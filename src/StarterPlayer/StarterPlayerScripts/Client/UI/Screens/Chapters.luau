-- Chapter overview. Locked chapters are visible (they create anticipation) but cannot be
-- started; nothing is ever locked behind Robux.

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Chapters = {}

local AVAILABLE_IN_BUILD = 1 -- chapters that exist in this build

function Chapters.new(router)
	local app = router.App
	local root, column = Components.ScreenRoot("Chapters")
	local layout = Components.List(column, Theme.Sizes.Gap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	Components.Heading(column, "MENU_CHAPTERS", 1)
	Components.Spacer(column, 10, 2)

	local completed = app.Profile.progress and app.Profile.progress.completed or {}
	local focus = nil
	for number = 1, 4 do
		local unlocked = number <= AVAILABLE_IN_BUILD and (number == 1 or table.find(completed, number - 1) ~= nil)
		local button = Components.Button({
			Key = string.format("CHAPTER_%02d_TITLE", number),
			TagKey = if unlocked then "CHAPTER_LABEL" else "CHAPTER_LOCKED",
			TagParams = if unlocked then { number = number } else nil,
			Disabled = not unlocked,
			LayoutOrder = 10 + number,
			Parent = column,
			OnActivated = function()
				app.Play(number)
			end,
		})
		if unlocked and not focus then
			focus = button.Instance
		end
	end

	Components.Spacer(column, 10, 20)
	local back = Components.Button({ Key = "MENU_BACK", LayoutOrder = 21, Parent = column, OnActivated = function()
		router:Pop()
	end })

	return { Root = root, Focus = focus or back.Instance }
end

return Chapters
