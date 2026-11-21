-- CommunityService: one-time reward for joining the official Roblox community (group).
--   * Membership is checked on the server (Player:IsInGroupAsync, fallback IsInGroup)
--   * The claim is stored in the save -> it can never be claimed twice
--   * Join requests that still wait for approval simply are not members yet: the player
--     can check again later (rate limited); failed web calls never consume the claim
--   * Playing never requires the community

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Community = require(Shared.Community)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local BadgeTracker = require(script.Parent.BadgeTracker)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local CommunityService = {}

local function isMember(player: Player): boolean?
	local groupId = Community.GroupId
	local ok, result = pcall(function()
		return (player :: any):IsInGroupAsync(groupId)
	end)
	if ok and type(result) == "boolean" then
		return result
	end
	ok, result = pcall(player.IsInGroup, player, groupId) -- older API (cached per server)
	if ok and type(result) == "boolean" then
		return result
	end
	return nil -- unknown: web request failed
end

function CommunityService.Start()
	local limiter = RateLimiter.new(2, 0.1)
	Net.Function("Community").OnServerInvoke = function(player: Player, action: any)
		if Community.GroupId <= 0 then
			return { status = "off" }
		end
		local profile = DataService.Get(player)
		if not profile then
			return { status = "error" }
		end
		local claimed = profile.Data.community.claimed ~= nil
		if action == "status" then
			return { status = if claimed then "claimed" else "open", groupId = Community.GroupId, marks = Community.RewardMarks }
		elseif action ~= "claim" then
			return { status = "error" }
		end
		if claimed then
			return { status = "claimed" }
		end
		if not limiter:Allow(player) then
			return { status = "rate" }
		end
		if not profile.Persistent then
			return { status = "error" }
		end
		local member = isMember(player)
		if member == nil then
			return { status = "error" }
		elseif not member then
			return { status = "not_member" }
		end
		DataService.Mutate(player, function(data)
			data.community.claimed = os.time()
		end)
		DataService.Grant(player, Community.RewardMarks)
		DataService.SaveNow(player)
		BadgeTracker.Award(player, "community")
		return { status = "ok", marks = Community.RewardMarks }
	end
end

return CommunityService
