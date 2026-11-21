-- HUD: deliberately minimal. Nothing is permanently on screen; every element appears in
-- context and fades away again.
--   * Subtitles (radio / voices / sound captions). Safety-relevant captions ("critical")
--     are shown even when subtitles are turned off.
--   * Objective toast
--   * Document reader (fax, notes)
--   * Short notifications
--   * Stamina line (only while not full)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))

local Components = require(script.Parent.Components)
local PhotoView = require(script.Parent.PhotoView)
local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local Theme = require(script.Parent.Theme)

local Hud = {}

local SUBTITLE_SIZES = { small = 18, medium = 22, large = 28 }
local MAX_LINES = 3

local gui: ScreenGui
local settings
local input
local subtitleFrame: Frame
local objectiveFrame: CanvasGroup
local objectiveText: TextLabel
local notifyLabel: TextLabel
local staminaTrack: Frame
local staminaFill: Frame
local documentLayer: Frame? = nil
local documentCallbacks: { onOpen: () -> (), onClose: () -> () }? = nil

type ActiveLine = { label: TextLabel, pill: Frame, line: { [string]: any }, expires: number }
local activeLines: { ActiveLine } = {}
local currentObjective: string? = nil
local objectiveToken = 0
local notifyToken = 0
local lineCounter = 0

local function escape(text: string): string
	return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function escapeParams(params: { [string]: any }?): { [string]: any }?
	if not params then
		return nil
	end
	local out = {}
	for key, value in params do
		out[key] = escape(tostring(value))
	end
	return out
end

local function subtitleText(line: { [string]: any }): string
	-- Base strings are ours (no markup); only runtime params (e.g. player names) are escaped.
	local text = Localization.T(line.text, escapeParams(line.params))
	if line.speaker then
		local color = if line.speaker == "SPEAKER_RELAY" then Theme.Colors.Relay else Theme.Colors.Radio
		return string.format('<font color="%s">%s</font>  %s', Theme.Hex(color), escape(Localization.T(line.speaker)), text)
	end
	return string.format('<font color="%s"><i>%s</i></font>', Theme.Hex(Theme.Colors.World), text)
end

local function subtitleSize(): number
	return SUBTITLE_SIZES[settings.Get("subtitleSize")] or SUBTITLE_SIZES.medium
end

local function removeLine(entry: ActiveLine)
	local index = table.find(activeLines, entry)
	if index then
		table.remove(activeLines, index)
	end
	TweenService:Create(entry.pill, Theme.Fade, { BackgroundTransparency = 1 }):Play()
	local tween = TweenService:Create(entry.label, Theme.Fade, { TextTransparency = 1, TextStrokeTransparency = 1 })
	tween.Completed:Once(function()
		entry.pill:Destroy()
	end)
	tween:Play()
end

function Hud.ShowSubtitle(line: { [string]: any })
	if type(line) ~= "table" or type(line.text) ~= "string" then
		return
	end
	if not settings.Get("subtitles") and not line.critical then
		return
	end
	if #activeLines >= MAX_LINES then
		removeLine(activeLines[1])
	end
	-- each line sits on its own dark pill: readable on bright and dark scenes alike
	local pill = Instance.new("Frame")
	pill.Name = "Line"
	pill.BackgroundColor3 = Color3.fromRGB(4, 6, 8)
	pill.BackgroundTransparency = 1
	pill.BorderSizePixel = 0
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.Size = UDim2.new()
	Components.Corner(pill, 6)
	Components.Padding(pill, 14, 6)
	lineCounter += 1
	pill.LayoutOrder = lineCounter
	pill.Parent = subtitleFrame
	if line.speaker then
		local accent = Instance.new("Frame")
		accent.Name = "Accent"
		accent.BackgroundColor3 = if line.speaker == "SPEAKER_RELAY" then Theme.Colors.Relay else Theme.Colors.Radio
		accent.BorderSizePixel = 0
		accent.Position = UDim2.new(0, -14, 0, -6)
		accent.Size = UDim2.new(0, 2, 1, 12)
		accent.Parent = pill
	end
	local label = Components.Text({
		Name = "Text",
		Text = "",
		RichText = true,
		Font = Theme.Fonts.Medium,
		TextSize = subtitleSize(),
		Color = Theme.Colors.TextBright,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(),
		Parent = pill,
	})
	label.AutomaticSize = Enum.AutomaticSize.XY
	local maxWidth = Instance.new("UISizeConstraint")
	maxWidth.MaxSize = Vector2.new(780, math.huge)
	maxWidth.Parent = label
	label.Text = subtitleText(line)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 1
	label.TextTransparency = 1
	TweenService:Create(label, Theme.Fast, { TextTransparency = 0, TextStrokeTransparency = 0.7 }):Play()
	TweenService:Create(pill, Theme.Fast, { BackgroundTransparency = 0.38 }):Play()

	local duration = math.clamp(tonumber(line.duration) or 4, 1.5, 12)
	if line.speaker then
		AudioController.Duck(duration) -- voices sit on top of the mix
	end
	local entry: ActiveLine = { label = label, pill = pill, line = line, expires = os.clock() + duration }
	table.insert(activeLines, entry)
	task.delay(duration, function()
		if table.find(activeLines, entry) then
			removeLine(entry)
		end
	end)
