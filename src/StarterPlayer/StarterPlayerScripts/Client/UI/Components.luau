-- Components: small set of UI building blocks shared by every screen.
-- All text goes through Localization.Bind, so language changes update instantly and
-- Roblox auto-translation never touches our text.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))
local Theme = require(script.Parent.Theme)
local AudioController = require(script.Parent.Parent.Controllers.AudioController)

local lastFocusSound = 0
local function focusSound()
	if os.clock() - lastFocusSound > 0.06 then
		lastFocusSound = os.clock()
		AudioController.UI("ui_focus")
	end
end

local Components = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Shared invisible selection object: we draw our own focus state instead of Roblox's box.
local hiddenSelection = Instance.new("Frame")
hiddenSelection.BackgroundTransparency = 1
hiddenSelection.Size = UDim2.fromScale(1, 1)

function Components.ScreenGui(name: string, displayOrder: number, fullBleed: boolean?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = displayOrder
	gui.AutoLocalize = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = if fullBleed then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = playerGui
	return gui
end

-- Responsive scaling: logical layout at 720p height, clamped so touch targets stay large
-- on phones and text does not become huge on 4K screens.
function Components.AttachScale(gui: ScreenGui): UIScale
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function update()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		scale.Scale = math.clamp(viewport.Y / 720, 0.9, 1.5)
	end
	local connection
	local function bindCamera()
		if connection then
			connection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
	return scale
end

-- Height of the screen in layout units (after AttachScale): < 600 means phone-sized.
function Components.LogicalHeight(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 720
	end
	local y = camera.ViewportSize.Y
	return y / math.clamp(y / 720, 0.9, 1.5)
end

export type TextProps = {
	Name: string?,
	Key: string?,
	Params: { [string]: any }?,
	Text: string?,
	Font: Enum.Font?,
	TextSize: number?,
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	Wrapped: boolean?,
	AutoY: boolean?,
	RichText: boolean?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function Components.Text(props: TextProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.Name or (props.Key or "Text")
	label.BackgroundTransparency = 1
	label.AutoLocalize = false
	label.Font = props.Font or Theme.Fonts.Body
	label.TextSize = props.TextSize or Theme.Sizes.TextBody
	label.TextColor3 = props.Color or Theme.Colors.Text
	label.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
	label.TextWrapped = props.Wrapped ~= false
	label.RichText = props.RichText == true
	label.Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or Theme.Sizes.TextBody) + 8)
	if props.AutoY then
		label.AutomaticSize = Enum.AutomaticSize.Y
	end
	if props.Position then
		label.Position = props.Position
	end
	if props.AnchorPoint then
		label.AnchorPoint = props.AnchorPoint
	end
	label.LayoutOrder = props.LayoutOrder or 0
	if props.Key then
		Localization.Bind(label, props.Key, props.Params)
	else
		label.Text = props.Text or ""
	end
	label.Parent = props.Parent
	return label
end

function Components.List(parent: Instance, padding: number?, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding or Theme.Sizes.Gap)
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.Parent = parent
	return layout
end

function Components.Padding(parent: Instance, left: number, top: number?, right: number?, bottom: number?)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, left)
	padding.PaddingTop = UDim.new(0, top or left)
	padding.PaddingRight = UDim.new(0, right or left)
	padding.PaddingBottom = UDim.new(0, bottom or top or left)
	padding.Parent = parent
	return padding
end

export type ButtonProps = {
	Key: string?,
	Params: { [string]: any }?,
	Text: string?,
	TagKey: string?, -- small right-aligned hint ("Suggested", "No signal yet", ...)
	TagParams: { [string]: any }?,
	OnActivated: (() -> ())?,
	LayoutOrder: number?,
	Height: number?,
	Disabled: boolean?,
	Font: Enum.Font?,
	Index: number?, -- small "01" number in front of the label (menu lists)
	Centered: boolean?, -- tabs / short choice buttons: centred label, no chevron
	Parent: Instance?,
}

export type Button = {
	Instance: TextButton,
	Label: TextLabel,
	Tag: TextLabel,
	SetDisabled: (disabled: boolean) -> (),
	SetFocused: (focused: boolean) -> (),
}

function Components.Corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.Sizes.Corner)
	corner.Parent = parent
	return corner
