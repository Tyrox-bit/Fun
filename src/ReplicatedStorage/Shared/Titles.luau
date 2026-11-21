-- Profile titles: earned by playing, never bought. Shown next to your name in the team
-- list. Requirements are evaluated on the server from the save data.

local Lore = require(script.Parent.Lore)

local Titles = {}

local function count(t: { [any]: any }?): number
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end

Titles.List = {
	{ id = "first_contact", name = "TITLE_FIRST_CONTACT", hint = "TITLE_FIRST_CONTACT_HINT", earned = function(data)
		return data.progress.completedChapters.ch1 ~= nil
	end },
	{ id = "breaker", name = "TITLE_BREAKER", hint = "TITLE_BREAKER_HINT", earned = function(data)
		return count(data.secrets.forecastsBroken) > 0
	end },
	{ id = "archivist", name = "TITLE_ARCHIVIST", hint = "TITLE_ARCHIVIST_HINT", earned = function(data)
		for _, entry in Lore do
			if entry.map == "relay07" and not data.secrets.logs[entry.id] then
				return false
			end
		end
		return true
	end },
	{ id = "night_shift", name = "TITLE_NIGHT_SHIFT", hint = "TITLE_NIGHT_SHIFT_HINT", earned = function(data)
		for _, stats in data.modes.survival do
			if (stats.best or 0) >= 5 then
				return true
			end
		end
		return false
	end },
	{ id = "listener", name = "TITLE_LISTENER", hint = "TITLE_LISTENER_HINT", earned = function(data)
		return data.storyChoices.c1_answer == 1
	end },
	{ id = "silent", name = "TITLE_SILENT", hint = "TITLE_SILENT_HINT", earned = function(data)
		return data.storyChoices.c1_answer == 2
	end },
}

function Titles.Get(id: string)
	for _, title in Titles.List do
		if title.id == id then
			return title
		end
	end
	return nil
end

return Titles
