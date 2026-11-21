-- SessionService: what the team in this server is currently playing.
--
--   One Roblox server = one team = at most one running session:
--     { mode = "story" | "survival", contentId = "ch1" | "sv_relay07" | ..., mapId }
--   * The first player who picks something starts it; teammates join it with one tap.
--   * Picking something else while teammates are playing: if that content has its own
--     place, the player is teleported to a fresh reserved server; otherwise "busy".
--   * Nobody in game for a while -> the session ends and the map is free again.
--   * Players who arrive by teleport with a valid selection start/join automatically.
-- Mode modules (Chapters/*, Modes/*) implement: Init(context), Begin(entry), Stop(),
-- OnPlayerEntered(player, firstTime), StartCheckpoint.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
local Net = require(Shared.Net)
local SessionState = require(Shared.SessionState)

local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local PlaceService = require(script.Parent.PlaceService)
local CreatureService = require(script.Parent.CreatureService)
local HealthService = require(script.Parent.HealthService)
local PowerService = require(script.Parent.PowerService)
local DoorService = require(script.Parent.DoorService)
local InventoryService = require(script.Parent.InventoryService)
local AnalyticsTracker = require(script.Parent.AnalyticsTracker)
local PartyService = require(script.Parent.PartyService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local SessionService = {}

local MODULES = {
	story = {
		ch1 = require(script.Parent.Parent.Chapters.Chapter1),
	},
	survival = {
		sv_relay07 = require(script.Parent.Parent.Modes.Survival),
	},
}

type Session = { mode: string, contentId: string, mapId: string, module: any, idleSince: number? }
local session: Session? = nil
local REJOIN_WINDOW = 15 * 60
local reservedCode: string? = nil -- known when this server was reached via a reserved teleport
local inGame: { [Player]: boolean } = {}
local entered: { [Player]: boolean } = {}

---------------------------------------------------------------------------
-- Checkpoints
---------------------------------------------------------------------------
local function findCheckpoint(id: string): BasePart?
	for _, part in CollectionService:GetTagged("FZ_Checkpoint") do
		if part:IsA("BasePart") and part:GetAttribute("CheckpointId") == id then
			return part
		end
	end
	return nil
end

local function placeAtCheckpoint(player: Player)
	local character = player.Character
	if not character or player:GetAttribute("FZ_MonsterMode") then
		return
	end
	local checkpoint = findCheckpoint(SessionState.Get("Checkpoint") or "C1_START")
	if not checkpoint then
		return
	end
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

function SessionService.SetCheckpoint(id: string)
	local changed = SessionState.Get("Checkpoint") ~= id
	SessionState.Set("Checkpoint", id)
	if changed then
		HealthService.ReturnAllEliminated() -- reaching a checkpoint brings eliminated teammates back
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function SessionService.Get(): Session?
	return session
end

function SessionService.IsActive(mode: string, contentId: string?): boolean
	return session ~= nil and session.mode == mode and (contentId == nil or session.contentId == contentId)
end

function SessionService.PlayersInGame(): { Player }
	local list = {}
	for player in inGame do
		table.insert(list, player)
	end
	return list
end

local function cleanWorld()
	CreatureService.Despawn()
	CreatureService.SetAIEnabled(true)
	CreatureService.SetDifficulty({})
	HealthService.TeamWipeHandler = nil
	PowerService.Reset()
	DoorService.CloseAll()
	HealthService.HealAll()
	InventoryService.ClearWorld()
end

local function start(mode: string, contentId: string): boolean
	local entry = Content.Entry(mode, contentId)
	local module = MODULES[mode] and MODULES[mode][contentId]
	if not entry or not module or entry.status ~= "available" then
		return false
	end
	if not MapService.Load(entry.map) then
		return false
	end
	cleanWorld()
	HealthService.ResetSessionStats()
	table.clear(CreatureService.Spotted)
	InventoryService.RefillCabinets()
	session = { mode = mode, contentId = contentId, mapId = entry.map, module = module, idleSince = nil }
	table.clear(entered)
	SessionService.SetCheckpoint(module.StartCheckpoint or "C1_START")
	SessionState.Set("Mode", mode)
	SessionState.Set("ContentId", contentId)
	module.Begin(entry)
	InventoryService.SpawnWorldItems(Config.Inventory.WorldItems)
	return true
end

local function leave(player: Player, respawn: boolean)
	if not inGame[player] then
		return
	end
	inGame[player] = nil
	InventoryService.Clear(player)
	DataService.Mutate(player, function(data)
		data.lastSession = {} -- left on purpose: no rejoin offer
	end)
	player:SetAttribute("FZ_InGame", false)
	player:SetAttribute("FZ_Downed", false)
	player:SetAttribute("FZ_Eliminated", false)
	player:SetAttribute("FZ_DownedUntil", nil)
	if respawn and player.Parent and not player:GetAttribute("FZ_MonsterMode") then
		player:LoadCharacter() -- back to the menu spawn, out of the station
	end
end

-- Ends the session for everyone (mode finished, or idle). Players return to the menu.
function SessionService.Finish()
	local current = session
	if not current then
		return
	end
	session = nil
	pcall(current.module.Stop)
	for player in table.clone(inGame) do
		leave(player, true)
	end
	cleanWorld()
	SessionState.Set("Mode", nil)
	SessionState.Set("ContentId", nil)
	SessionState.Set("Objective", nil)
	SessionState.Set("ObjectiveParams", nil)
end

local function join(player: Player)
	local current = session
	if not current then
		return false
	end
	inGame[player] = true
	current.idleSince = nil
	player:SetAttribute("FZ_InGame", true)
	player:SetAttribute("FZ_AutoJoin", nil)
	placeAtCheckpoint(player)
	local firstTime = not entered[player]
	entered[player] = true
	if firstTime then
		InventoryService.Reset(player)
		AnalyticsTracker.NewRun(player)
	end
	if player:GetAttribute("FZ_NewPlayer") then
		AnalyticsTracker.Onboarding(player, 3, "EnteredGame")
	end
	player:SetAttribute("FZ_RejoinAvailable", nil)
	DataService.Mutate(player, function(data)
		data.lastSession = { placeId = game.PlaceId, jobId = game.JobId, code = reservedCode or "", time = os.time() }
	end)
	if current.module.OnPlayerEntered then
		task.spawn(current.module.OnPlayerEntered, player, firstTime)
	end
	return true
end

local function completedChapters(player: Player): { [string]: any }
	local profile = DataService.Get(player)
	return if profile then profile.Data.progress.completedChapters else {}
end

local function request(player: Player, action: string, mode: any, contentId: any)
	if action == "leave" then
		leave(player, true)
		return { status = "ok" }
	elseif action == "private" then
		if inGame[player] then
			return { status = "error" }
		end
		return { status = PartyService.CreatePrivate(player) }
	elseif action == "rejoin" then
		local profile = DataService.Get(player)
		local last = profile and profile.Data.lastSession
		if not last or type(last.jobId) ~= "string" or last.jobId == game.JobId or os.time() - (last.time or 0) > REJOIN_WINDOW then
			return { status = "none" }
		end
		DataService.Mutate(player, function(data)
			data.lastSession = {}
		end)
		task.spawn(PlaceService.Rejoin, player, last.placeId, last.jobId, last.code)
		return { status = "teleport" }
	elseif action == "join" then
		return { status = if join(player) then "ok" else "none" }
	elseif action ~= "start" then
		return { status = "error" }
	end
	if type(mode) ~= "string" or type(contentId) ~= "string" then
		return { status = "error" }
	end
	local entry = Content.Entry(mode, contentId)
	if not entry or not Content.IsUnlocked(entry, completedChapters(player)) then
		return { status = "locked" }
	end
	if session and session.mode == mode and session.contentId == contentId then
		join(player)
		return { status = "ok" }
	end
	if session and #SessionService.PlayersInGame() > 0 then
		if PlaceService.CanTeleport(entry.map) then
			task.spawn(PlaceService.Teleport, { player }, entry.map, { mode = mode, contentId = contentId })
			return { status = "teleport" }
		end
		return { status = "busy", mode = session.mode, contentId = session.contentId }
	end
	if session then
		SessionService.Finish()
	end
	if not start(mode, contentId) then
		return { status = "error" }
	end
	join(player)
	return { status = "ok" }
end

function SessionService.ResetActive()
	local current = session
	if current then
		local mode, contentId = current.mode, current.contentId
		local players = SessionService.PlayersInGame()
		SessionService.Finish()
		start(mode, contentId)
		for _, player in players do
			join(player)
		end
	end
end

function SessionService.Start()
	local context = {
		setCheckpoint = SessionService.SetCheckpoint,
		finish = SessionService.Finish,
		playersInGame = SessionService.PlayersInGame,
		leave = function(player: Player)
			leave(player, true)
		end,
	}
	for _, modules in MODULES do
		for _, module in modules do
			module.Init(context)
		end
	end

	local limiter = RateLimiter.new(4, 0.5)
	Net.Function("Session").OnServerInvoke = function(player: Player, action: any, mode: any, contentId: any)
		if not limiter:Allow(player) or type(action) ~= "string" then
			return { status = "error" }
		end
		return request(player, action, mode, contentId)
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if inGame[player] then
				task.defer(placeAtCheckpoint, player)
			end
		end)
		-- Arrived by teleport with a selection? Start or join it automatically.
		reservedCode = reservedCode or PlaceService.ArrivalCode(player)
		local mode, contentId = PlaceService.ArrivalSelection(player)
		if mode and contentId then
			if not session then
				start(mode :: string, contentId :: string)
			end
			if session and session.mode == mode and session.contentId == contentId then
				player:SetAttribute("FZ_AutoJoin", true)
			end
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		inGame[player] = nil
		entered[player] = nil
	end)

	-- Disconnected recently from a running session in another server? Offer the way back.
	DataService.ProfileLoaded:Connect(function(player, profile)
		local last = profile.Data.lastSession
		if type(last) == "table" and type(last.jobId) == "string" and last.jobId ~= game.JobId and os.time() - (last.time or 0) <= REJOIN_WINDOW then
			player:SetAttribute("FZ_RejoinAvailable", true)
		end
	end)

	-- End idle sessions so the next team can pick something else.
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(2)
			ticks += 1
			if ticks % 30 == 0 then
				-- keep the rejoin window fresh for long sessions (once a minute)
				for player in inGame do
					DataService.Mutate(player, function(data)
						if type(data.lastSession) == "table" and data.lastSession.jobId == game.JobId then
							data.lastSession.time = os.time()
						end
					end)
				end
			end
			local current = session
			if current then
				if next(inGame) == nil then
					current.idleSince = current.idleSince or os.clock()
					if os.clock() - current.idleSince > Config.Survival.SessionIdleEnd then
						SessionService.Finish()
					end
				else
					current.idleSince = nil
				end
			end
		end
	end)
end

return SessionService
