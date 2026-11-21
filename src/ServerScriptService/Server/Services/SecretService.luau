-- SecretService: community secrets. Answers are checked on the server only, each secret
-- can be solved once per player, and a global counter shows how many players solved it
-- ("You are number 37") - the community can puzzle together without any external site.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Registry = require(Shared.SecretsRegistry)

local DataService = require(script.Parent.DataService)
local LoreService = require(script.Parent.LoreService)
local AchievementService = require(script.Parent.AchievementService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local Answers = require(ServerStorage:WaitForChild("Secrets"):WaitForChild("SecretAnswers"))

local SecretService = {}

local counter = nil
pcall(function()
	counter = DataStoreService:GetDataStore("FZ_SecretSolvers_v1")
end)

local function normalize(text: string): string
	return (string.gsub(string.upper(text), "[^%w]", ""))
end

local function solve(player: Player, raw: any)
	if type(raw) ~= "string" or #raw > 64 then
		return { status = "nothing" }
	end
	local input = normalize(raw)
	for _, secret in Registry do
		for _, answer in Answers[secret.id] or {} do
			if input == normalize(answer) then
				local profile = DataService.Get(player)
				if not profile or not profile.Persistent then
					return { status = "nothing" }
				end
				if profile.Data.secrets.solved[secret.id] then
					return { status = "known", unlock = secret.unlock }
				end
				DataService.Mutate(player, function(data)
					data.secrets.solved[secret.id] = os.time()
				end)
				LoreService.Unlock(player, secret.unlock, true)
				DataService.Grant(player, secret.marks or 0)
				AchievementService.Award(player, "decoder")
				local solvers = 0
				if counter then
					pcall(function()
						solvers = counter:IncrementAsync(secret.id, 1)
					end)
				end
				return { status = "ok", unlock = secret.unlock, solvers = solvers }
			end
		end
	end
	return { status = "nothing" }
end

function SecretService.Start()
	local limiter = RateLimiter.new(5, 0.1) -- burst 5, then one try every 10 s (no brute force)
	Net.Function("SolveSecret").OnServerInvoke = function(player: Player, raw: any)
		if not limiter:Allow(player) then
			return { status = "rate" }
		end
		return solve(player, raw)
	end
end

return SecretService
