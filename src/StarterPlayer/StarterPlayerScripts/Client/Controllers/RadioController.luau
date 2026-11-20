-- RadioController: the walkie-talkie in your hand.
--   * Push to talk (R / LB / touch "Radio"), hold or toggle (Settings -> Radio button)
--   * Mute / unmute your own microphone (M / D-pad left / touch "Mic")
--   * Viewmodel: raised while transmitting, half-raised while receiving, otherwise away
--   * Small HUD line: "TRANSMITTING", "Receiving: name", "Microphone muted"
-- Transmitting is audible to the creature (server NoiseService) - talk with care.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local InputController = require(script.Parent.InputController)
local VoiceController = require(script.Parent.VoiceController)
local AudioController = require(script.Parent.AudioController)

local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)

local RadioController = {}

local player = Players.LocalPlayer
local settings = nil
local transmitting = false
local muted = false
local receiving: { string } = {}

local viewmodel: Model? = nil
local led: BasePart? = nil
local body: BasePart? = nil
local render: RBXScriptConnection? = nil
local pose = 0 -- 0 hidden, 0.5 receiving, 1 transmitting

local statusLabel: TextLabel
local micLabel: TextLabel

local HIDDEN = CFrame.new(0.9, -2.8, -1.4) * CFrame.Angles(math.rad(-30), 0, 0)
local HALF = CFrame.new(0.95, -1.45, -1.7) * CFrame.Angles(math.rad(8), math.rad(-14), math.rad(-6))
local RAISED = CFrame.new(0.55, -0.85, -1.35) * CFrame.Angles(math.rad(14), math.rad(-24), math.rad(-10))

