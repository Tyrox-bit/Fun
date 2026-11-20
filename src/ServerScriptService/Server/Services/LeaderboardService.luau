-- LeaderboardService: global best shifts per survival map (OrderedDataStore).
-- Names are resolved and cached on the server. Reads are cached for 60 s.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared.Content)
local Net = require(Shared.Net)

local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local LeaderboardService = {}

local stores: { [string]: OrderedDataStore } = {}
local cache: { [string]: { time: number, entries: { any } } } = {}
local names: { [number]: string } = {}

local function store(survivalId: string): OrderedDataStore?
	if stores[survivalId] then
		return stores[survivalId]
	end
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "FZ_Survival_" .. survivalId .. "_v1")
	if ok then
		stores[survivalId] = result
		return result
	end
	return nil
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then name else "?"
	return names[userId]
end

function LeaderboardService.Submit(survivalId: string, userId: number, shifts: number)
	local s = store(survivalId)
	if not s or shifts <= 0 then
		return
	end
	pcall(function()
		s:UpdateAsync(tostring(userId), function(old)
			if type(old) == "number" and old >= shifts then
				return nil -- keep the better score, no write
			end
			return math.floor(shifts)
		end)
	end)
	cache[survivalId] = nil
end

function LeaderboardService.Top(survivalId: string): { any }?
	local cached = cache[survivalId]
	if cached and os.clock() - cached.time < 60 then
		return cached.entries
	end
	local s = store(survivalId)
	if not s then
		return nil
	end
	local ok, pages = pcall(s.GetSortedAsync, s, false, 10)
	if not ok then
		return nil
	end
	local entries = {}
	for rank, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key) or 0
		table.insert(entries, { rank = rank, name = nameOf(userId), shifts = item.value })
	end
	cache[survivalId] = { time = os.clock(), entries = entries }
	return entries
end

function LeaderboardService.Start()
	local limiter = RateLimiter.new(3, 0.2)
	Net.Function("GetLeaderboard").OnServerInvoke = function(player: Player, survivalId: any)
		if not limiter:Allow(player) or type(survivalId) ~= "string" or not Content.Survival(survivalId) then
			return { ok = false }
		end
		local entries = LeaderboardService.Top(survivalId)
		return { ok = entries ~= nil, entries = entries or {} }
	end
end

return LeaderboardService
