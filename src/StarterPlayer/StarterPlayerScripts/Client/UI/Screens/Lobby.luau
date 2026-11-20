-- Team screen: who is in this session, one-tap invite, clear solo message.
-- One Roblox server = one team. Friends who accept the invite join this server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)
local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))

local Lobby = {}

function Lobby.new(router)
	local app = router.App
	local root, column = Components.ScreenRoot("Lobby")
	local layout = Components.List(column, Theme.Sizes.Gap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	Components.Heading(column, "LOBBY_TITLE", 1)
	local count = Components.Text({ Text = "", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, LayoutOrder = 2, Parent = column })

	local list = Instance.new("Frame")
	list.Name = "Players"
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.LayoutOrder = 3
	list.Parent = column
	Components.List(list, 2)

	local function refresh()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local players = Players:GetPlayers()
		Localization.Bind(count, "LOBBY_COUNT", { count = #players, max = Config.MaxPartySize })
		for index, player in players do
			local isSelf = player == Players.LocalPlayer
			local suffix = if isSelf then "  " .. Localization.T("LOBBY_YOU") else ""
			if isSelf then
				Components.Text({
					Text = string.format("%s  @%s%s", player.DisplayName, player.Name, suffix),
					Font = Theme.Fonts.Body,
					TextSize = Theme.Sizes.TextBody,
					Color = Theme.Colors.Text,
					Wrapped = false,
					LayoutOrder = index,
					Parent = list,
				})
			else
				-- Tap a teammate to mute / unmute their voice and radio for you only.
				local muted = app.Voice.IsMuted(player)
				local row = Components.Button({
					Text = string.format("%s  @%s", player.DisplayName, player.Name),
					TagKey = if muted then "LOBBY_UNMUTE" else "LOBBY_MUTE",
					Height = 40,
					LayoutOrder = index,
					Parent = list,
				})
				row.Instance.Activated:Connect(function()
					app.Voice.SetMuted(player, not app.Voice.IsMuted(player))
					refresh()
				end)
			end
		end
	end
	refresh()
	local connections = {
		Players.PlayerAdded:Connect(refresh),
		Players.PlayerRemoving:Connect(function()
			task.defer(refresh)
		end),
		Localization.Changed:Connect(refresh),
	}

	Components.Spacer(column, 10, 4)
	local invite = Components.Button({ Key = "LOBBY_INVITE", LayoutOrder = 5, Parent = column, OnActivated = function()
		task.spawn(function()
			local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, Players.LocalPlayer)
			if ok and canInvite then
				pcall(SocialService.PromptGameInvite, SocialService, Players.LocalPlayer)
			else
				app.Hud.Notify("LOBBY_INVITE_UNAVAILABLE")
			end
		end)
	end })
	Components.Text({ Key = "LOBBY_SOLO_HINT", TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 6, Parent = column })
	Components.Spacer(column, 10, 7)
	Components.Button({ Key = "MENU_BACK", LayoutOrder = 8, Parent = column, OnActivated = function()
		router:Pop()
	end })

	return {
		Root = root,
		Focus = invite.Instance,
		Destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end,
	}
end

return Lobby