local function part(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

local function buildViewmodel(): Model
	local model = Instance.new("Model")
	model.Name = "FZ_RadioViewmodel"
	local color = player:GetAttribute("FZ_RadioColor")
	local b = part(model, "Body", Vector3.new(0.75, 1.7, 0.42), if typeof(color) == "Color3" then color else Color3.fromRGB(46, 48, 50), Enum.Material.SmoothPlastic)
	model.PrimaryPart = b
	body = b
	local antenna = part(model, "Antenna", Vector3.new(0.14, 1.3, 0.14), Color3.fromRGB(26, 26, 26), Enum.Material.Rubber)
	antenna:SetAttribute("Offset", CFrame.new(-0.22, 1.45, 0))
	local screen = part(model, "Screen", Vector3.new(0.56, 0.42, 0.05), Color3.fromRGB(255, 150, 60), Enum.Material.Neon)
	screen.Transparency = 0.15
	screen:SetAttribute("Offset", CFrame.new(0, 0.42, -0.22))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 200
	gui.AutoLocalize = false
	gui.Parent = screen
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.RobotoMono
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(40, 16, 0)
	text.Text = "CH-07\nRELAIS"
	text.AutoLocalize = false
	text.Parent = gui
	local grille = part(model, "Speaker", Vector3.new(0.5, 0.5, 0.05), Color3.fromRGB(20, 20, 20), Enum.Material.DiamondPlate)
	grille:SetAttribute("Offset", CFrame.new(0, -0.35, -0.22))
	local l = part(model, "Led", Vector3.new(0.1, 0.1, 0.06), Color3.fromRGB(60, 20, 20), Enum.Material.Neon)
	l:SetAttribute("Offset", CFrame.new(0.26, 0.74, -0.22))
	led = l
	local knob = part(model, "Knob", Vector3.new(0.18, 0.2, 0.18), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
	knob:SetAttribute("Offset", CFrame.new(0.2, 0.92, 0))
	return model
end

local function placeViewmodel(cframe: CFrame)
	local model = viewmodel :: Model
	local b = body :: BasePart
	b.CFrame = cframe
	for _, child in model:GetChildren() do
		if child ~= b and child:IsA("BasePart") then
			local offset = child:GetAttribute("Offset")
			if typeof(offset) == "CFrame" then
				child.CFrame = cframe * offset
			end
		end
	end
end

local function targetPose(): number
	if transmitting then
		return 1
	elseif #receiving > 0 then
		return 0.5
	end
	return 0
end

local function ensureRender()
	if render then
		return
	end
	render = RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local goal = targetPose()
		pose += (goal - pose) * math.min(1, dt * 9)
		if math.abs(goal - pose) < 0.01 then
			pose = goal
		end
		if pose <= 0.001 and goal == 0 then
			if viewmodel then
				viewmodel:Destroy()
				viewmodel = nil
			end
			(render :: RBXScriptConnection):Disconnect()
			render = nil
			return
		end
		if not viewmodel or not viewmodel.Parent then
			viewmodel = buildViewmodel()
			viewmodel.Parent = camera
		end
		local offset = if pose <= 0.5 then HIDDEN:Lerp(HALF, pose * 2) else HALF:Lerp(RAISED, (pose - 0.5) * 2)
		local t = os.clock()
		local sway = CFrame.new(math.sin(t * 1.3) * 0.015, math.sin(t * 2.1) * 0.012, 0)
		placeViewmodel(camera.CFrame * offset * sway)
		if led then
			led.Color = if transmitting then Color3.fromRGB(255, 40, 30) elseif #receiving > 0 then Color3.fromRGB(80, 255, 120) else Color3.fromRGB(60, 20, 20)
		end
	end)
end

local function refreshHud()
	if transmitting then
		statusLabel.TextColor3 = Theme.Colors.Accent
		Localization.Bind(statusLabel, "RADIO_TX")
		statusLabel.Text = "● " .. statusLabel.Text
		statusLabel.Visible = true
	elseif #receiving > 0 then
		statusLabel.TextColor3 = Theme.Colors.Relay
		Localization.Bind(statusLabel, "RADIO_RX", { name = table.concat(receiving, ", ") })
		statusLabel.Visible = true
	else
		statusLabel.Visible = false
	end
	micLabel.Visible = muted
end

local function setTransmitting(value: boolean)
	if transmitting == value then
		return
	end
	transmitting = value
	Net.Event("RadioState"):FireServer(value)
	AudioController.Play(if value then "radio_squelch_on" else "radio_squelch_off", nil, 0.5, "SFX")
	InputController.SetTouchActive("Radio", value)
	ensureRender()
	refreshHud()
end

local function setMuted(value: boolean)
	muted = value
	Net.Event("MicMute"):FireServer(value)
	InputController.SetTouchActive("Mic", value)
	refreshHud()
end

function RadioController.IsMuted(): boolean
	return muted
end

function RadioController.ToggleMute()
	setMuted(not muted)
end

-- Called when gameplay is paused (menus, documents, downed is fine).
function RadioController.Stop()
	setTransmitting(false)
end

function RadioController.Init(hudGui: ScreenGui, settingsController)
	settings = settingsController
	statusLabel = Components.Text({ Text = "", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Accent, Size = UDim2.fromOffset(360, 20), Position = UDim2.new(0, 24, 1, -64), Parent = hudGui })
	statusLabel.Visible = false
	statusLabel.TextStrokeTransparency = 0.5
	micLabel = Components.Text({ Key = "MIC_OFF", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, Size = UDim2.fromOffset(360, 20), Position = UDim2.new(0, 24, 1, -40), Parent = hudGui })
	micLabel.Visible = false
	micLabel.TextStrokeTransparency = 0.5

	InputController.Action:Connect(function(name, pressed)
		if name == "Radio" then
			if settings.Get("radioMode") == "toggle" then
				if pressed then
					setTransmitting(not transmitting)
				end
			else
				setTransmitting(pressed)
			end
		elseif name == "Mic" and pressed then
			setMuted(not muted)
		end
	end)

	VoiceController.ReceivingChanged:Connect(function(names)
		receiving = names
		ensureRender()
		refreshHud()
	end)
	Localization.Changed:Connect(refreshHud)
	player:GetAttributeChangedSignal("FZ_RadioColor"):Connect(function()
		if viewmodel then
			viewmodel:Destroy()
			viewmodel = nil
		end
	end)
end

return RadioController
