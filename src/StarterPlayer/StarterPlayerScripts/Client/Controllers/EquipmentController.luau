-- EquipmentController: client side of shop equipment.
--   Observer set: night vision (N / D-pad up / touch "Night") with a 30 s battery that
--   recharges, and fresh creature tracks (sent by the server only to observers).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local InputController = require(script.Parent.InputController)

local EquipmentController = {}

local player = Players.LocalPlayer
local BATTERY_SECONDS = 30
local battery = BATTERY_SECONDS
local active = false
local effect: ColorCorrectionEffect? = nil
local loop: RBXScriptConnection? = nil

local function setNightVision(on: boolean)
	if on and (not player:GetAttribute("FZ_NightVision") or battery < 2) then
		return
	end
	active = on
	InputController.SetTouchActive("NightVision", on)
	if not effect then
		local e = Instance.new("ColorCorrectionEffect")
		e.Name = "FZ_NightVision"
		e.Enabled = false
		e.Parent = Lighting
		effect = e
	end
	local e = effect :: ColorCorrectionEffect
	e.Enabled = true
	TweenService:Create(e, TweenInfo.new(0.25), {
		Brightness = if on then 0.32 else 0,
		Contrast = if on then 0.25 else 0,
		Saturation = if on then -0.9 else 0,
		TintColor = if on then Color3.fromRGB(150, 255, 170) else Color3.new(1, 1, 1),
	}):Play()
	if not loop then
		loop = RunService.Heartbeat:Connect(function(dt)
			if active then
				battery -= dt
				if battery <= 0 then
					battery = 0
					setNightVision(false)
				end
			else
				battery = math.min(BATTERY_SECONDS, battery + dt * 0.5)
				if battery >= BATTERY_SECONDS and loop then
					loop:Disconnect()
					loop = nil
				end
			end
		end)
	end
end

local function footprint(position: Vector3)
	if typeof(position) ~= "Vector3" then
		return
	end
	local mark = Instance.new("Part")
	mark.Name = "FZ_Track"
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.CastShadow = false
	mark.Size = Vector3.new(1.2, 0.05, 2.2)
	mark.CFrame = CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi, 0)
	mark.Material = Enum.Material.Neon
	mark.Color = Color3.fromRGB(150, 30, 26)
	mark.Transparency = 0.35
	mark.Parent = workspace.CurrentCamera
	local fade = TweenService:Create(mark, TweenInfo.new(18, Enum.EasingStyle.Linear), { Transparency = 1 })
	fade.Completed:Once(function()
		mark:Destroy()
	end)
	fade:Play()
end

function EquipmentController.SetActive(gameplay: boolean)
	if not gameplay and active then
		setNightVision(false)
	end
end

function EquipmentController.Init()
	local function refresh()
		local owned = player:GetAttribute("FZ_NightVision") == true
		InputController.SetTouchVisible("NightVision", owned)
		if not owned and active then
			setNightVision(false)
		end
	end
	player:GetAttributeChangedSignal("FZ_NightVision"):Connect(refresh)
	refresh()
	InputController.Action:Connect(function(name, pressed)
		if name == "NightVision" and pressed then
			setNightVision(not active)
		end
	end)
	Net.Event("Footprint").OnClientEvent:Connect(footprint)
end

return EquipmentController
