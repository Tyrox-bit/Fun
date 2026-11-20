-- NoiseService: everything the creature can hear goes through here.
-- Footsteps are derived from server-side character velocity (no client trust needed):
-- standing still is silent, walking is quiet, sprinting is loud.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local NoiseService = {}
NoiseService.Heard = Signal.new() -- (position: Vector3, radius: number, source: Player?)

function NoiseService.Emit(position: Vector3, radius: number, source: Player?)
	NoiseService.Heard:Fire(position, radius, source)
end

function NoiseService.Start()
	task.spawn(function()
		while true do
			task.wait(0.4)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air and player:GetAttribute("FZ_InGame") and not player:GetAttribute("FZ_MonsterMode") then
					local velocity = root.AssemblyLinearVelocity
					local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
					if speed > Config.Movement.WalkSpeed + 2 then
						NoiseService.Emit(root.Position, Config.Noise.Sprint, player)
					elseif speed > 3 then
						NoiseService.Emit(root.Position, Config.Noise.Walk, player)
					end
				end
			end
		end
	end)
end

return NoiseService
