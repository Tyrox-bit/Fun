-- Main menu (mode "main") and in-game menu (mode "pause").
-- No shop button yet: the shop arrives after the vertical slice (see roadmap).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))
local SessionState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SessionState"))

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
		Components.Text({ Text = "SILENT RELAY", Font = Theme.Fonts.Title, TextSize = Theme.Sizes.TextTitle, Color = Theme.Colors.TextBright, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1, Parent = column })
		Components.Text({ Key = "MENU_TAGLINE", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, LayoutOrder = 2, Parent = column })
	end
	Components.Spacer(column, 18, 3)

	local Lobby = require(script.Parent.Lobby)
	local Settings = require(script.Parent.Settings)
	local Extras = require(script.Parent.Extras)
	local Shop = require(script.Parent.Shop)
	local Play = require(script.Parent.Play)
	local UpdatesScreen = require(script.Parent.Updates)

	local primary
	if pause then
		primary = Components.Button({ Key = "MENU_RESUME", LayoutOrder = 10, Parent = column, OnActivated = function()
			app.Resume()
		end })
	else
		-- Lost connection a moment ago? Offer the way back to the team first.
		if game:GetService("Players").LocalPlayer:GetAttribute("FZ_RejoinAvailable") then
			local rejoin = Components.Button({ Key = "MENU_REJOIN", LayoutOrder = 8, Parent = column, OnActivated = function()
				app.Rejoin()
			end })
			rejoin.Label.TextColor3 = Theme.Colors.Relay
			primary = rejoin
		end
		-- "Continue" only when the team in this server is already playing something.
		if type(SessionState.Get("Mode")) == "string" then
			primary = Components.Button({ Key = "MENU_CONTINUE", LayoutOrder = 9, Parent = column, OnActivated = function()
				app.Join()
			end })
		end
		local play = Components.Button({ Key = "MENU_PLAY", TagKey = if app.HasNewContent() then "CONTENT_NEW" else nil, LayoutOrder = 10, Parent = column, OnActivated = function()
			router:Push(Play)
		end })
		play.Tag.TextColor3 = Theme.Colors.Accent
		primary = primary or play
	end
	Components.Button({ Key = "MENU_LOBBY", LayoutOrder = 11, Parent = column, OnActivated = function()
		router:Push(Lobby)
	end })
	Components.Button({ Key = "ARCHIVE_TITLE", LayoutOrder = 12, Parent = column, OnActivated = function()
		router:Push(require(script.Parent.Archive))
	end })
	Components.Button({ Key = "MENU_SHOP", LayoutOrder = 13, Parent = column, OnActivated = function()
		router:Push(Shop)
	end })
	Components.Button({ Key = "MENU_SETTINGS", LayoutOrder = 14, Parent = column, OnActivated = function()
		router:Push(Settings)
	end })
	Components.Button({ Key = "MENU_EXTRAS", LayoutOrder = 15, Parent = column, OnActivated = function()
		router:Push(Extras)
	end })
	if pause then
		local mic = Components.Button({ Key = if app.Radio.IsMuted() then "MIC_UNMUTE" else "MIC_MUTE", LayoutOrder = 16, Parent = column })
		mic.Instance.Activated:Connect(function()
			app.Radio.ToggleMute()
			Localization.Bind(mic.Label, if app.Radio.IsMuted() then "MIC_UNMUTE" else "MIC_MUTE")
		end)
		Components.Button({ Key = "MENU_LEAVE", LayoutOrder = 17, Parent = column, OnActivated = function()
			app.Leave()
		end })
	else
		-- Quiet "What's new" link with a small dot when there is an unseen update.
		local updates = Components.Button({ Key = "MENU_UPDATES", TagKey = if app.HasNewUpdate() then "CONTENT_DOT" else nil, Height = 36, LayoutOrder = 20, Parent = column, OnActivated = function()
			router:Push(UpdatesScreen)
		end })
		updates.Label.TextSize = Theme.Sizes.TextSmall
		updates.Label.TextColor3 = Theme.Colors.TextDim
		updates.Tag.TextColor3 = Theme.Colors.Accent
	end

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
				app.Resume()
			end
			return true
		end,
	}
end

return MainMenu
