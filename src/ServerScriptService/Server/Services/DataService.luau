-- DataService: persistent player data with session locking.
--
-- * One profile per player, loaded with UpdateAsync and locked to this server (JobId),
--   so two servers can never write the same save at the same time (protects codes,
--   currency and progress against duplication when a player hops servers quickly).
-- * Autosave refreshes the lock; leaving releases it.
-- * If DataStores are unavailable (Studio without API access, outage) the player gets a
--   session-only profile and is told that progress will not be saved. Anything that must
--   persist (code rewards, purchases) refuses to run on such a profile.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)
local Net = require(Shared.Net)

local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- (player, profile)

export type Profile = {
	Player: Player,
	Key: string,
	Data: { [string]: any },
	Persistent: boolean,
	Dirty: boolean,
	Saving: boolean,
	Released: boolean,
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[FZ-Data] DataStore unavailable, running session-only: " .. tostring(result))
	end
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function defaultData(): { [string]: any }
	return {
		version = Config.Data.SchemaVersion,
		settings = Config.DefaultSettings(),
		signalMarks = 0,
		redeemedCodes = {}, -- [codeId] = unix time
		progress = {
			chapter = 1,
			checkpoint = "C1_START",
			completed = {}, -- array of chapter numbers
		},
		stats = { sessions = 0, firstJoin = os.time(), lastJoin = 0 },
		inventory = {}, -- [itemId] = true
		equipped = {}, -- { set = itemId?, radioSkin = itemId? }
	}
end

local function reconcile(data: { [string]: any }, template: { [string]: any })
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
end

local function sanitizeSettings(settings: { [string]: any })
	for key, definition in Config.Settings do
		local value = settings[key]
		if value ~= nil then
			local ok = Config.ValidateSetting(key, value)
			if not ok then
				settings[key] = definition.default
			end
		end
	end
	for key in settings do
		if Config.Settings[key] == nil then
			settings[key] = nil
		end
	end
end

-- Schema migrations. Add a branch for every SchemaVersion bump.
local function migrate(data: { [string]: any })
	local version = tonumber(data.version) or 0
	-- if version < 2 then ... end
	if version < Config.Data.SchemaVersion then
		data.version = Config.Data.SchemaVersion
	end
end

local function prepare(data: { [string]: any })
	migrate(data)
	reconcile(data, defaultData())
	if type(data.settings) ~= "table" then
		data.settings = Config.DefaultSettings()
	end
	sanitizeSettings(data.settings)
	if type(data.signalMarks) ~= "number" or data.signalMarks ~= data.signalMarks or data.signalMarks < 0 then
		data.signalMarks = 0
	end
	data.signalMarks = math.floor(data.signalMarks)
end

local function withRetries(label: string, attempts: number, callback: () -> any): (boolean, any)
	local delayTime = 1
	for attempt = 1, attempts do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		warn(string.format("[FZ-Data] %s failed (attempt %d/%d): %s", label, attempt, attempts, tostring(result)))
		if attempt < attempts then
			task.wait(delayTime)
			delayTime = math.min(delayTime * 2, 8)
		end
	end
	return false, nil
end

local function publishAttributes(profile: Profile)
	local player = profile.Player
	player:SetAttribute("FZ_SignalMarks", profile.Data.signalMarks)
	player:SetAttribute("FZ_DataPersistent", profile.Persistent)
end

local function loadProfile(player: Player): Profile?
	local key = "u_" .. player.UserId
	local profile: Profile = {
		Player = player,
		Key = key,
		Data = {},
		Persistent = false,
		Dirty = false,
		Saving = false,
		Released = false,
	}

	local loaded = nil
	if store then
		local maxLockAttempts = 6
		for lockAttempt = 1, maxLockAttempts do
			local lockedByOther = false
			local ok, result = withRetries("Load " .. key, 4, function()
				return (store :: DataStore):UpdateAsync(key, function(old)
					lockedByOther = false
					local data = if type(old) == "table" then old else defaultData()
					local lock = data.lock
					if
						type(lock) == "table"
						and lock.job ~= game.JobId
						and os.time() - (tonumber(lock.time) or 0) < Config.Data.LockTimeout
						and lockAttempt < maxLockAttempts
					then
						-- Another server still owns this save (usually: it is finishing the
						-- save after the player left). Abort this write and retry shortly.
						lockedByOther = true
						return nil
					end
					prepare(data)
					data.lock = { job = game.JobId, time = os.time() }
					data.stats.sessions += 1
					data.stats.lastJoin = os.time()
					return data
				end)
			end)
			if not ok then
				break
			end
			if not lockedByOther and type(result) == "table" then
				loaded = result
				break
			end
			if player.Parent == nil then
				return nil
			end
			task.wait(5)
		end
	end

	if loaded then
		profile.Data = loaded
		profile.Persistent = true
	else
		profile.Data = defaultData()
		profile.Persistent = false
		if store then
			warn("[FZ-Data] Using session-only profile for " .. key)
		end
	end
	return profile
end

local function saveProfile(profile: Profile, release: boolean): boolean
	if not profile.Persistent or not store then
		return true
	end
	while profile.Saving do
		task.wait()
	end
	if profile.Released then
		return true
	end
	profile.Saving = true
	local lostLock = false
	local wasDirty = profile.Dirty
	local ok = withRetries("Save " .. profile.Key, if release then 5 else 3, function()
		return (store :: DataStore):UpdateAsync(profile.Key, function(old)
			lostLock = false
			if type(old) == "table" and type(old.lock) == "table" and old.lock.job ~= game.JobId then
				lostLock = true
				return nil
			end
			local out = table.clone(profile.Data)
			out.lock = if release then nil else { job = game.JobId, time = os.time() }
			return out
		end)
	end)
	profile.Saving = false
	if lostLock then
		-- Another server took this save over. Never overwrite it from here.
		warn("[FZ-Data] Lost session lock for " .. profile.Key .. "; profile is now read-only")
		profile.Persistent = false
		publishAttributes(profile)
		return false
	end
	if ok then
		if wasDirty then
			profile.Dirty = false
		end
		if release then
			profile.Released = true
		end
	end
	return ok
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

function DataService.WaitFor(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 20)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Mutate data through this function so the profile is marked dirty.
function DataService.Mutate(player: Player, mutator: ({ [string]: any }) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutator(profile.Data)
	profile.Dirty = true
	publishAttributes(profile)
	return true
end

-- Adds earned Signal Marks (never negative) and tells the player.
function DataService.Grant(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end
	local ok = DataService.Mutate(player, function(data)
		data.signalMarks += math.floor(amount)
	end)
	if ok then
		Net.Event("Notify"):FireClient(player, "REWARD_MARKS", { amount = math.floor(amount) })
	end
	return ok
end

-- Immediate save for important changes (code rewards, chapter completion).
function DataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	return saveProfile(profile, false)
end

function DataService.Start()
	local fetchLimiter = RateLimiter.new(3, 0.2)

	local function onPlayerAdded(player: Player)
		local profile = loadProfile(player)
		if not profile then
			return
		end
		if player.Parent == nil then
			-- Left while loading: release the lock right away.
			saveProfile(profile, true)
			return
		end
		profiles[player] = profile
		publishAttributes(profile)
		player:SetAttribute("FZ_DataReady", true)
		DataService.ProfileLoaded:Fire(player, profile)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			saveProfile(profile, true)
			profiles[player] = nil
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for _, profile in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for _, profile in profiles do
				-- Always save: this also refreshes the session lock.
				task.spawn(saveProfile, profile, false)
			end
		end
	end)

	Net.Function("FetchProfile").OnServerInvoke = function(player: Player)
		if not fetchLimiter:Allow(player) then
			return nil
		end
		local profile = DataService.WaitFor(player, 20)
		if not profile then
			return nil
		end
		local data = profile.Data
		return {
			settings = deepCopy(data.settings),
			signalMarks = data.signalMarks,
			progress = { chapter = data.progress.chapter, completed = deepCopy(data.progress.completed) },
			inventory = deepCopy(data.inventory),
			equipped = deepCopy(data.equipped),
			persistent = profile.Persistent,
			isNew = data.stats.sessions <= 1,
		}
	end
end

return DataService
