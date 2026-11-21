-- MovementController: slow walk, short limited sprint with stamina.
-- Keyboard: hold to sprint. Gamepad (L3) and touch: toggle, ends automatically when the
-- player stops moving or runs out of breath. No permanent sprinting by design.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local InputController = require(script.Parent.InputController)

local MovementController = {}

local M = Config.Movement
local player = Players.LocalPlayer

local stamina = 1
local exhausted = false
local wantsSprint = false
local sprinting = false
local regenTimer = 0
local heartbeat: RBXScriptConnection? = nil
local settings = nil
local onStamina: ((number, boolean) -> ())? = nil

local function cameraEffectsScale(): number
	local value = settings and settings.Get("cameraEffects") or "full"
	return if value == "off" then 0 elseif value == "reduced" then 0.5 else 1
end

local function setSprinting(value: boolean)
	if sprinting == value then
		return
	end
	sprinting = value
	InputController.SetTouchActive("Sprint", value)
	local camera = workspace.CurrentCamera
	if camera then
		local fov = M.BaseFov + (if value then M.SprintFovBoost * cameraEffectsScale() else 0)
		TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { FieldOfView = fov }):Play()
	end
end

local function step(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	if not moving and InputController.GetDevice() ~= "keyboard" then
		wantsSprint = false -- toggle sprint ends when the player stops
	end

	local canSprint = wantsSprint and moving and not exhausted and stamina > 0 and not player:GetAttribute("FZ_Downed")
	setSprinting(canSprint)

	if sprinting then
		stamina = math.max(0, stamina - dt / M.StaminaSeconds)
		regenTimer = M.RegenDelay
		if stamina <= 0 then
			exhausted = true
			wantsSprint = false
		end
	else
		regenTimer = math.max(0, regenTimer - dt)
		if regenTimer <= 0 then
			stamina = math.min(1, stamina + dt / M.RegenSeconds)
		end
		if exhausted and stamina >= M.ExhaustedThreshold then
			exhausted = false
		end
	end

	if player:GetAttribute("FZ_MonsterMode") then
		return -- the creature rig keeps the speed the server gave it
	end
	local speed = if sprinting then M.SprintSpeed else M.WalkSpeed
	if player:GetAttribute("FZ_Downed") then
		speed = Config.Health.CrawlSpeed
		wantsSprint = false
	end
	if player:GetAttribute("FZ_Rescuing") or player:GetAttribute("FZ_Eliminated") then
		speed = 0 -- kneeling next to a teammate: you cannot run away while helping
		wantsSprint = false
	end
	if player:GetAttribute("FZ_AdminSpeed") then
		speed *= 2
	end
	humanoid.WalkSpeed = speed
	if onStamina then
		onStamina(stamina, exhausted)
	end
end

function MovementController.Init(settingsController, staminaCallback: (number, boolean) -> ())
	settings = settingsController
	onStamina = staminaCallback
	InputController.Action:Connect(function(name, pressed, device)
		if name ~= "Sprint" then
			return
		end
		if device == "keyboard" then
			wantsSprint = pressed
		elseif pressed then
			wantsSprint = not wantsSprint
		end
	end)
end

function MovementController.SetActive(active: boolean)
	if active and not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(step)
	elseif not active and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
		wantsSprint = false
		setSprinting(false)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = M.WalkSpeed
		end
	end
end

return MovementController