end

function Hud.ShowObjective(key: string?, announce: boolean?, params: { [string]: any }?)
	currentObjective = key
	if not key then
		objectiveFrame.Visible = false
		return
	end
	Localization.Bind(objectiveText, key, params)
	objectiveToken += 1
	local token = objectiveToken
	objectiveFrame.Visible = true
	objectiveFrame.GroupTransparency = 1
	objectiveFrame.Position = UDim2.fromOffset(4, 16)
	TweenService:Create(objectiveFrame, Theme.Slow, { GroupTransparency = 0, Position = UDim2.fromOffset(24, 16) }):Play()
	task.delay(if announce == false then 4 else 7, function()
		if token == objectiveToken then
			TweenService:Create(objectiveFrame, Theme.Slow, { GroupTransparency = 1 }):Play()
		end
	end)
end

function Hud.Notify(key: string, params: { [string]: any }?)
	-- params may carry text keys (e.g. an achievement name): show them translated
	if params then
		local translated = {}
		for name, value in params do
			translated[name] = if type(value) == "string" and string.match(value, "^[A-Z][A-Z0-9_]+$") and Localization.Has(value) then Localization.T(value) else value
		end
		params = translated
	end
	notifyToken += 1
	local token = notifyToken
	Localization.Bind(notifyLabel, key, params)
	local toast = notifyLabel.Parent :: CanvasGroup
	toast.Visible = true
	notifyLabel.Visible = true
	toast.GroupTransparency = 1
	toast.Position = UDim2.new(0.5, 0, 0, 6)
	TweenService:Create(toast, Theme.Fade, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, 18) }):Play()
	task.delay(4, function()
		if token == notifyToken then
			TweenService:Create(toast, Theme.Slow, { GroupTransparency = 1 }):Play()
		end
	end)
end

function Hud.SetStamina(value: number, exhausted: boolean)
	local visible = value < 0.999
	if staminaTrack.Visible ~= visible then
		staminaTrack.Visible = visible
	end
	staminaFill.Size = UDim2.fromScale(value, 1)
	staminaFill.BackgroundColor3 = if exhausted then Theme.Colors.Accent else Theme.Colors.Text
end

local function formatDate(unix: number): string
	local t = os.date("*t", unix)
	return Localization.T("DATE_FORMAT", {
		d = string.format("%02d", t.day),
		m = string.format("%02d", t.month),
		y = tostring(t.year),
	})
end

function Hud.IsDocumentOpen(): boolean
	return documentLayer ~= nil
end

function Hud.CloseDocument()
	if not documentLayer then
		return
	end
	documentLayer:Destroy()
	documentLayer = nil
	GuiService.SelectedObject = nil
	if documentCallbacks then
		documentCallbacks.onClose()
	end
end