end

function Components.Stroke(parent: Instance, color: Color3?, transparency: number?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or Theme.Colors.PanelLine
	stroke.Transparency = transparency or 0.35
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

-- Glass card: dark translucent panel with a soft top highlight and a hairline border.
function Components.Panel(props: { Name: string?, Size: UDim2?, Position: UDim2?, AnchorPoint: Vector2?, Transparency: number?, LayoutOrder: number?, Parent: Instance? }): Frame
	local panel = Instance.new("Frame")
	panel.Name = props.Name or "Panel"
	panel.BackgroundColor3 = Theme.Colors.Panel
	panel.BackgroundTransparency = props.Transparency or 0.18
	panel.BorderSizePixel = 0
	panel.Size = props.Size or UDim2.fromScale(1, 0)
	panel.Position = props.Position or UDim2.new()
	panel.AnchorPoint = props.AnchorPoint or Vector2.zero
	panel.LayoutOrder = props.LayoutOrder or 0
	Components.Corner(panel)
	Components.Stroke(panel, Theme.Colors.PanelLine, 0.45)
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 178, 186))
	sheen.Parent = panel
	panel.Parent = props.Parent
	return panel
end

function Components.Button(props: ButtonProps): Button
	local height = props.Height or Theme.Sizes.Button
	local compact = height < 44
	local button = Instance.new("TextButton")
	button.Name = props.Key or "Button"
	button.AutoButtonColor = false
	button.AutoLocalize = false
	button.Text = ""
	button.BackgroundColor3 = Theme.Colors.PanelRaised
	button.BackgroundTransparency = 0.45
	button.BorderSizePixel = 0
	button.ClipsDescendants = true
	button.Size = UDim2.new(1, 0, 0, height)
	button.LayoutOrder = props.LayoutOrder or 0
	button.Selectable = true
	button.SelectionImageObject = hiddenSelection
	Components.Corner(button, 5)
	local stroke = Components.Stroke(button, Theme.Colors.PanelLine, 0.6)

	-- Accent sweep: a red glow that slides in from the left on focus/hover.
	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.BackgroundColor3 = Theme.Colors.Accent
	sweep.BorderSizePixel = 0
	sweep.Size = UDim2.fromScale(0, 1)
	sweep.ZIndex = 0
	sweep.Parent = button
	local sweepGradient = Instance.new("UIGradient")
	sweepGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.62),
		NumberSequenceKeypoint.new(0.55, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	})
	sweepGradient.Parent = sweep

	local bar = Instance.new("Frame")
	bar.Name = "FocusBar"
	bar.BackgroundColor3 = Theme.Colors.Accent
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0, 0.5)
	bar.Size = UDim2.new(0, 3, 1, 0)
	bar.BackgroundTransparency = 1
	bar.Parent = button

	local centered = props.Centered == true
	local textLeft = if centered then 6 else 18
	local index: TextLabel? = nil
	if props.Index then
		index = Components.Text({
			Name = "Index",
			Text = string.format("%02d", props.Index),
			Font = Theme.Fonts.Mono,
			TextSize = 13,
			Color = Theme.Colors.TextFaint,
			Wrapped = false,
			Size = UDim2.new(0, 26, 1, 0),
			Position = UDim2.fromOffset(16, 0),
			Parent = button,
		})
		textLeft = 48
	end

	local label = Components.Text({
		Name = "Label",
		Key = props.Key,
		Params = props.Params,
		Text = props.Text,
		Font = props.Font or Theme.Fonts.Medium,
		TextSize = if compact then Theme.Sizes.TextSmall + 1 else Theme.Sizes.TextButton,
		Wrapped = false,
		Size = if centered then UDim2.new(1, -12, 1, 0) else UDim2.new(1, -(textLeft + 34), 1, 0),
		Position = UDim2.fromOffset(textLeft, 0),
		XAlign = if centered then Enum.TextXAlignment.Center else nil,
		Parent = button,
	})
	label.TextTruncate = Enum.TextTruncate.AtEnd
	if centered then
		-- tabs are narrow: shrink long labels ("Barrierefreiheit") instead of cutting them
		label.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = label.TextSize
		limit.MinTextSize = 9
		limit.Parent = label
		label.Size = UDim2.new(1, -12, 0.62, 0)
		label.Position = UDim2.new(0, textLeft, 0.19, 0)
	end

	local chevron = Components.Text({
		Name = "Chevron",
		Text = "›",
		Font = Theme.Fonts.Bold,
		TextSize = if compact then 18 else 24,
		Color = Theme.Colors.TextFaint,
		XAlign = Enum.TextXAlignment.Center,
		Wrapped = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.new(0, 24, 1, 0),
		Position = UDim2.new(1, -8, 0.5, 0),
		Parent = button,
	})

	local tag = Components.Text({
		Name = "Tag",
		Key = props.TagKey,
		Params = props.TagParams,
		Font = Theme.Fonts.Mono,
		TextSize = Theme.Sizes.TextSmall - 1,
		Color = Theme.Colors.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		Wrapped = false,
		Size = UDim2.new(0.45, -16, 1, 0),
		Position = UDim2.new(0.55, 0, 0, 0),
		Parent = button,
	})
	tag.Visible = props.TagKey ~= nil
	chevron.Visible = not centered
	if tag.Visible then
		label.Size = UDim2.new(0.6, -textLeft, 1, 0)
		chevron.Visible = false
	end

	local disabled = props.Disabled == true
	local focused = false
	local hovered = false
	local pressed = false

	local function render()
		local active = (focused or hovered) and not disabled
		TweenService:Create(bar, Theme.Fast, { BackgroundTransparency = if active then 0 else 1 }):Play()
		TweenService:Create(sweep, Theme.Fade, { Size = UDim2.fromScale(if active then 1 else 0, 1) }):Play()
		TweenService:Create(button, Theme.Fast, {
			BackgroundTransparency = if pressed and active then 0.05 elseif active then 0.2 else 0.45,
		}):Play()
		TweenService:Create(stroke, Theme.Fast, {
			Color = if active then Theme.Colors.Accent else Theme.Colors.PanelLine,
			Transparency = if active then 0.35 else 0.6,
		}):Play()
		TweenService:Create(label, Theme.Fast, {
			TextColor3 = if disabled then Theme.Colors.TextFaint elseif active then Theme.Colors.TextBright else Theme.Colors.Text,
			Position = if centered then UDim2.new(0, textLeft, 0.19, 0) else UDim2.fromOffset(if active then textLeft + 4 else textLeft, 0),
		}):Play()
		TweenService:Create(chevron, Theme.Fast, {
			TextColor3 = if active then Theme.Colors.Accent else Theme.Colors.TextFaint,
			Position = UDim2.new(1, if active then -4 else -8, 0.5, 0),
		}):Play()
		if index then
			TweenService:Create(index, Theme.Fast, { TextColor3 = if active then Theme.Colors.Accent else Theme.Colors.TextFaint }):Play()
		end
	end

	button.MouseEnter:Connect(function()
		hovered = true
		if not disabled then
			focusSound()
		end
		render()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		pressed = false
		render()
	end)
	button.MouseButton1Down:Connect(function()
		pressed = true
		render()
	end)
	button.MouseButton1Up:Connect(function()
		pressed = false
		render()
	end)
	button.SelectionGained:Connect(function()
		focused = true
		focusSound()
		render()
	end)
	button.SelectionLost:Connect(function()
		focused = false
		render()
	end)
	button.Activated:Connect(function()
		if disabled or not props.OnActivated then
			return
		end
		AudioController.UI("ui_select")
		props.OnActivated()
	end)

	render()
	button.Parent = props.Parent

	return {
		Instance = button,
		Label = label,
		Tag = tag,
		SetDisabled = function(value: boolean)
			disabled = value
			render()
		end,
		SetFocused = function(value: boolean)
			focused = value
			render()
		end,
	}
