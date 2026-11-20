-- Chapter 1 "The Reception" - opening section (gatehouse).
-- Content only: all systems used here are generic and reusable.

local StoryService = require(script.Parent.Parent.Services.StoryService)
local InteractionService = require(script.Parent.Parent.Services.InteractionService)

local Chapter1 = {}

-- Arrival transmission. Sent per player when they first enter, so a friend who joins
-- later still gets their own "they just arrived" moment.
local ARRIVAL = {
	{ delay = 1.5, text = "SFX_STATIC", channel = "sfx", duration = 2 },
	{ delay = 1.0, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C1_001", channel = "radio", duration = 5.5 },
	{ delay = 5.8, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C1_002", channel = "radio", duration = 4 },
	{ delay = 5.0, text = "SFX_FAX", channel = "world", duration = 3, critical = false },
}

function Chapter1.Start()
	InteractionService.Register("c1_fax", function(player, _instance, _prompt)
		-- The fax was "sent" tomorrow at 02:14: first clue that the station receives the future.
		StoryService.ShowDocument(player, {
			title = "FAX_TITLE",
			body = "FAX_BODY",
			date = os.time() + 24 * 60 * 60,
		})
		if StoryService.GetFlag("C1_FaxRead") then
			return
		end
		StoryService.SetFlag("C1_FaxRead", true)
		StoryService.Sequence("all", {
			{ delay = 3, speaker = "SPEAKER_RELAY", text = "RADIO_C1_003", channel = "radio", duration = 3.5 },
		})
		task.delay(7, function()
			StoryService.SetObjective("OBJECTIVE_FIND_SENDER")
		end)
	end)
end

function Chapter1.OnPlayerEntered(player: Player, firstTime: boolean)
	if not firstTime then
		return
	end
	StoryService.Sequence(player, ARRIVAL)
	if StoryService.GetObjective() == nil then
		task.delay(14, function()
			if StoryService.GetObjective() == nil then
				StoryService.SetObjective("OBJECTIVE_CHECK_GATEHOUSE")
			end
		end)
	end
end

return Chapter1
