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
	player:SetAttribute("FZ_Downed", false)
	clearRevivePrompt(player)
	player:LoadCharacter() -- SessionService places the new character at the checkpoint
end

-- Optional override (survival: a wipe ends the run instead of a checkpoint respawn).
HealthService.TeamWipeHandler = nil :: (() -> ())?

local function checkTeamWipe()
	local players = inGamePlayers()
	if #players == 0 then
		return
	end
	for _, player in players do
		if not HealthService.IsDowned(player) then
			return
		end
	end
	if HealthService.TeamWipeHandler then
		task.delay(2, HealthService.TeamWipeHandler)
		return
	end
	task.delay(3, function()
		for _, player in inGamePlayers() do
			if HealthService.IsDowned(player) then
				Net.Event("Notify"):FireClient(player, "HUD_SIGNAL_LOST")
				HealthService.Respawn(player)
			end
		end
	end)
end

local function setDowned(player: Player, humanoid: Humanoid)
	humanoid.Health = 1
	player:SetAttribute("FZ_Downed", true)
	downedSince[player] = os.clock()
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
	if not humanoid or HealthService.IsDowned(player) or player:GetAttribute("FZ_MonsterMode") then
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
	humanoid.Health = math.clamp(healthValue, 1, humanoid.MaxHealth)
	lastDamage[target] = os.clock()
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
		if not target or target == helper or HealthService.IsDowned(helper) then
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
		downedSince[player] = nil
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
					if since and now - since > HC.DownedTimeout then
						Net.Event("Notify"):FireClient(player, "HUD_SIGNAL_LOST")
						HealthService.Respawn(player)
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
