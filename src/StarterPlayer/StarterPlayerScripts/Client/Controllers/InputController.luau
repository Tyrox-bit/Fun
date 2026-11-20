-- InputController: one logical action layer for keyboard/mouse, gamepad and touch.
--
-- Primary path: Roblox Input Action System (InputContext / InputAction / InputBinding).
-- Fallback path: UserInputService, used automatically if the Input Action System cannot be
-- created on this client (or when Config FORCE_LEGACY is set for debugging).
--
-- Gameplay code only ever sees logical actions:
--   InputController.Action:Connect(function(name, pressed, device) ... end)
-- Interactions themselves use ProximityPrompts (E / X / tap) via InteractionService.
--
-- Default bindings
--   Sprint      LeftShift | L3 (left stick click) | touch "Run" (toggle)
--   Flashlight  F         | R1 / RB               | touch "Light"
--   Pause       P         | View / Share (Select) | touch "II"
-- GuiService.AutoSelectGuiEnabled is turned off so the Select button is free for our
-- menu; the Router sets gamepad focus explicitly whenever a menu opens.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Signal)
local Localization = require(Shared.Localization)

local Theme = require(script.Parent.Parent.UI.Theme)

local FORCE_LEGACY = false

export type Device = "keyboard" | "gamepad" | "touch"

local InputController = {}
InputController.Action = Signal.new() -- (name: string, pressed: boolean, device: Device)
InputController.DeviceChanged = Signal.new() -- (device: Device)

local ACTIONS = {
	{ name = "Sprint", keys = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 }, touchKey = "TOUCH_SPRINT" },
	{ name = "Flashlight", keys = { Enum.KeyCode.F, Enum.KeyCode.ButtonR1 }, touchKey = "TOUCH_LIGHT" },
	{ name = "Pause", keys = { Enum.KeyCode.P, Enum.KeyCode.ButtonSelect }, touchText = "II", small = true },
}

local device: Device = "keyboard"
local gameplayEnabled = false
local usingActionSystem = false
local held: { [string]: boolean } = {}
local touchButtons: { [string]: TextButton } = {}
local touchContainer: Frame? = nil
local context: Instance? = nil

local function fire(name: string, pressed: boolean)
	if pressed then
		if not gameplayEnabled or UserInputService:GetFocusedTextBox() then
			return
		end
		if held[name] then
			return
		end
		held[name] = true
	else
		if not held[name] then
			return
		end
		held[name] = nil
	end
	InputController.Action:Fire(name, pressed, device)
end

---------------------------------------------------------------------------
-- Device detection
---------------------------------------------------------------------------

local function deviceFromLastInput(inputType: Enum.UserInputType): Device?
	if inputType == Enum.UserInputType.Touch then
		return "touch"
	end
	local name = inputType.Name
	if string.sub(name, 1, 7) == "Gamepad" then
		return "gamepad"
	end
	if inputType == Enum.UserInputType.Keyboard or string.sub(name, 1, 5) == "Mouse" then
		return "keyboard"
	end
	return nil
end

local function setDevice(newDevice: Device?)
	if not newDevice or newDevice == device then
		return
	end
	device = newDevice
	if touchContainer then
		touchContainer.Visible = gameplayEnabled and device == "touch"
	end
	InputController.DeviceChanged:Fire(device)
end

local function readPreferredInput(): Device?
	local ok, preferred = pcall(function()
		return (UserInputService :: any).PreferredInput
	end)
	if not ok or preferred == nil then
		return nil
	end
	if preferred == Enum.PreferredInput.Touch then
		return "touch"
	elseif preferred == Enum.PreferredInput.Gamepad then
		return "gamepad"
	end
	return "keyboard"
end

local function initDeviceDetection()
	local preferred = readPreferredInput()
	if preferred then
		device = preferred
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
			setDevice(readPreferredInput())
		end)
	else
		device = deviceFromLastInput(UserInputService:GetLastInputType())
			or (if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "touch" else "keyboard")
		UserInputService.LastInputTypeChanged:Connect(function(inputType)
			setDevice(deviceFromLastInput(inputType))
		end)
	end
end

---------------------------------------------------------------------------
-- Touch buttons (large, few, right thumb area; Pause sits top-right)
---------------------------------------------------------------------------