function Hud.ShowDocument(document: { [string]: any })
	if type(document) ~= "table" or type(document.title) ~= "string" or type(document.body) ~= "string" then
		return
	end
	Hud.CloseDocument()

	local layer = Instance.new("Frame")
	layer.Name = "Document"
	layer.BackgroundColor3 = Color3.new(0, 0, 0)
	layer.BackgroundTransparency = 0.35
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 20
	layer.Parent = gui
	documentLayer = layer

	local unlock = Instance.new("TextButton")
	unlock.Modal = true
	unlock.Text = ""
	unlock.BackgroundTransparency = 1
	unlock.Size = UDim2.fromOffset(0, 0)
	unlock.Selectable = false
	unlock.Parent = layer

	local panel = Instance.new("Frame")
	panel.Name = "Paper"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 520, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Theme.Colors.Panel
	panel.BorderSizePixel = 0
	panel.ZIndex = 21
	panel.Parent = layer
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, 600)
	sizeLimit.Parent = panel
	Components.Corner(panel, 8)
	Components.Stroke(panel, Theme.Colors.PanelLine, 0.3)
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundColor3 = Theme.Colors.Accent
	topBar.BorderSizePixel = 0
	topBar.Size = UDim2.fromOffset(40, 2)
	topBar.LayoutOrder = -1
	topBar.ZIndex = 22
	topBar.Parent = panel
	layer.BackgroundTransparency = 1
	TweenService:Create(layer, Theme.Fade, { BackgroundTransparency = 0.25 }):Play()
	Components.Padding(panel, 28, 24)
	Components.List(panel, 12)

	local params = if type(document.params) == "table" then table.clone(document.params) else nil
	if type(document.date) == "number" then
		params = params or {}
		params.date = formatDate(document.date)
	end
	if type(document.photo) == "table" then
		local photo = PhotoView.Build(document.photo)
		photo.LayoutOrder = 0
		photo.ZIndex = 22
		for _, d in photo:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 23
			end
		end
		photo.Parent = panel
	end
	local title = Components.Text({ Key = document.title, Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Accent, LayoutOrder = 1, Parent = panel })
	title.ZIndex = 22
	local body = Components.Text({ Key = document.body, Params = params, Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.TextBright, AutoY = true, Size = UDim2.fromScale(1, 0), YAlign = Enum.TextYAlignment.Top, LayoutOrder = 2, Parent = panel })
	body.ZIndex = 22
	local close = Components.Button({ Key = "DOC_CLOSE", LayoutOrder = 3, OnActivated = Hud.CloseDocument, Parent = panel })
	close.Instance.ZIndex = 22
	for _, child in close.Instance:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 23
		end
	end

	if documentCallbacks then
		documentCallbacks.onOpen()
	end
	if input.GetDevice() == "gamepad" then
		GuiService.SelectedObject = close.Instance
	end
end

-- Survival status line (top centre): "SHIFT 3 · BLACKOUT" or the break countdown.
local statusLine: TextLabel? = nil
function Hud.SetStatus(key: string?, params: { [string]: any }?, suffixKey: string?)
	local label = statusLine :: TextLabel
	if not key then
		label.Visible = false
		return
	end
	local text = Localization.T(key, params)
	if suffixKey then
		text ..= "  ·  " .. Localization.T(suffixKey)
	end
	label.Text = text
	label.Visible = true
end

