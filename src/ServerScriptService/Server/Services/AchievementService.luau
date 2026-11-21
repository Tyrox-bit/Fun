-- AchievementService: one-time achievements with server-side rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local BadgeTracker = require(script.Parent.BadgeTracker)

local AchievementService = {}

local function definition(id: string)
	for _, item in Achievements do
		if item.id == id then
			return item
		end
	end
	return nil
end

function AchievementService.Has(player: Player, id: string): boolean
	local profile = DataService.Get(player)
	return profile ~= nil and profile.Data.achievements[id] ~= nil
end

function AchievementService.Award(player: Player, id: string)
	local item = definition(id)
	local profile = DataService.Get(player)
	if not item or not profile or profile.Data.achievements[id] then
		return
	end
	DataService.Mutate(player, function(data)
		data.achievements[id] = os.time()
	end)
	Net.Event("Notify"):FireClient(player, "ACH_UNLOCKED", { name = item.name })
	if item.marks and item.marks > 0 then
		task.delay(2.5, function()
			if player.Parent then
				DataService.Grant(player, item.marks)
			end
		end)
	end
	BadgeTracker.Award(player, id)
end

return AchievementService
