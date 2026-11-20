-- "What's new": optional, opened by the player from the main menu. Never a pop-up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Updates = require(Shared.Updates)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local UpdatesScreen = {}

function UpdatesScreen.new(router)
	local app = router.App
	local root, column = Components.ScreenRoot("Updates")
	local scroll = Components.ScrollColumn(column, UDim2.fromScale(1, 1))
	Components.Heading(scroll, "UPDATES_TITLE", 1)
	local order = 1
	for _, update in Updates do
		order += 1
		Components.Spacer(scroll, 10, order)
		order += 1
		Components.Text({ Key = update.title, Font = Theme.Fonts.Bold, TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.TextBright, LayoutOrder = order, Parent = scroll })
		order += 1
		Components.Text({ Text = "v" .. update.id, Font = Theme.Fonts.Mono, TextSize = 13, Color = Theme.Colors.TextFaint, LayoutOrder = order, Parent = scroll })
		for _, line in update.lines do
			order += 1
			Components.Text({ Key = line, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Text, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = order, Parent = scroll })
		end
	end
	order += 1
	local back = Components.Button({ Key = "MENU_BACK", LayoutOrder = order + 1, Parent = scroll, OnActivated = function()
		router:Pop()
	end })

	-- Opening the overview marks the newest update as seen (removes the small dot).
	local newest = Updates[1]
	if newest and app.Profile.lastSeenUpdate ~= newest.id then
		app.Profile.lastSeenUpdate = newest.id
		Net.Event("MarkSeen"):FireServer("update:" .. newest.id)
	end

	return { Root = root, Focus = back.Instance }
end

return UpdatesScreen
