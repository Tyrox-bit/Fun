-- DoorService: sliding doors (tag FZ_Door). Opening makes noise; locked doors buzz.
-- The creature opens unlocked doors in its way (CreatureService calls Open).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local InteractionService = require(script.Parent.InteractionService)
local NoiseService = require(script.Parent.NoiseService)

local DoorService = {}

local TWEEN = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local busy: { [Instance]: boolean } = {}

local function setOpen(panel: BasePart, open: boolean)
	if busy[panel] or panel:GetAttribute("Open") == open then
		return
	end
	busy[panel] = true
	panel:SetAttribute("Open", open)
	local target = panel:GetAttribute(if open then "OpenCFrame" else "ClosedCFrame")
	Net.Event("Sfx"):FireAllClients("door_open", panel.Position)
	NoiseService.Emit(panel.Position, Config.Noise.Door, nil)
	local tween = TweenService:Create(panel, TWEEN, { CFrame = target })
	tween.Completed:Once(function()
		busy[panel] = nil
	end)
	tween:Play()
end

function DoorService.Open(panel: BasePart)
	if not panel:GetAttribute("Locked") then
		setOpen(panel, true)
	end
end

function DoorService.Close(panel: BasePart)
	setOpen(panel, false)
end

function DoorService.SetLocked(panel: BasePart, locked: boolean)
	panel:SetAttribute("Locked", locked)
	local stripe = panel:FindFirstChild("Stripe")
	if stripe and stripe:IsA("BasePart") then
		stripe.Color = if locked then Color3.fromRGB(200, 40, 30) else Color3.fromRGB(90, 220, 140)
	end
	local modifier = panel:FindFirstChildOfClass("PathfindingModifier")
	if modifier then
		modifier.PassThrough = not locked
	end
	if locked and panel:GetAttribute("Open") then
		setOpen(panel, false)
	end
end

-- Closes every door and restores its locked state from the map (a chapter may have
-- unlocked a door in an earlier run - maps are reused between sessions).
function DoorService.CloseAll()
	for _, panel in CollectionService:GetTagged("FZ_Door") do
		if panel:IsA("BasePart") then
			if panel:GetAttribute("LockedAtStart") == nil then
				panel:SetAttribute("LockedAtStart", panel:GetAttribute("Locked") == true)
			end
			if (panel:GetAttribute("PowerSector") or "") == "" then
				DoorService.SetLocked(panel, panel:GetAttribute("LockedAtStart") == true)
			end
			setOpen(panel, false)
		end
	end
end

function DoorService.Start()
	InteractionService.Register("door", function(player, panel)
		if not panel:IsA("BasePart") then
			return
		end
		if panel:GetAttribute("Locked") then
			Net.Event("Sfx"):FireAllClients("door_locked", panel.Position)
			Net.Event("Notify"):FireClient(player, "DOOR_LOCKED")
			return
		end
		setOpen(panel, not panel:GetAttribute("Open"))
	end)
end

return DoorService
