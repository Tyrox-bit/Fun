-- Archive: everything you have found and decided, plus your titles.
-- Unfound entries show as "???" so players know there is more to discover.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared.Localization)
local Lore = require(Shared.Lore)
local Net = require(Shared.Net)
local Titles = require(Shared.Titles)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Archive = {}

function Archive.new(router)
	local app = router.App
	local root, column = Components.ScreenRoot("Archive")
	local scroll = Components.ScrollColumn(column, UDim2.fromScale(1, 1))
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	Components.Heading(scroll, "ARCHIVE_TITLE", nextOrder())
	local loading = Components.Text({ Key = "LEADERBOARD_LOADING", TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, LayoutOrder = nextOrder(), Parent = scroll })
	local back = Components.Button({ Key = "MENU_BACK", LayoutOrder = 999, Parent = scroll, OnActivated = function()
		router:Pop()
	end })

	task.spawn(function()
		local okProfile, profile = pcall(function()
			return Net.Function("FetchProfile"):InvokeServer()
		end)
		local okShop, shop = pcall(function()
			return Net.Function("ShopAction"):InvokeServer("get")
		end)
		if not scroll.Parent then
			return
		end
		loading:Destroy()
		profile = if okProfile and type(profile) == "table" then profile else app.Profile
		local secrets = profile.secrets or { logs = {}, forecastsBroken = {} }
		local choices = profile.storyChoices or {}

		-- Finds
		Components.Text({ Key = "ARCHIVE_FINDS", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Accent, LayoutOrder = nextOrder(), Parent = scroll })
		for _, item in Lore do
			if secrets.logs[item.id] then
				Components.Button({ Key = item.title, Height = 40, LayoutOrder = nextOrder(), Parent = scroll, OnActivated = function()
					app.Hud.ShowDocument({ title = item.title, body = item.body })
				end })
			else
				Components.Text({ Text = "  ???", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.TextFaint, LayoutOrder = nextOrder(), Parent = scroll })
			end
		end

		-- Decisions and forecasts
		Components.Spacer(scroll, 8, nextOrder())
		Components.Text({ Key = "ARCHIVE_DECISIONS", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Accent, LayoutOrder = nextOrder(), Parent = scroll })
		local answer = choices.c1_answer
		Components.Text({
			Key = if answer == 1 then "ARCHIVE_C1_ANSWERED" elseif answer == 2 then "ARCHIVE_C1_SILENT" else "ARCHIVE_C1_OPEN",
			TextSize = Theme.Sizes.TextBody,
			Color = Theme.Colors.Text,
			AutoY = true,
			Size = UDim2.fromScale(1, 0),
			LayoutOrder = nextOrder(),
			Parent = scroll,
		})
		local broken = 0
		for _ in secrets.forecastsBroken or {} do
			broken += 1
		end
		Components.Text({ Key = "ARCHIVE_FORECASTS", Params = { count = broken }, TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.Text, LayoutOrder = nextOrder(), Parent = scroll })

		-- Titles
		Components.Spacer(scroll, 8, nextOrder())
		Components.Text({ Key = "ARCHIVE_TITLES", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Accent, LayoutOrder = nextOrder(), Parent = scroll })
		local earned = {}
		if okShop and type(shop) == "table" then
			for _, id in shop.titles or {} do
				earned[id] = true
			end
		end
		local equipped = okShop and type(shop) == "table" and shop.equipped and shop.equipped.title
		for _, title in Titles.List do
			if earned[title.id] then
				local button
				button = Components.Button({
					Key = title.name,
					TagKey = if equipped == title.id then "SHOP_EQUIPPED" else "SHOP_EQUIP",
					Height = 40,
					LayoutOrder = nextOrder(),
					Parent = scroll,
					OnActivated = function()
						local wearing = equipped == title.id
						pcall(function()
							Net.Function("ShopAction"):InvokeServer("title", if wearing then "" else title.id)
						end)
						equipped = if wearing then nil else title.id
						Localization.Bind(button.Tag, if equipped == title.id then "SHOP_EQUIPPED" else "SHOP_EQUIP")
					end,
				})
			else
				Components.Text({ Key = title.hint, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextFaint, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = nextOrder(), Parent = scroll })
			end
		end
	end)

	return { Root = root, Focus = back.Instance }
end

return Archive
