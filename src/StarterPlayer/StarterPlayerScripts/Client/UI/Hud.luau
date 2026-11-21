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

type ActiveLine = { label: TextLabel, line: { [string]: any }, expires: number }
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
	local tween = TweenService:Create(entry.label, Theme.Fade, { TextTransparency = 1, TextStrokeTransparency = 1 })
	tween.Completed:Once(function()
		entry.label:Destroy()
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
	local label = Components.Text({
		Name = "Line",
		Text = "",
		RichText = true,
		Font = Theme.Fonts.Medium,
		TextSize = subtitleSize(),
		Color = Theme.Colors.TextBright,
		XAlign = Enum.TextXAlignment.Center,
		AutoY = true,
		Size = UDim2.fromScale(1, 0),
		Parent = subtitleFrame,
	})
	label.Text = subtitleText(line)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 1
	label.TextTransparency = 1
	lineCounter += 1
	label.LayoutOrder = lineCounter
	TweenService:Create(label, Theme.Fast, { TextTransparency = 0, TextStrokeTransparency = 0.45 }):Play()

	local duration = math.clamp(tonumber(line.duration) or 4, 1.5, 12)
	local entry: ActiveLine = { label = label, line = line, expires = os.clock() + duration }
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
	TweenService:Create(objectiveFrame, Theme.Slow, { GroupTransparency = 0 }):Play()
	task.delay(if announce == false then 4 else 7, function()
		if token == objectiveToken then
			TweenService:Create(objectiveFrame, Theme.Slow, { GroupTransparency = 1 }):Play()
		end
	end)
end

function Hud.Notify(key: string, params: { [string]: any }?)
	notifyToken += 1
	local token = notifyToken
	Localization.Bind(notifyLabel, key, params)
	notifyLabel.Visible = true
	notifyLabel.TextTransparency = 1
	TweenService:Create(notifyLabel, Theme.Fast, { TextTransparency = 0 }):Play()
	task.delay(4, function()
		if token == notifyToken then
			TweenService:Create(notifyLabel, Theme.Fade, { TextTransparency = 1 }):Play()
		end
	end)
end

function Hud.SetStamina(value: number, exhausted: boolean)
	local visible = value < 0.999
	if staminaTrack.Visible ~= visible then
		staminaTrack.Visible = visible
	end
	staminaFill.Size = UDim2.fromScale(value, 1)
	staminaFill.BackgroundColor3 = if exhausted then Theme.Colors.Accent else Theme.Colors.TextDim
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
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.PanelLine
	stroke.Parent = panel
	Components.Padding(panel, 28, 24)
	Components.List(panel, 12)

	local params = if type(document.params) == "table" then table.clone(document.params) else nil
	if type(document.date) == "number" then
		params = params or {}
		params.date = formatDate(document.date)
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
	subtitleFrame.Position = UDim2.new(0.5, 0, 1, -24)
	subtitleFrame.Size = UDim2.new(0.62, 0, 0.4, 0)
	subtitleFrame.Parent = gui
	local subtitleLayout = Components.List(subtitleFrame, 6)
	subtitleLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	subtitleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	objectiveFrame = Instance.new("CanvasGroup")
	objectiveFrame.Name = "Objective"
	objectiveFrame.BackgroundTransparency = 1
	objectiveFrame.Position = UDim2.fromOffset(24, 16)
	objectiveFrame.Size = UDim2.fromOffset(420, 70)
	objectiveFrame.Visible = false
	objectiveFrame.Parent = gui
	Components.List(objectiveFrame, 2)
	Components.Text({ Key = "OBJECTIVE_NEW", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Accent, LayoutOrder = 1, Parent = objectiveFrame })
	objectiveText = Components.Text({ Text = "", Font = Theme.Fonts.Medium, TextSize = Theme.Sizes.TextHeading, Color = Theme.Colors.TextBright, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 2, Parent = objectiveFrame })

	notifyLabel = Components.Text({ Text = "", Font = Theme.Fonts.Medium, TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.TextBright, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(0.8, 0, 0, 28), Position = UDim2.new(0.5, 0, 0, 20), AnchorPoint = Vector2.new(0.5, 0), Parent = gui })
	notifyLabel.Visible = false

	statusLine = Components.Text({ Text = "", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Radio, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.new(0.5, 0, 0, 52), AnchorPoint = Vector2.new(0.5, 0), Parent = gui })
	;(statusLine :: TextLabel).TextStrokeTransparency = 0.5
	;(statusLine :: TextLabel).Visible = false

	forecastLine = Components.Text({ Text = "", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Relay, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(0.7, 0, 0, 20), Position = UDim2.new(0.5, 0, 0, 74), AnchorPoint = Vector2.new(0.5, 0), Parent = gui })
	;(forecastLine :: TextLabel).TextStrokeTransparency = 0.5
	;(forecastLine :: TextLabel).Visible = false

	staminaTrack = Instance.new("Frame")
	staminaTrack.Name = "Stamina"
	staminaTrack.AnchorPoint = Vector2.new(0.5, 1)
	staminaTrack.Position = UDim2.new(0.5, 0, 1, -8)
	staminaTrack.Size = UDim2.fromOffset(160, 2)
	staminaTrack.BackgroundColor3 = Theme.Colors.TextFaint
	staminaTrack.BackgroundTransparency = 0.5
	staminaTrack.BorderSizePixel = 0
	staminaTrack.Visible = false
	staminaTrack.Parent = gui
	staminaFill = Instance.new("Frame")
	staminaFill.BorderSizePixel = 0
	staminaFill.BackgroundColor3 = Theme.Colors.TextDim
	staminaFill.Size = UDim2.fromScale(1, 1)
	staminaFill.Parent = staminaTrack

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
