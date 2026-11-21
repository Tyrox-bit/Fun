-- HealthService: damage, downed state and revive. Nobody dies instantly:
--   damage -> downed (crawling) -> a teammate helps up (hold prompt)
--   solo, whole team down, or timeout -> back to the last checkpoint, nothing is lost.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local InteractionService = require(script.Parent.InteractionService)

local HealthService = {}

local HC = Config.Health
local lastDamage: { [Player]: number } = {}
local downedSince: { [Player]: number } = {}
local eliminatedAt: { [Player]: number } = {}
local savedHipHeight: { [Player]: number } = {}

-- Per-session statistics for achievements ("nobody left behind", "last survivor").
HealthService.SessionStats = { eliminated = {} :: { [Player]: boolean } }
function HealthService.ResetSessionStats()
	table.clear(HealthService.SessionStats.eliminated)
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function inGamePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("FZ_InGame") and not player:GetAttribute("FZ_MonsterMode") then
			table.insert(list, player)
		end
	end
	return list
end

function HealthService.IsDowned(player: Player): boolean
	return player:GetAttribute("FZ_Downed") == true
end

function HealthService.IsEliminated(player: Player): boolean
	return player:GetAttribute("FZ_Eliminated") == true
end

local function standing(player: Player): boolean
	return not HealthService.IsDowned(player) and not HealthService.IsEliminated(player)
end

local function setLowered(player: Player, lowered: boolean)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	if lowered then
		savedHipHeight[player] = savedHipHeight[player] or humanoid.HipHeight
		humanoid.HipHeight = (savedHipHeight[player] :: number) * 0.35 -- crawling on the floor
		humanoid.JumpHeight = 0
	elseif savedHipHeight[player] then
		humanoid.HipHeight = savedHipHeight[player] :: number
		humanoid.JumpHeight = 7.2
		savedHipHeight[player] = nil
	end
end

