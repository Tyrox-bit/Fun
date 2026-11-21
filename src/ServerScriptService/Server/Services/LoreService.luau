-- LoreService: DAS ARCHIV on the server. Finds are saved per player (data.secrets.logs),
-- first finds pay a small reward, and insights unlock when their linked entries are known.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Lore = require(Shared.Lore)
local Net = require(Shared.Net)

local InteractionService = require(script.Parent.InteractionService)
local StoryService = require(script.Parent.StoryService)
local DataService = require(script.Parent.DataService)
local BadgeTracker = require(script.Parent.BadgeTracker)
local AchievementService = require(script.Parent.AchievementService)

local LoreService = {}

local REWARD = 50

function LoreService.Entry(id: string)
	for _, item in Lore do
		if item.id == id then
			return item
		end
	end
	return nil
end

local function checkInsights(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local logs = profile.Data.secrets.logs
	for _, item in Lore do
		if item.links and not logs[item.id] then
			local complete = true
			for _, link in item.links do
				if not logs[link] then
					complete = false
				end
			end
			if complete then
				DataService.Mutate(player, function(data)
					data.secrets.logs[item.id] = os.time()
				end)
				DataService.Grant(player, item.reward or REWARD)
				Net.Event("Notify"):FireClient(player, "ARCHIVE_INSIGHT")
			end
		end
	end
	-- every regular find of Relay Station 07 -> badge
	local all = true
	for _, item in Lore do
		if item.map == "relay07" and not item.links and not item.secret and not logs[item.id] then
			all = false
		end
	end
	if all then
		BadgeTracker.Award(player, "ch1_archive")
		AchievementService.Award(player, "archivist")
	end
end

-- Saves an entry for a player (no document is shown). Returns true on a first find.
function LoreService.Unlock(player: Player, id: string, silent: boolean?): boolean
	local item = LoreService.Entry(id)
	local profile = DataService.Get(player)
	if not item or not profile or profile.Data.secrets.logs[id] then
		return false
	end
	DataService.Mutate(player, function(data)
		data.secrets.logs[id] = os.time()
	end)
	if not silent then
		DataService.Grant(player, REWARD)
		Net.Event("Notify"):FireClient(player, "ARCHIVE_NEW")
	end
	checkInsights(player)
	return true
end

function LoreService.UnlockAll(players: { Player }, id: string)
	for _, player in players do
		LoreService.Unlock(player, id, true)
	end
end

function LoreService.Start()
	InteractionService.Register("lore", function(player, object)
		local id = object:GetAttribute("LogId")
		local item = type(id) == "string" and LoreService.Entry(id)
		if not item then
			return
		end
		StoryService.ShowDocument(player, { title = item.title, body = item.body })
		LoreService.Unlock(player, id)
	end)
end

return LoreService
