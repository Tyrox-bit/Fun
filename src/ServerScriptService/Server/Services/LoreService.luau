-- LoreService: hidden finds (Shared/Lore.luau). Reading one opens the document, saves it
-- to the player's archive (Extras -> Archive) and pays a small reward the first time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Lore = require(Shared.Lore)

local InteractionService = require(script.Parent.InteractionService)
local StoryService = require(script.Parent.StoryService)
local DataService = require(script.Parent.DataService)
local BadgeTracker = require(script.Parent.BadgeTracker)

local LoreService = {}

local REWARD = 50

local function entry(id: string)
	for _, item in Lore do
		if item.id == id then
			return item
		end
	end
	return nil
end

function LoreService.Start()
	InteractionService.Register("lore", function(player, object)
		local id = object:GetAttribute("LogId")
		local item = type(id) == "string" and entry(id)
		if not item then
			return
		end
		StoryService.ShowDocument(player, { title = item.title, body = item.body })
		local profile = DataService.Get(player)
		if not profile or profile.Data.secrets.logs[id] then
			return
		end
		DataService.Mutate(player, function(data)
			data.secrets.logs[id] = os.time()
		end)
		DataService.Grant(player, REWARD)
		local complete = true
		for _, other in Lore do
			if other.map == item.map and not profile.Data.secrets.logs[other.id] then
				complete = false
			end
		end
		if complete and item.map == "relay07" then
			BadgeTracker.Award(player, "ch1_archive")
		end
	end)
end

return LoreService