-- Forecast line (top centre, under the status line): "FORECAST · Lights in Sector A · 0:24"
local forecastLine: TextLabel? = nil
function Hud.SetForecast(key: string?, seconds: number?)
	local label = forecastLine :: TextLabel
	if not key then
		label.Visible = false
		return
	end
	local s = math.max(0, math.floor(seconds or 0))
	label.Text = Localization.T("FORECAST_LABEL", { text = Localization.T(key), time = string.format("%d:%02d", s // 60, s % 60) })
	label.Visible = true
end

function Hud.Init(hudGui: ScreenGui, settingsController, inputController, callbacks: { onOpen: () -> (), onClose: () -> () })
	gui = hudGui
	settings = settingsController
	input = inputController
	documentCallbacks = callbacks

	subtitleFrame = Instance.new("Frame")
	subtitleFrame.Name = "Subtitles"
	subtitleFrame.BackgroundTransparency = 1
	subtitleFrame.AnchorPoint = Vector2.new(0.5, 1)
	subtitleFrame.Position = UDim2.new(0.5, 0, 1, -96) -- above the hotbar
	subtitleFrame.Size = UDim2.new(0.62, 0, 0.4, 0)
	subtitleFrame.Parent = gui
	local subtitleLayout = Components.List(subtitleFrame, 6)
	subtitleLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	subtitleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	objectiveFrame = Instance.new("CanvasGroup")
	objectiveFrame.Name = "Objective"
	objectiveFrame.BackgroundColor3 = Theme.Colors.Panel
	objectiveFrame.BackgroundTransparency = 0.3
	objectiveFrame.BorderSizePixel = 0
	objectiveFrame.Position = UDim2.fromOffset(24, 16)
	objectiveFrame.Size = UDim2.fromOffset(400, 0)
	objectiveFrame.AutomaticSize = Enum.AutomaticSize.Y
	objectiveFrame.Visible = false
	objectiveFrame.Parent = gui
	Components.Corner(objectiveFrame, 6)
	Components.Padding(objectiveFrame, 18, 10, 14, 12)
	Components.List(objectiveFrame, 2)
	local objectiveBar = Instance.new("Frame")
	objectiveBar.Name = "Bar"
	objectiveBar.BackgroundColor3 = Theme.Colors.Accent
	objectiveBar.BorderSizePixel = 0
	objectiveBar.Size = UDim2.fromOffset(28, 2)
	objectiveBar.LayoutOrder = 0
	objectiveBar.Parent = objectiveFrame
	Components.Text({ Key = "OBJECTIVE_NEW", Font = Theme.Fonts.Mono, TextSize = 13, Color = Theme.Colors.Accent, LayoutOrder = 1, Parent = objectiveFrame })
	objectiveText = Components.Text({ Text = "", Font = Theme.Fonts.Bold, TextSize = Theme.Sizes.TextHeading - 2, Color = Theme.Colors.TextBright, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 2, Parent = objectiveFrame })

	-- notification toast (top centre)
	local toast = Instance.new("CanvasGroup")
	toast.Name = "Toast"
	toast.BackgroundColor3 = Theme.Colors.Panel
	toast.BackgroundTransparency = 0.2
	toast.BorderSizePixel = 0
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 18)
	toast.Size = UDim2.new()
	toast.AutomaticSize = Enum.AutomaticSize.XY
	toast.Visible = false
	toast.Parent = gui
	Components.Corner(toast, 18)
	Components.Stroke(toast, Theme.Colors.Accent, 0.55)
	Components.Padding(toast, 18, 8)
	notifyLabel = Components.Text({ Text = "", Font = Theme.Fonts.Medium, TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.TextBright, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(), Parent = toast })
	notifyLabel.AutomaticSize = Enum.AutomaticSize.XY
	local toastLimit = Instance.new("UISizeConstraint")
	toastLimit.MaxSize = Vector2.new(640, math.huge)
	toastLimit.Parent = notifyLabel

	local function pillLine(color: Color3, y: number): TextLabel
		local holder = Instance.new("Frame")
		holder.BackgroundColor3 = Color3.fromRGB(4, 6, 8)
		holder.BackgroundTransparency = 0.4
		holder.BorderSizePixel = 0
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, y)
		holder.AutomaticSize = Enum.AutomaticSize.XY
		holder.Size = UDim2.new()
		holder.Parent = gui
		Components.Corner(holder, 4)
		Components.Padding(holder, 12, 3)
		local label = Components.Text({ Text = "", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = color, XAlign = Enum.TextXAlignment.Center, Wrapped = false, Size = UDim2.new(), Parent = holder })
		label.AutomaticSize = Enum.AutomaticSize.XY
		-- the holder follows the label's visibility
		holder.Visible = false
		label:GetPropertyChangedSignal("Visible"):Connect(function()
			holder.Visible = label.Visible
		end)
		return label
	end
	statusLine = pillLine(Theme.Colors.Radio, 62)
	forecastLine = pillLine(Theme.Colors.Relay, 90)
	;(statusLine :: TextLabel).Visible = false
	;(forecastLine :: TextLabel).Visible = false

	staminaTrack = Instance.new("Frame")
	staminaTrack.Name = "Stamina"
	staminaTrack.AnchorPoint = Vector2.new(0.5, 1)
	staminaTrack.Position = UDim2.new(0.5, 0, 1, -10)
	staminaTrack.Size = UDim2.fromOffset(220, 4)
	staminaTrack.BackgroundColor3 = Color3.new(0, 0, 0)
	staminaTrack.BackgroundTransparency = 0.45
	staminaTrack.BorderSizePixel = 0
	staminaTrack.Visible = false
	staminaTrack.Parent = gui
	Components.Corner(staminaTrack, 2)
	staminaFill = Instance.new("Frame")
	staminaFill.BorderSizePixel = 0
	staminaFill.BackgroundColor3 = Theme.Colors.Text
	staminaFill.Size = UDim2.fromScale(1, 1)
	staminaFill.Parent = staminaTrack
	Components.Corner(staminaFill, 2)

	-- Re-render visible subtitles when the language or subtitle size changes.
	Localization.Changed:Connect(function()
		for _, entry in activeLines do
			entry.label.Text = subtitleText(entry.line)
		end
	end)
	settings.Changed:Connect(function(key)
		if key == "subtitleSize" then
			for _, entry in activeLines do
				entry.label.TextSize = subtitleSize()
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(inputObject)
		if not documentLayer then
			return
		end
		local key = inputObject.KeyCode
		if key == Enum.KeyCode.ButtonB or (key == Enum.KeyCode.Backspace and not UserInputService:GetFocusedTextBox()) then
			Hud.CloseDocument()
		end
	end)
end

return Hud
