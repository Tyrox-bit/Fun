-- Content registry: the single list of everything playable. New chapters, survival
-- maps, maps and places are added HERE - menus, saves, teleports and "new" badges all
-- read from this table, so an update never needs changes in a dozen places.
--
-- Rules for updates (see docs/UPDATES.md):
--   * ids are permanent. Never rename or reuse an id (saves reference them).
--   * status "planned" shows the entry as "in development" (not selectable).
--   * "since" = the update that introduced it (drives the subtle NEW badge).

local Content = {}

Content.Modes = {
	story = { id = "story", name = "MODE_STORY", description = "MODE_STORY_DESC" },
	survival = { id = "survival", name = "MODE_SURVIVAL", description = "MODE_SURVIVAL_DESC" },
}
Content.ModeOrder = { "story", "survival" }

-- Maps are built by a module in ServerScriptService/Server/Map (or loaded from your own
-- Studio model named after `model` in ServerStorage/Maps). One map can serve several modes.
Content.Maps = {
	relay07 = { id = "relay07", name = "MAP_RELAY07", builder = "RelayStation07", model = "Relay07" },
	dam03 = { id = "dam03", name = "MAP_DAM03", builder = "Dam03", model = "Dam03" },
	mine = { id = "mine", name = "MAP_MINE", builder = "Mine", model = "Mine" },
	church = { id = "church", name = "MAP_CHURCH", builder = "Chapel", model = "Church" },
}

Content.Chapters = {
	{ id = "ch1", number = 1, title = "CHAPTER_01_TITLE", description = "CHAPTER_01_DESC", map = "relay07", status = "available", since = "0.2.0" },
	{ id = "ch2", number = 2, title = "CHAPTER_02_TITLE", description = "CHAPTER_02_DESC", map = "dam03", status = "available", since = "0.4.0", requires = "ch1" },
	{ id = "ch3", number = 3, title = "CHAPTER_03_TITLE", description = "CHAPTER_03_DESC", map = "church", status = "available", since = "0.4.0", requires = "ch2" },
	{ id = "ch4", number = 4, title = "CHAPTER_04_TITLE", description = "CHAPTER_04_DESC", map = "mine", status = "available", since = "0.4.0", requires = "ch3" },
}

Content.SurvivalMaps = {
	{ id = "sv_relay07", title = "SV_MAP_RELAY07", description = "SV_MAP_RELAY07_DESC", map = "relay07", status = "available", since = "0.3.0", requires = nil },
	{ id = "sv_dam03", title = "SV_MAP_DAM03", description = "SV_MAP_DAM03_DESC", map = "dam03", status = "available", since = "0.4.0", requires = "ch2" },
	{ id = "sv_church", title = "SV_MAP_CHURCH", description = "SV_MAP_CHURCH_DESC", map = "church", status = "available", since = "0.5.0", requires = "ch3" },
	{ id = "sv_mine", title = "SV_MAP_MINE", description = "SV_MAP_MINE_DESC", map = "mine", status = "available", since = "0.5.0", requires = "ch4" },
}

-- Roblox places inside this experience (Creator Hub -> Places). 0 = not created yet:
-- everything then runs in the current place (single-place mode, fully playable).
Content.Places = {
	hub = 0, -- start place with the menu (optional; the main place works as hub)
	relay07 = 0, -- a dedicated place for the Relay Station 07 map
	dam03 = 0,
	church = 0,
	mine = 0,
}

function Content.Chapter(id: string)
	for _, chapter in Content.Chapters do
		if chapter.id == id then
			return chapter
		end
	end
	return nil
end

function Content.Survival(id: string)
	for _, entry in Content.SurvivalMaps do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function Content.Entry(mode: string, id: string)
	if mode == "story" then
		return Content.Chapter(id)
	elseif mode == "survival" then
		return Content.Survival(id)
	end
	return nil
end

-- Is this entry playable for a player with these completed chapter ids?
function Content.IsUnlocked(entry, completed: { [string]: any }): boolean
	if not entry or entry.status ~= "available" then
		return false
	end
	return entry.requires == nil or completed[entry.requires] ~= nil
end

-- All ids that can show a NEW badge.
function Content.AllIds(): { string }
	local ids = {}
	for _, chapter in Content.Chapters do
		table.insert(ids, chapter.id)
	end
	for _, entry in Content.SurvivalMaps do
		table.insert(ids, entry.id)
	end
	return ids
end

return Content
