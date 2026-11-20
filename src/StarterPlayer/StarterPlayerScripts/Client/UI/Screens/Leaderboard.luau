-- Global best shifts for one survival map (top 10) + your own best.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Leaderboard = {}

function Leaderboard.new(router, args)
	local app = router.App
	local entry = args.entry
	local root, column = Components.ScreenRoot("Leaderboard")
	local layout = Components.List(column, Theme.Sizes.Gap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	Components.Heading(column, "LEADERBOARD_TITLE", 1)
	Components.Text({ Key = entry.title, Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, LayoutOrder = 2, Parent = column })
	local stats = app.Profile.survival and app.Profile.survival[entry.id]
	Components.Text({ Key = "SV_BEST", Params = { shifts = stats and stats.best or 0 }, Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Radio, LayoutOrder = 3, Parent = column })

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.LayoutOrder = 4
	list.Parent = column
	Components.List(list, 2)
	local status = Components.Text({ Key = "LEADERBOARD_LOADING", TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, Parent = list })

	local back = Components.Button({ Key = "MENU_BACK", LayoutOrder = 10, Parent = column, OnActivated = function()
		router:Pop()
	end })

	task.spawn(function()
		local ok, result = pcall(function()
			return Net.Function("GetLeaderboard"):InvokeServer(entry.id)
		end)
		if not list.Parent then
			return
		end
		if not ok or type(result) ~= "table" or not result.ok then
			Localization.Bind(status, "LEADERBOARD_ERROR")
			return
		end
		if #result.entries == 0 then
			Localization.Bind(status, "LEADERBOARD_EMPTY")
			return
		end
		status:Destroy()
		for index, row in result.entries do
			Components.Text({ Key = "LEADERBOARD_ROW", Params = { rank = row.rank, name = row.name, shifts = row.shifts }, Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextBody, Color = if index == 1 then Theme.Colors.Radio else Theme.Colors.Text, LayoutOrder = index, Parent = list })
		end
	end)

	return { Root = root, Focus = back.Instance }
end

return Leaderboard
