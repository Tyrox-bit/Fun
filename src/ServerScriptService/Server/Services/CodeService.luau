-- CodeService: redeemable codes hidden inside the game world.
-- Codes are defined in ServerStorage.Secrets.Codes (never replicated to clients), checked
-- server-side, redeemable once per account (session lock in DataService prevents
-- cross-server duplication) and saved immediately.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local AdminService = require(script.Parent.AdminService)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local Codes = require(ServerStorage:WaitForChild("Secrets"):WaitForChild("Codes"))

local CodeService = {}

local function normalize(raw: string): string
	local trimmed = string.gsub(raw, "%s+", "")
	return string.upper(trimmed)
end

function CodeService.Redeem(player: Player, raw: any): { [string]: any }
	if type(raw) ~= "string" or #raw == 0 or #raw > Config.Codes.MaxLength * 2 then
		return { status = "invalid" }
	end
	local code = normalize(raw)
	if #code == 0 or #code > Config.Codes.MaxLength then
		return { status = "invalid" }
	end

	if AdminService.MatchesGesture(code) then
		if AdminService.IsAuthorized(player) then
			AdminService.Unlock(player)
			return { status = "admin" }
		end
		AdminService.Log(player, "gesture_denied")
		return { status = "invalid" } -- indistinguishable from a wrong code
	end

	local definition = Codes[code]
	if not definition or definition.active == false then
		return { status = "invalid" }
	end

	local profile = DataService.Get(player)
	if not profile or not profile.Persistent then
		-- Never hand out a reward that cannot be saved (and could then be redeemed again).
		return { status = "error" }
	end
	if profile.Data.redeemedCodes[definition.id] then
		return { status = "used" }
	end

	-- No yield between the check above and this write, so double invocations are safe.
	local amount = definition.reward.signalMarks or 0
	DataService.Mutate(player, function(data)
		data.redeemedCodes[definition.id] = os.time()
		data.signalMarks += amount
	end)
	DataService.SaveNow(player) -- if this fails, autosave retries; the profile stays locked
	return { status = "ok", amount = amount, balance = profile.Data.signalMarks }
end

function CodeService.Start()
	local limiter = RateLimiter.new(5, 1 / 6) -- burst 5, then one attempt every 6 s
	Net.Function("RedeemCode").OnServerInvoke = function(player: Player, raw: any)
		if not limiter:Allow(player) then
			return { status = "rate_limited" }
		end
		return CodeService.Redeem(player, raw)
	end
end

return CodeService
