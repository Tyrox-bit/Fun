-- Components: small set of UI building blocks shared by every screen.
-- All text goes through Localization.Bind, so language changes update instantly and
-- Roblox auto-translation never touches our text.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))
local Theme = require(script.Parent.Theme)

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
	Parent: Instance?,
}

export type Button = {
	Instance: TextButton,
	Label: TextLabel,
	Tag: TextLabel,
	SetDisabled: (disabled: boolean) -> (),
	SetFocused: (focused: boolean) -> (),
}

function Components.Button(props: ButtonProps): Button
	local height = props.Height or Theme.Sizes.Button
	local button = Instance.new("TextButton")
	button.Name = props.Key or "Button"
	button.AutoButtonColor = false
	button.AutoLocalize = false
	button.Text = ""
	button.BackgroundColor3 = Theme.Colors.TextBright
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Size = UDim2.new(1, 0, 0, height)
	button.LayoutOrder = props.LayoutOrder or 0
	button.Selectable = true
	button.SelectionImageObject = hiddenSelection

	local bar = Instance.new("Frame")
	bar.Name = "FocusBar"
	bar.BackgroundColor3 = Theme.Colors.Accent
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0, 0.5)
	bar.Size = UDim2.new(0, 3, 0.55, 0)
	bar.BackgroundTransparency = 1
	bar.Parent = button

	local label = Components.Text({
		Name = "Label",
		Key = props.Key,
		Params = props.Params,
		Text = props.Text,
		Font = props.Font or Theme.Fonts.Medium,
		TextSize = Theme.Sizes.TextButton,
		Wrapped = false,
		Size = UDim2.new(1, -18, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		Parent = button,
	})
	label.TextTruncate = Enum.TextTruncate.AtEnd

	local tag = Components.Text({
		Name = "Tag",
		Key = props.TagKey,
		Params = props.TagParams,
		Font = Theme.Fonts.Mono,
		TextSize = Theme.Sizes.TextSmall,
		Color = Theme.Colors.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		Wrapped = false,
		Size = UDim2.new(0.45, -12, 1, 0),
		Position = UDim2.new(0.55, 0, 0, 0),
		Parent = button,
	})
	tag.Visible = props.TagKey ~= nil
	if tag.Visible then
		label.Size = UDim2.new(0.6, -18, 1, 0)
	end

	local disabled = props.Disabled == true
	local focused = false
	local hovered = false

	local function render()
		local active = (focused or hovered) and not disabled
		TweenService:Create(bar, Theme.Fast, { BackgroundTransparency = if active then 0 else 1 }):Play()
		TweenService:Create(button, Theme.Fast, { BackgroundTransparency = if active then 0.93 else 1 }):Play()
		TweenService:Create(label, Theme.Fast, {
			TextColor3 = if disabled then Theme.Colors.TextFaint elseif active then Theme.Colors.TextBright else Theme.Colors.Text,
			Position = UDim2.fromOffset(if active then 20 else 16, 0),
		}):Play()
	end

	button.MouseEnter:Connect(function()
		hovered = true
		render()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		render()
	end)
	button.SelectionGained:Connect(function()
		focused = true
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
	return Components.Text({
		Key = key,
		Font = Theme.Fonts.Bold, -- Michroma is reserved for the Latin-only logo (accent coverage)
		TextSize = Theme.Sizes.TextHeading + 4,
		Color = Theme.Colors.TextBright,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = layoutOrder or 0,
		Parent = parent,
	})
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

	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, Theme.Sizes.Margin, 0.5, 0)
	column.Size = UDim2.new(0, Theme.Sizes.ContentWidth, 1, -48)
	column.Parent = root
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(Theme.Sizes.ContentWidth, math.huge)
	constraint.Parent = column
	return root, column
end

return Components
