-- Community: optional one-time reward for joining the official Roblox community.
-- Nothing is required to play. The reward is only granted after the SERVER confirmed the
-- membership. Pending join requests: check again after they were accepted.

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Community = require(Shared.Community)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local CommunityScreen = {}

local STATUS = {
	ok = "COMMUNITY_OK",
	claimed = "COMMUNITY_CLAIMED",
	not_member = "COMMUNITY_NOT_MEMBER",
	rate = "CODE_RATE_LIMITED",
	error = "COMMUNITY_ERROR",
	off = "COMMUNITY_OFF",
}

function CommunityScreen.new(router)
	local root, column = Components.ScreenRoot("Community")
	local layout = Components.List(column, Theme.Sizes.Gap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	Components.Heading(column, "COMMUNITY_TITLE", 1)
	Components.Text({ Key = "COMMUNITY_DESC", Params = { marks = Community.RewardMarks }, TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.Text, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 2, Parent = column })
	Components.Text({ Key = "COMMUNITY_OPTIONAL", TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 3, Parent = column })
	local status = Components.Text({ Text = "", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 8, Parent = column })

	local function show(result)
		local key = STATUS[type(result) == "table" and result.status or "error"] or "COMMUNITY_ERROR"
		status.TextColor3 = if key == "COMMUNITY_OK" or key == "COMMUNITY_CLAIMED" then Theme.Colors.Relay else Theme.Colors.TextDim
		Localization.Bind(status, key, { marks = Community.RewardMarks })
	end

	local join = Components.Button({ Key = "COMMUNITY_JOIN", LayoutOrder = 5, Parent = column, OnActivated = function()
		task.spawn(function()
			local ok = pcall(function()
				(GroupService :: any):PromptJoinAsync(Community.GroupId)
			end)
			if not ok then
				Localization.Bind(status, "COMMUNITY_JOIN_MANUAL")
			end
		end)
	end })
	Components.Button({ Key = "COMMUNITY_CHECK", LayoutOrder = 6, Parent = column, OnActivated = function()
		local ok, result = pcall(function()
			return Net.Function("Community"):InvokeServer("claim")
		end)
		show(if ok then result else nil)
	end })
	Components.Spacer(column, 8, 9)
	Components.Button({ Key = "MENU_BACK", LayoutOrder = 10, Parent = column, OnActivated = function()
		router:Pop()
	end })

	task.spawn(function()
		local ok, result = pcall(function()
			return Net.Function("Community"):InvokeServer("status")
		end)
		if ok and type(result) == "table" and result.status == "claimed" then
			show(result)
		end
	end)
	return { Root = root, Focus = join.Instance }
end

return CommunityScreen