local function createTouchButtons(parent: ScreenGui)
	local container = Instance.new("Frame")
	container.Name = "TouchControls"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Visible = false
	container.Parent = parent
	touchContainer = container

	local index = 0
	for _, definition in ACTIONS do
		local button = Instance.new("TextButton")
		button.Name = definition.name
		button.AutoButtonColor = false
		button.AutoLocalize = false
		button.BackgroundColor3 = Theme.Colors.Panel
		button.BackgroundTransparency = 0.35
		button.TextColor3 = Theme.Colors.TextBright
		button.Font = Theme.Fonts.Medium
		button.TextSize = 15
		button.Selectable = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Colors.TextFaint
		stroke.Transparency = 0.3
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button
		if definition.small then
			button.Size = UDim2.fromOffset(48, 48)
			button.AnchorPoint = Vector2.new(1, 0)
			button.Position = UDim2.new(1, -16, 0, 8)
		else
			button.Size = UDim2.fromOffset(72, 72)
			button.AnchorPoint = Vector2.new(1, 1)
			button.Position = UDim2.new(1, -150 - index * 84, 1, -28 - index * 60)
			index += 1
		end
		if definition.touchKey then
			Localization.Bind(button, definition.touchKey)
		else
			button.Text = definition.touchText or ""
		end
		button.Parent = container
		touchButtons[definition.name] = button
	end
end

---------------------------------------------------------------------------
-- Binding paths
---------------------------------------------------------------------------

local function bindWithActionSystem(): boolean
	local ok, err = pcall(function()
		local newContext = Instance.new("InputContext")
		newContext.Name = "FZ_Gameplay"
		for _, definition in ACTIONS do
			local action = Instance.new("InputAction")
			action.Name = definition.name
			action.Type = Enum.InputActionType.Bool
			for _, key in definition.keys do
				local binding = Instance.new("InputBinding")
				binding.KeyCode = key
				binding.Parent = action
			end
			local touchButton = touchButtons[definition.name]
			if touchButton then
				local binding = Instance.new("InputBinding")
				binding.UIButton = touchButton
				binding.Parent = action
			end
			action.Pressed:Connect(function()
				fire(definition.name, true)
			end)
			action.Released:Connect(function()
				fire(definition.name, false)
			end)
			action.Parent = newContext
		end
		newContext.Enabled = gameplayEnabled
		newContext.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
		context = newContext
	end)
	if not ok then
		warn("[FZ-Input] Input Action System unavailable, using fallback: " .. tostring(err))
		if context then
			context:Destroy()
			context = nil
		end
	end
	return ok
end

local function bindWithFallback()
	local keyToAction: { [Enum.KeyCode]: string } = {}
	for _, definition in ACTIONS do
		for _, key in definition.keys do
			keyToAction[key] = definition.name
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local name = keyToAction[input.KeyCode]
		if name then
			fire(name, true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local name = keyToAction[input.KeyCode]
		if name then
			fire(name, false)
		end
	end)
	for name, button in touchButtons do
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				fire(name, true)
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				fire(name, false)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function InputController.Init(hudGui: ScreenGui)
	GuiService.AutoSelectGuiEnabled = false
	initDeviceDetection()
	createTouchButtons(hudGui)
	usingActionSystem = not FORCE_LEGACY and bindWithActionSystem()
	if not usingActionSystem then
		bindWithFallback()
	end
end

function InputController.GetDevice(): Device
	return device
end

function InputController.IsUsingActionSystem(): boolean
	return usingActionSystem
end

function InputController.SetGameplayEnabled(enabled: boolean)
	gameplayEnabled = enabled
	if context then
		(context :: any).Enabled = enabled
	end
	if touchContainer then
		touchContainer.Visible = enabled and device == "touch"
	end
	if not enabled then
		-- Release everything that is still held so nothing gets stuck "on".
		for name in table.clone(held) do
			held[name] = nil
			InputController.Action:Fire(name, false, device)
		end
	end
end

-- Lets gameplay code reflect state on touch buttons (e.g. sprint toggle highlighted).
function InputController.SetTouchActive(name: string, active: boolean)
	local button = touchButtons[name]
	if button then
		button.BackgroundColor3 = if active then Theme.Colors.Accent else Theme.Colors.Panel
	end
end

return InputController