local function clearRevivePrompt(player: Player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		CollectionService:RemoveTag(root, "FZ_Interactable")
		local prompt = root:FindFirstChild("FZ_Prompt")
		if prompt then
			prompt:Destroy()
		end
	end
end

function HealthService.Respawn(player: Player)
	downedSince[player] = nil
	eliminatedAt[player] = nil
	savedHipHeight[player] = nil
	player:SetAttribute("FZ_Downed", false)
	player:SetAttribute("FZ_Eliminated", false)
	player:SetAttribute("FZ_DownedUntil", nil)
	clearRevivePrompt(player)
	player:LoadCharacter() -- SessionService places the new character at the checkpoint
end

-- Eliminated players come back at the next checkpoint / survival break (or after a max wait).
function HealthService.ReturnAllEliminated()
	for player in table.clone(eliminatedAt) do
		if player.Parent then
			HealthService.Respawn(player)
		end
	end
end

-- Optional override (survival: a wipe ends the run instead of a checkpoint respawn).
HealthService.TeamWipeHandler = nil :: (() -> ())?

local function checkTeamWipe()
	local players = inGamePlayers()
	if #players == 0 then
		return
	end
	for _, player in players do
		if standing(player) then
			return
		end
	end
	if HealthService.TeamWipeHandler then
		task.delay(2, HealthService.TeamWipeHandler)
		return
	end
	task.delay(3, function()
		for _, player in inGamePlayers() do
			if not standing(player) then
				Net.Event("Notify"):FireClient(player, "HUD_SIGNAL_LOST")
				HealthService.Respawn(player)
			end
		end
	end)
end

local function setDowned(player: Player, humanoid: Humanoid)
	humanoid.Health = 1
	player:SetAttribute("FZ_Downed", true)
	player:SetAttribute("FZ_DownedUntil", workspace:GetServerTimeNow() + HC.DownedTimeout)
	downedSince[player] = os.clock()
	setLowered(player, true)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root:SetAttribute("InteractId", "revive")
		root:SetAttribute("ActionKey", "INTERACT_REVIVE")
		root:SetAttribute("ObjectKey", "OBJECT_TEAMMATE")
		root:SetAttribute("HoldDuration", HC.ReviveHold)
		root:SetAttribute("MaxDistance", 7)
		CollectionService:AddTag(root, "FZ_Interactable")
	end
	checkTeamWipe()
end

function HealthService.Damage(player: Player, amount: number)
	local humanoid = humanoidOf(player)
	if not humanoid or not standing(player) or player:GetAttribute("FZ_MonsterMode") then
		return
	end
	lastDamage[player] = os.clock()
	Net.Event("Hurt"):FireClient(player, amount)
	if humanoid.Health - amount <= 1 then
		setDowned(player, humanoid)
	else
		humanoid.Health -= amount
	end
end

function HealthService.Revive(target: Player, healthValue: number)
	local humanoid = humanoidOf(target)
	if not humanoid or not HealthService.IsDowned(target) then
		return
	end
	clearRevivePrompt(target)
	downedSince[target] = nil
	target:SetAttribute("FZ_Downed", false)
	target:SetAttribute("FZ_DownedUntil", nil)
	setLowered(target, false)
	humanoid.Health = math.clamp(healthValue, 1, humanoid.MaxHealth)
	lastDamage[target] = os.clock()
end

function HealthService.Heal(player: Player, amount: number)
	local humanoid = humanoidOf(player)
	if humanoid and not HealthService.IsDowned(player) and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

function HealthService.HealAll()
	for _, player in Players:GetPlayers() do
		local humanoid = humanoidOf(player)
		if humanoid then
			if HealthService.IsDowned(player) then
				HealthService.Revive(player, humanoid.MaxHealth)
			end
			humanoid.Health = humanoid.MaxHealth
		end
	end
end

function HealthService.Start()
	InteractionService.Register("revive", function(helper, root)
		local target = Players:GetPlayerFromCharacter(root.Parent)
		if not target or target == helper or not standing(helper) or not HealthService.IsDowned(target) then
			return
		end
		-- A medkit is required for a full revive (first-aid cabinets / found in the world).
		local InventoryService = require(script.Parent.InventoryService)
		if not InventoryService.Take(helper, "medkit") then
			Net.Event("Notify"):FireClient(helper, "REVIVE_NEED_MEDKIT")
			return
		end
		local reviveHealth = tonumber(helper:GetAttribute("FZ_ReviveHealth")) or HC.ReviveHealth
		HealthService.Revive(target, reviveHealth)
	end)

	local function onCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		humanoid.MaxHealth = HC.Max
		humanoid.Health = HC.Max
		humanoid.BreakJointsOnDeath = false
		player:SetAttribute("FZ_Downed", false)
		player:SetAttribute("FZ_DownedUntil", nil)
		downedSince[player] = nil
		savedHipHeight[player] = nil
		if HealthService.IsEliminated(player) then
			task.defer(function()
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and HealthService.IsEliminated(player) then
					character:PivotTo(CFrame.new(0, 600, 0))
					root.Anchored = true
				end
			end)
		end
		humanoid.Died:Connect(function()
			-- Safety net (falls, resets): never a game over, just back to the checkpoint.
			task.delay(2, function()
				if player.Parent and player.Character == character then
					HealthService.Respawn(player)
				end
			end)
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastDamage[player] = nil
		downedSince[player] = nil
		eliminatedAt[player] = nil
		savedHipHeight[player] = nil
		HealthService.SessionStats.eliminated[player] = nil
		task.defer(checkTeamWipe)
	end)

	-- Regeneration and downed timeout (1 Hz is plenty)
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local humanoid = humanoidOf(player)
				if humanoid then
					local since = downedSince[player]
					local eliminatedSince = eliminatedAt[player]
					if eliminatedSince and now - eliminatedSince > HC.EliminatedMaxWait then
						HealthService.Respawn(player) -- never wait forever
					elseif since and now - since > HC.DownedTimeout then
						if #inGamePlayers() <= 1 then
							-- Solo: no elimination, back to the last checkpoint
							Net.Event("Notify"):FireClient(player, "HUD_SIGNAL_LOST")
							HealthService.Respawn(player)
						else
							-- Nobody came in time: out for this section / round, spectate the team
							downedSince[player] = nil
							clearRevivePrompt(player)
							setLowered(player, false)
							player:SetAttribute("FZ_Downed", false)
							player:SetAttribute("FZ_DownedUntil", nil)
							player:SetAttribute("FZ_Eliminated", true)
							eliminatedAt[player] = now
							HealthService.SessionStats.eliminated[player] = true
							Net.Event("Notify"):FireClient(player, "HUD_ELIMINATED")
							local character = player.Character
							local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
							if character and root then
								character:PivotTo(CFrame.new(0, 600, 0))
								root.Anchored = true
							end
							checkTeamWipe()
						end
					elseif not since and humanoid.Health > 0 then
						local cap = tonumber(player:GetAttribute("FZ_RegenCap")) or HC.RegenCap
						if now - (lastDamage[player] or 0) > HC.RegenDelay and humanoid.Health < cap then
							humanoid.Health = math.min(cap, humanoid.Health + HC.RegenPerSecond)
						end
					end
				end
			end
		end
	end)
end

return HealthService
