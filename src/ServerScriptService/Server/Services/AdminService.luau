-- AdminService: server-side authorization and audit log for maintenance tools.
--
-- Security model:
--   1. IsAuthorized() checks UserId / ownership on the server (cached per session).
--   2. The gesture code is read from ServerStorage at runtime (attribute
--      "FZ_AdminGesture", set by the owner in Studio, NOT committed to git). It only
--      unlocks the hidden menu entry for authorized players.
--   3. Every admin remote call re-checks authorization; the client-visible attribute
--      FZ_Admin is only a UI hint and is never trusted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local AdminConfig = require(script.Parent.Parent.AdminConfig)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local AdminService = {}

local authorizedCache: { [Player]: boolean } = {}
local unlocked: { [Player]: boolean } = {}
local auditLog: { { time: number, userId: number, name: string, action: string, detail: string } } = {}
local MAX_LOG = 200

function AdminService.Log(player: Player, action: string, detail: string?)
	local entry = {
		time = os.time(),
		userId = player.UserId,
		name = player.Name,
		action = action,
		detail = detail or "",
	}
	table.insert(auditLog, entry)
	if #auditLog > MAX_LOG then
		table.remove(auditLog, 1)
	end
	print(string.format("[FZ-ADMIN] %s (%d) %s %s", entry.name, entry.userId, action, entry.detail))
end

function AdminService.IsAuthorized(player: Player): boolean
	local cached = authorizedCache[player]
	if cached ~= nil then
		return cached
	end
	local authorized = false
	local certain = true
	if RunService:IsStudio() and AdminConfig.AllowAllInStudio then
		authorized = true
	elseif table.find(AdminConfig.UserIds, player.UserId) then
		authorized = true
	elseif game.CreatorType == Enum.CreatorType.User then
		authorized = player.UserId == game.CreatorId
	elseif game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		if ok then
			authorized = rank >= AdminConfig.MinGroupRank
		else
			certain = false -- web call failed: do not cache a false negative
		end
	end
	if certain then
		authorizedCache[player] = authorized
	end
	return authorized
end

function AdminService.MatchesGesture(normalizedCode: string): boolean
	local gesture = ServerStorage:GetAttribute("FZ_AdminGesture")
	if type(gesture) ~= "string" or #gesture < 6 then
		return false
	end
	return string.upper(gesture) == normalizedCode
end

function AdminService.Unlock(player: Player)
	unlocked[player] = true
	player:SetAttribute("FZ_Admin", true)
	AdminService.Log(player, "unlock")
end

local function isAllowed(player: Player): boolean
	return unlocked[player] == true and AdminService.IsAuthorized(player)
end

local ACTIONS = {}

ACTIONS.grant_test_marks = function(player: Player)
	local ok = DataService.Mutate(player, function(data)
		data.signalMarks += 100
	end)
	return { ok = ok }
end

ACTIONS.get_log = function()
	local recent = {}
	for i = math.max(1, #auditLog - 19), #auditLog do
		table.insert(recent, auditLog[i])
	end
	return { ok = true, log = recent }
end

function AdminService.Start()
	if type(ServerStorage:GetAttribute("FZ_AdminGesture")) ~= "string" then
		warn("[FZ-ADMIN] No gesture configured. Set the string attribute 'FZ_AdminGesture' on ServerStorage (min. 6 characters) to enable the hidden maintenance entry.")
	end

	local limiter = RateLimiter.new(10, 1)
	Net.Function("AdminAction").OnServerInvoke = function(player: Player, action: any, _payload: any)
		if not limiter:Allow(player) then
			return { ok = false, reason = "rate_limited" }
		end
		if type(action) ~= "string" or not isAllowed(player) then
			AdminService.Log(player, "denied", tostring(action))
			return { ok = false, reason = "denied" }
		end
		local handler = ACTIONS[action]
		if not handler then
			return { ok = false, reason = "unknown" }
		end
		AdminService.Log(player, action)
		return handler(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		authorizedCache[player] = nil
		unlocked[player] = nil
	end)
end

return AdminService
