-- DirectorService ("HorrorDirector"): decides WHEN a scare happens, so scares stay earned.
--   * Global gap between scares (70 s) and per-player gap (60 s) against habituation
--   * Never the same scare type twice in a row; nothing while a creature is chasing
--   * Many beats target ONE player only ("Did you see that too?")
--   * Optional hints when the team is stuck on an objective for a long time
-- The visual/audio side runs on the clients (DirectorController), scaled by each
-- player's own "Scare intensity" setting.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local SessionState = require(Shared.SessionState)

local StoryService = require(script.Parent.StoryService)
local CreatureService = require(script.Parent.CreatureService)

local DirectorService = {}

local GLOBAL_GAP = 70
local PLAYER_GAP = 60
local HINT_AFTER = 150

export type Beat = {
	id: string,
	kind: string, -- apparition | footsteps | flicker | cctv | namecall | doorslam
	once: boolean?,
	condition: (player: Player, info: { [string]: any }) -> boolean,
	data: ((player: Player) -> { [string]: any })?,
	others: boolean?, -- also notify the other players (for "cctv": they see it WITHOUT the figure)
}

local beats: { Beat } = {}
local used: { [string]: boolean } = {}
local lastGlobal = 0
local lastKind: string? = nil
local lastForPlayer: { [Player]: number } = {}
local hints: { [string]: string } = {}
local objectiveSince = os.clock()
local lastObjective: any = nil
local lastHint = 0
local enabled = false
local playersInGame: (() -> { Player })? = nil

function DirectorService.AreaOf(position: Vector3): string?
	local best, bestDistance = nil, 45
	for _, node in CollectionService:GetTagged("FZ_CreaturePatrol") do
		if node:IsA("BasePart") then
			local d = (node.Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = node:GetAttribute("Area"), d
			end
		end
	end
	return best
end

-- Called by a mode when it begins / stops.
function DirectorService.Configure(newBeats: { Beat }, newHints: { [string]: string }, voters: () -> { Player })
	beats = newBeats
	hints = newHints
	playersInGame = voters
	table.clear(used)
	table.clear(lastForPlayer)
	lastGlobal = os.clock() - GLOBAL_GAP + 45 -- first scare no earlier than ~45 s in
	lastKind = nil
	objectiveSince = os.clock()
	lastHint = 0
	enabled = true
end

function DirectorService.Stop()
	enabled = false
	beats = {}
	hints = {}
end

local function fire(beat: Beat, player: Player)
	used[beat.id] = true
	lastGlobal = os.clock()
	lastKind = beat.kind
	lastForPlayer[player] = os.clock()
	local data = if beat.data then beat.data(player) else {}
	Net.Event("Scare"):FireClient(player, beat.kind, data)
	if beat.others and playersInGame then
		local quiet = table.clone(data)
		quiet.withFigure = false
		for _, other in playersInGame() do
			if other ~= player then
				Net.Event("Scare"):FireClient(other, beat.kind, quiet)
			end
		end
	end
end

local function nearestTeammate(player: Player, players: { Player }): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local best = math.huge
	if not root then
		return best
	end
	for _, other in players do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if otherRoot then
			best = math.min(best, (otherRoot.Position - root.Position).Magnitude)
		end
	end
	return best
end

function DirectorService.Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			if not enabled or not playersInGame then
				continue
			end
			local now = os.clock()
			local players = playersInGame()

			-- Hints when stuck
			local objective = SessionState.Get("Objective")
			if objective ~= lastObjective then
				lastObjective = objective
				objectiveSince = now
			elseif type(objective) == "string" and hints[objective] and now - objectiveSince > HINT_AFTER and now - lastHint > HINT_AFTER then
				lastHint = now
				StoryService.Say("all", { speaker = "SPEAKER_RELAY", text = hints[objective], channel = "radio", duration = 5 })
			end

			-- Security cameras: where is the creature?
			if SessionState.Get("Cameras") then
				local creature = CreatureService.Get()
				local root = creature and creature:FindFirstChild("HumanoidRootPart") :: BasePart?
				SessionState.Set("CctvArea", if root then DirectorService.AreaOf(root.Position) or "?" else "-")
			end

			if now - lastGlobal < GLOBAL_GAP then
				continue
			end
			for _, player in players do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and not player:GetAttribute("FZ_Downed") and now - (lastForPlayer[player] or 0) > PLAYER_GAP and not CreatureService.IsChasingNear(root.Position, 60) then
					local info = {
						position = root.Position,
						area = DirectorService.AreaOf(root.Position),
						alone = nearestTeammate(player, players) > 25,
					}
					local fired = false
					for _, beat in beats do
						if not (beat.once and used[beat.id]) and beat.kind ~= lastKind and beat.condition(player, info) then
							fire(beat, player)
							fired = true
							break
						end
					end
					if fired then
						break
					end
				end
			end
		end
	end)
end

return DirectorService
