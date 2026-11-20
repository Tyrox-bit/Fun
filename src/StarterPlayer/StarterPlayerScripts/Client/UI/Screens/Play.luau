-- Play: choose a story chapter or a survival map. Everything comes from Shared/Content,
-- so new chapters and maps appear here automatically after an update.
-- Card tags: In development / Locked / NEW / Completed / Best shift.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared.Content)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)
local SessionState = require(Shared.SessionState)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Play = {}

local function chapterNumber(id: string?): number?
	local chapter = id and Content.Chapter(id)
	return chapter and chapter.number
end

function Play.new(router)
	local app = router.App
	local profile = app.Profile
	local completed = (profile.progress and profile.progress.completedChapters) or {}
	local seen = profile.seenContent or {}
	local survivalStats = profile.survival or {}

	local root, column = Components.ScreenRoot("Play")
	column.Size = UDim2.new(0, Theme.Sizes.ContentWidth + 80, 1, -48)
	local scroll = Components.ScrollColumn(column, UDim2.fromScale(1, 1))
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local focus = nil

	Components.Heading(scroll, "PLAY_TITLE", nextOrder())

	-- A session is already running in this server: offer to join it first.
	local runningMode, runningId = SessionState.Get("Mode"), SessionState.Get("ContentId")
	if type(runningMode) == "string" and type(runningId) == "string" then
		local entry = Content.Entry(runningMode, runningId)
		if entry then
			local join = Components.Button({ Key = "SESSION_JOIN_RUNNING", Params = { name = Localization.T(entry.title) }, LayoutOrder = nextOrder(), Parent = scroll, OnActivated = function()
				app.Join()
			end })
			join.Label.TextColor3 = Theme.Colors.Relay
			focus = join.Instance
		end
	end

	local function tagFor(mode: string, entry): (string, { [string]: any }?)
		if entry.status ~= "available" then
			return "CONTENT_PLANNED", nil
		end
		if not Content.IsUnlocked(entry, completed) then
			return "CONTENT_LOCKED", { number = chapterNumber(entry.requires) or "?" }
		end
		if entry.since and not seen[entry.id] then
			return "CONTENT_NEW", nil
		end
		if mode == "story" then
			if completed[entry.id] then
				return "CONTENT_DONE", nil
			end
			return "CHAPTER_LABEL", { number = entry.number }
		end
		local stats = survivalStats[entry.id]
		if stats and stats.best and stats.best > 0 then
			return "SV_BEST", { shifts = stats.best }
		end
		return "MODE_SURVIVAL", nil
	end

	for _, modeId in Content.ModeOrder do
		local mode = Content.Modes[modeId]
		Components.Spacer(scroll, 8, nextOrder())
		Components.Text({ Key = mode.name, Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Accent, LayoutOrder = nextOrder(), Parent = scroll })
		Components.Text({ Key = mode.description, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = nextOrder(), Parent = scroll })
		local entries = if modeId == "story" then Content.Chapters else Content.SurvivalMaps
		for _, entry in entries do
			local tagKey, tagParams = tagFor(modeId, entry)
			local playable = Content.IsUnlocked(entry, completed)
			local card = Components.Button({
				Key = entry.title,
				TagKey = tagKey,
				TagParams = tagParams,
				Disabled = not playable,
				LayoutOrder = nextOrder(),
				Parent = scroll,
				OnActivated = function()
					if not seen[entry.id] then
						seen[entry.id] = true
						Net.Event("MarkSeen"):FireServer(entry.id)
					end
					app.Start(modeId, entry.id)
				end,
			})
			if tagKey == "CONTENT_NEW" then
				card.Tag.TextColor3 = Theme.Colors.Accent
			end
			if playable and not focus then
				focus = card.Instance
			end
			if modeId == "survival" and playable then
				Components.Button({ Key = "SV_LEADERBOARD", Height = 34, LayoutOrder = nextOrder(), Parent = scroll, OnActivated = function()
					router:Push(require(script.Parent.Leaderboard), { entry = entry })
				end }).Label.TextSize = Theme.Sizes.TextSmall
			end
		end
	end

	Components.Spacer(scroll, 10, nextOrder())
	local back = Components.Button({ Key = "MENU_BACK", LayoutOrder = nextOrder(), Parent = scroll, OnActivated = function()
		router:Pop()
	end })

	return { Root = root, Focus = focus or back.Instance }
end

return Play
