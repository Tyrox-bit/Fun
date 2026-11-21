-- BadgeTracker: awards Roblox badges configured in Shared/Badges.luau (id 0 = skipped).

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Badges = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Badges"))

local BadgeTracker = {}

local awarded: { [string]: boolean } = {}

function BadgeTracker.Award(player: Player, key: string)
	local id = Badges[key]
	if type(id) ~= "number" or id <= 0 then
		return
	end
	local cacheKey = player.UserId .. ":" .. key
	if awarded[cacheKey] then
		return
	end
	awarded[cacheKey] = true
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if ok and not has then
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		end
	end)
end

return BadgeTracker
