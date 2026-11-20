-- GameFlowService: session flow (menu -> in game), checkpoints and chapter hooks.
--
-- Party model: one Roblox server = one team (max 4, set "Max Players" to 4 in Game
-- Settings). Story progress is shared per server through SessionState. Nobody waits for
-- anyone: a player who presses Play enters immediately; friends who join later are
-- placed at the team's current checkpoint.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local SessionState = require(Shared.SessionState)

local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local CHECKPOINT_TAG = "FZ_Checkpoint"

local GameFlowService = {}

local chapters = {
	[1] = require(script.Parent.Parent.Chapters.Chapter1),
}

local inGame: { [Player]: boolean } = {}
local entered: { [Player]: boolean } = {} -- entered at least once this session

local function findCheckpoint(id: string): BasePart?
	for _, part in CollectionService:GetTagged(CHECKPOINT_TAG) do
		if part:IsA("BasePart") and part:GetAttribute("CheckpointId") == id then
			return part
		end
	end
	return nil
end

local function placeAtCheckpoint(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local checkpoint = findCheckpoint(SessionState.Get("Checkpoint") or "C1_START")
	if not checkpoint then
		return -- fall back to the default SpawnLocation
	end
	-- Spread the team a little so nobody spawns inside a teammate.
	local index = table.find(Players:GetPlayers(), player) or 1
	local offset = Vector3.new(((index - 1) % 2) * 3 - 1.5, 3, math.floor((index - 1) / 2) * 3)
	local target = checkpoint.CFrame * CFrame.new(offset)
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 5)
	end)
	if player.Character == character then
		character:PivotTo(target)
	end
end

function GameFlowService.SetCheckpoint(id: string)
	SessionState.Set("Checkpoint", id)
end

function GameFlowService.Start()
	SessionState.Set("Chapter", 1)
	SessionState.Set("Checkpoint", "C1_START")

	for _, chapter in chapters do
		chapter.Start()
	end

	local limiter = RateLimiter.new(2, 0.5)
	Net.Event("ClientReady").OnServerEvent:Connect(function(player: Player)
		if not limiter:Allow(player) or inGame[player] then
			return
		end
		inGame[player] = true
		player:SetAttribute("FZ_InGame", true)
		placeAtCheckpoint(player)
		local firstTime = not entered[player]
		entered[player] = true
		local chapter = chapters[SessionState.Get("Chapter") or 1]
		if chapter and chapter.OnPlayerEntered then
			chapter.OnPlayerEntered(player, firstTime)
		end
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if inGame[player] then
				task.defer(placeAtCheckpoint, player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		inGame[player] = nil
		entered[player] = nil
	end)
end

return GameFlowService
