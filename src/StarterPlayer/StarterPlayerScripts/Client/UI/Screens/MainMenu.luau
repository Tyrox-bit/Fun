-- Main menu (mode "main") and in-game menu (mode "pause").
-- No shop button yet: the shop arrives after the vertical slice (see roadmap).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local MainMenu = {}

function MainMenu.new(router, args)
	local app = router.App
	local pause = args and args.mode == "pause"
	local root, column = Components.ScreenRoot(if pause then "PauseMenu" else "MainMenu")
	local layout = Components.List(column, Theme.Sizes.Gap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	if pause then
		Components.Heading(column, "PAUSE_TITLE", 1)
		Components.Text({ Key = "PAUSE_NOTE", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 2, Parent = column })
	else
		Components.Text({ Text = "FREQUENCY ZERO", Font = Theme.Fonts.Title, TextSize = Theme.Sizes.TextTitle, Color = Theme.Colors.TextBright, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1, Parent = column })
		Components.Text({ Key = "MENU_TAGLINE", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, LayoutOrder = 2, Parent = column })
	end
	Components.Spacer(column, 18, 3)

	local Lobby = require(script.Parent.Lobby)
	local Chapters = require(script.Parent.Chapters)
	local Settings = require(script.Parent.Settings)
	local Extras = require(script.Parent.Extras)

	local primaryKey = if pause then "MENU_RESUME" elseif app.HasProgress() then "MENU_CONTINUE" else "MENU_PLAY"
	local primary = Components.Button({ Key = primaryKey, LayoutOrder = 10, Parent = column, OnActivated = function()
		app.Play()
	end })
	Components.Button({ Key = "MENU_LOBBY", LayoutOrder = 11, Parent = column, OnActivated = function()
		router:Push(Lobby)
	end })
	if not pause then
		Components.Button({ Key = "MENU_CHAPTERS", LayoutOrder = 12, Parent = column, OnActivated = function()
			router:Push(Chapters)
		end })
	end
	Components.Button({ Key = "MENU_SETTINGS", LayoutOrder = 13, Parent = column, OnActivated = function()
		router:Push(Settings)
	end })
	Components.Button({ Key = "MENU_EXTRAS", LayoutOrder = 14, Parent = column, OnActivated = function()
		router:Push(Extras)
	end })

	Components.Text({
		Text = "v" .. Config.Version,
		Font = Theme.Fonts.Mono,
		TextSize = 13,
		Color = Theme.Colors.TextFaint,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, Theme.Sizes.Margin + 16, 1, -12),
		Size = UDim2.fromOffset(200, 18),
		Parent = root,
	})

	return {
		Root = root,
		Focus = primary.Instance,
		OnBack = function()
			if pause then
				app.Play()
			end
			return true
		end,
	}
end

return MainMenu