end

-- Scrollable vertical column. Gamepad selection scrolls it automatically.
function Components.ScrollColumn(parent: Instance, size: UDim2, position: UDim2?): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "Scroll"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = size
	frame.Position = position or UDim2.new()
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.ScrollBarThickness = 3
	frame.ScrollBarImageColor3 = Theme.Colors.TextFaint
	frame.Selectable = false
	frame.Parent = parent
	Components.List(frame, Theme.Sizes.Gap)
	Components.Padding(frame, 2, 2, 8, 12)
	return frame
end

function Components.Heading(parent: Instance, key: string, layoutOrder: number?): TextLabel
	local heading = Components.Text({
		Key = key,
		Font = Theme.Fonts.Bold, -- Michroma is reserved for the Latin-only logo (accent coverage)
		TextSize = Theme.Sizes.TextHeading + 8,
		Color = Theme.Colors.TextBright,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = layoutOrder or 0,
		Parent = parent,
	})
	heading.TextYAlignment = Enum.TextYAlignment.Top
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = Theme.Colors.Accent
	rule.BorderSizePixel = 0
	rule.AnchorPoint = Vector2.new(0, 1)
	rule.Position = UDim2.new(0, 0, 1, -2)
	rule.Size = UDim2.fromOffset(36, 2)
	rule.Parent = heading
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.BackgroundColor3 = Theme.Colors.PanelLine
	line.BackgroundTransparency = 0.5
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.new(0, 42, 1, -2.5)
	line.Size = UDim2.new(1, -42, 0, 1)
	line.Parent = heading
	return heading
