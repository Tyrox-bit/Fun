-- MovementGuardService: server-side sanity check against speed exploits.
-- Player characters are simulated on the client, so the server compares the distance
-- moved between checks with what is possible (sprint + tolerance, admin speed x2).
-- Violations pull the character back to the last valid position and are logged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MovementGuardService = {}

local INTERVAL = 0.5
local TOLERANCE = 1.45 -- lag, slopes, knockback
local lastValid: { [Player]: { position: Vector3, time: number } } = {}
local strikes: { [Player]: number } = {}

local function allowedSpeed(player: Player): number
	local speed = Config.Movement.SprintSpeed
	if player:GetAttribute("FZ_AdminSpeed") then
		speed *= 2
	end
	if player:GetAttribute("FZ_MonsterMode") then
		speed = 30
	end
	return speed * TOLERANCE
end

function MovementGuardService.Forget(player: Player)
	lastValid[player] = nil
end

function MovementGuardService.Start(logViolation: ((Player, string) -> ())?)
	local report = logViolation or function(player: Player, message: string)
		warn(string.format("[FZ-Guard] %s (%d): %s", player.Name, player.UserId, message))
	end
	Players.PlayerRemoving:Connect(function(player)
		lastValid[player] = nil
		strikes[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			lastValid[player] = nil -- respawns and checkpoint placement are legitimate jumps
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(INTERVAL)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and player:GetAttribute("FZ_InGame") then
					local last = lastValid[player]
					local position = root.Position
					if last and not player:GetAttribute("FZ_Teleporting") then
						local moved = Vector3.new(position.X - last.position.X, 0, position.Z - last.position.Z).Magnitude
						local possible = allowedSpeed(player) * (now - last.time) + 2
						if moved > possible then
							strikes[player] = (strikes[player] or 0) + 1
							if strikes[player] >= 2 then
								root.CFrame = CFrame.new(last.position) * root.CFrame.Rotation
								root.AssemblyLinearVelocity = Vector3.zero
								report(player, string.format("moved %.1f studs, max %.1f", moved, possible))
								strikes[player] = 0
								continue
							end
						else
							strikes[player] = 0
						end
					end
					lastValid[player] = { position = position, time = now }
				else
					lastValid[player] = nil
				end
			end
		end
	end)
end

return MovementGuardService
