-- PromptController: our own interaction prompt (all prompts use Style = Custom).
-- Same look on every device; key glyph adapts to the input device:
--   keyboard "E" · gamepad "X" · touch: the whole prompt is a big tap / hold target
-- Hold prompts fill the key box; a short flash confirms the trigger.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.UI.Theme)

local PromptController = {}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name
		return (string.gsub(name, "^Button", ""))
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "●"
	end
	local ok, text = pcall(UserInputService.GetStringForKeyCode, UserInputService, prompt.KeyboardKeyCode)
	return if ok and text ~= "" then string.upper(text) else prompt.KeyboardKeyCode.Name
end

local function adornee(prompt: ProximityPrompt): Instance?
	local parent = prompt.Parent
	if parent and parent:IsA("Model") then
		return parent.PrimaryPart
	end
	return parent
end

local function build(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local gui = Instance.new("BillboardGui")
	gui.Name = "FZ_Prompt"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(if touch then 280 else 250, if touch then 72 else 58)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.ResetOnSpawn = false
	gui.AutoLocalize = false
	gui.Active = touch
	gui.ClipsDescendants = false
	gui.Adornee = adornee(prompt)

	local frame = Instance.new("TextButton")
	frame.Name = "Frame"
	frame.AutoButtonColor = false
	frame.Text = ""
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.Colors.Panel
	frame.BackgroundTransparency = 1
	frame.Active = touch
	frame.Selectable = false
	frame.Parent = gui

	local key = Instance.new("Frame")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Position = UDim2.new(0, 4, 0.5, 0)
	key.Size = UDim2.fromOffset(if touch then 56 else 42, if touch then 56 else 42)
	key.BackgroundColor3 = Theme.Colors.Panel
	key.BackgroundTransparency = 0.15
	key.ClipsDescendants = true
	key.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = key
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.TextBright
	stroke.Transparency = 0.35
	stroke.Thickness = 1.5
	stroke.Parent = key

	local fill = Instance.new("Frame")
	fill.Name = "Hold"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = Theme.Colors.Relay
	fill.BackgroundTransparency = 0.35
	fill.BorderSizePixel = 0
	fill.Parent = key

	local keyLabel = Instance.new("TextLabel")
	keyLabel.BackgroundTransparency = 1
	keyLabel.Size = UDim2.fromScale(1, 1)
	keyLabel.Font = Theme.Fonts.Bold
	keyLabel.TextSize = if touch then 24 else 20
	keyLabel.TextColor3 = Theme.Colors.TextBright
	keyLabel.Text = keyText(prompt, inputType)
	keyLabel.AutoLocalize = false
	keyLabel.ZIndex = 2
	keyLabel.Parent = key

	local action = Instance.new("TextLabel")
	action.BackgroundTransparency = 1
	action.Position = UDim2.new(0, key.Size.X.Offset + 14, 0, if touch then 10 else 6)
	action.Size = UDim2.new(1, -(key.Size.X.Offset + 16), 0, 24)
	action.Font = Theme.Fonts.Bold
	action.TextSize = if touch then 20 else 18
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextColor3 = Theme.Colors.TextBright
	action.TextStrokeTransparency = 0.5
	action.TextTruncate = Enum.TextTruncate.AtEnd
	action.AutoLocalize = false
	action.Parent = frame

	local object = action:Clone()
	object.Position = UDim2.new(0, key.Size.X.Offset + 14, 0, if touch then 34 else 30)
	object.Size = UDim2.new(1, -(key.Size.X.Offset + 16), 0, 20)
	object.Font = Theme.Fonts.Mono
	object.TextSize = 14
	object.TextColor3 = Theme.Colors.TextDim
	object.Parent = frame

	local function refreshText()
		action.Text = prompt.ActionText
		object.Text = prompt.ObjectText
	end
	refreshText()

	local connections = {
		prompt:GetPropertyChangedSignal("ActionText"):Connect(refreshText),
		prompt:GetPropertyChangedSignal("ObjectText"):Connect(refreshText),
	}
	local holdTween: Tween? = nil
	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			fill.Size = UDim2.fromScale(1, 0)
			holdTween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			;(holdTween :: Tween):Play()
		end
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
		end
		TweenService:Create(fill, Theme.Fast, { Size = UDim2.fromScale(1, 0) }):Play()
	end))
	table.insert(connections, prompt.Triggered:Connect(function()
		stroke.Color = Theme.Colors.Relay
		stroke.Transparency = 0
		TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 0.35, Color = Theme.Colors.TextBright }):Play()
	end))

	if touch then
		-- Large target: tap = trigger, hold = hold prompt
		table.insert(connections, frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end))
		table.insert(connections, frame.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end))
	end

	gui.Parent = playerGui
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		gui:Destroy()
	end
end

function PromptController.Init()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local cleanup = build(prompt, inputType)
		prompt.PromptHidden:Wait()
		cleanup()
	end)
end

return PromptController