end

function Components.Spacer(parent: Instance, height: number, layoutOrder: number)
	local spacer = Instance.new("Frame")
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.new(1, 0, 0, height)
	spacer.LayoutOrder = layoutOrder
	spacer.Parent = parent
	return spacer
end

-- Standard screen root: a CanvasGroup (for fades) holding a left-aligned content column.
function Components.ScreenRoot(name: string): (CanvasGroup, Frame)
	local root = Instance.new("CanvasGroup")
	root.Name = name
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.GroupTransparency = 1

	-- Side slab: dark glass from the left edge, fading out towards the scene.
	local slab = Instance.new("Frame")
	slab.Name = "Slab"
	slab.BackgroundColor3 = Theme.Colors.Background
	slab.BorderSizePixel = 0
	slab.Size = UDim2.new(0, Theme.Sizes.Margin * 2 + Theme.Sizes.ContentWidth + 120, 1, 0)
	slab.ZIndex = 0
	slab.Parent = root
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.72, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = slab
	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.BackgroundColor3 = Theme.Colors.Accent
	edge.BackgroundTransparency = 0.2
	edge.BorderSizePixel = 0
	edge.Size = UDim2.new(0, 2, 1, 0)
	edge.Parent = root
	local edgeFade = Instance.new("UIGradient")
	edgeFade.Rotation = 90
	edgeFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	edgeFade.Parent = edge

	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, Theme.Sizes.Margin, 0.5, 0)
	column.Size = UDim2.new(0, Theme.Sizes.ContentWidth, 1, -64)
	column.Parent = root
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(Theme.Sizes.ContentWidth, math.huge)
	constraint.Parent = column
	return root, column
end

-- Full-screen vignette (four soft edges, no image assets needed).
function Components.Vignette(parent: Instance, strength: number?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Vignette"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 50
	holder.Active = false
	holder.Parent = parent
	local s = strength or 0.35
	for i, rotation in { 0, 90, 180, 270 } do
		local edge = Instance.new("Frame")
		edge.Name = "Edge" .. i
		edge.BackgroundColor3 = Color3.new(0, 0, 0)
		edge.BorderSizePixel = 0
		edge.AnchorPoint = Vector2.new(0.5, 0.5)
		edge.Position = UDim2.fromScale(0.5, 0.5)
		edge.Size = if rotation % 180 == 0 then UDim2.fromScale(1, 1) else UDim2.fromScale(1, 1)
		edge.ZIndex = 50
		edge.Parent = holder
		local g = Instance.new("UIGradient")
		g.Rotation = rotation
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - s),
			NumberSequenceKeypoint.new(0.22, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = edge
	end
	return holder
end

return Components
