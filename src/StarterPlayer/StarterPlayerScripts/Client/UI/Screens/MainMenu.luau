-- Main menu (mode "main") and in-game menu (mode "pause").
-- No shop button yet: the shop arrives after the vertical slice (see roadmap).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))
local SessionState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SessionState"))

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local MainMenu = {}

-- Title block: kicker line, two-tone logo, live waveform, tagline.
function MainMenu.Logo(column: Frame, app, root: GuiObject, compact: boolean?)
	local block = Instance.new("Frame")
	block.Name = "Logo"
	block.BackgroundTransparency = 1
	block.Size = UDim2.new(1, 0, 0, if compact then 62 else 196)
	block.LayoutOrder = 1
	block.Parent = column

	local live = Instance.new("Frame")
	live.Name = "LiveDot"
	live.BackgroundColor3 = Theme.Colors.Accent
	live.BorderSizePixel = 0
	live.Size = UDim2.fromOffset(8, 8)
	live.Position = UDim2.fromOffset(0, 7)
	live.Parent = block
	Components.Corner(live, 4)
	Components.Text({ Text = "LIVE  ·  RELAY 07  ·  147.300 MHz", Font = Theme.Fonts.Mono, TextSize = 13, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(16, 0), Parent = block })

	local big = if compact then 34 else 56
	local silent = Components.Text({ Text = "SILENT", Font = Theme.Fonts.Title, TextSize = big, Color = Theme.Colors.TextBright, Wrapped = false, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(-3, 24), Parent = block })
	silent.TextStrokeTransparency = 0.85
	local relayX = if compact then 232 else 0
	local relayY = if compact then 24 else 82
	local relayGlow = Components.Text({ Text = "RELAY", Font = Theme.Fonts.Title, TextSize = big, Color = Theme.Colors.AccentDeep, Wrapped = false, Size = UDim2.new(1, -relayX, 0, 60), Position = UDim2.fromOffset(relayX - 1, relayY + 2), Parent = block })
	relayGlow.TextTransparency = 0.35
	local relay = Components.Text({ Text = "RELAY", Font = Theme.Fonts.Title, TextSize = big, Color = Theme.Colors.Accent, Wrapped = false, Size = UDim2.new(1, -relayX, 0, 60), Position = UDim2.fromOffset(relayX - 3, relayY), Parent = block })
	relay.TextStrokeColor3 = Theme.Colors.Accent
	relay.TextStrokeTransparency = 0.7
	if compact then
		-- one line, sized by the font itself (no guessed offsets)
		silent.RichText = true
		silent.Text = string.format('SILENT <font color="%s">RELAY</font>', Theme.Hex(Theme.Colors.Accent))
		silent.Position = UDim2.fromOffset(-2, 18)
		silent.Size = UDim2.new(1, 0, 0, 40)
		relay.Visible = false
		relayGlow.Visible = false
	end

	-- live waveform: thin bars that breathe like a carrier signal with bursts of noise
	local wave = Instance.new("Frame")
	wave.Name = "Wave"
	wave.BackgroundTransparency = 1
	wave.Size = UDim2.new(1, 0, 0, 26)
	wave.Position = UDim2.fromOffset(0, if compact then 76 else 146)
	wave.Visible = not compact
	wave.ClipsDescendants = true
	wave.Parent = block
	local bars = {}
	local count = 64
	for i = 1, count do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.new((i - 1) / count, 0, 0.5, 0)
		bar.Size = UDim2.new(1 / count, -2, 0, 2)
		bar.BackgroundColor3 = if i % 9 == 0 then Theme.Colors.Accent else Theme.Colors.TextDim
		bar.BackgroundTransparency = 0.25
		bar.Parent = wave
		bars[i] = bar
	end
	Components.Text({ Key = "MENU_TAGLINE", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 176), Parent = block }).Visible = not compact

	local calm = app.Settings.Get("reduceFlicker") == true
	local t = 0
	local burst = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not root.Parent then
			connection:Disconnect()
			return
		end
		t += dt
		if burst <= 0 and math.random() < dt * 0.25 then
			burst = 0.5
		end
		burst = math.max(0, burst - dt)
		for i, bar in bars do
			local x = i / count
			local carrier = math.sin(x * 18 + t * 3.1) * 0.5 + math.sin(x * 41 - t * 5.3) * 0.25
			local noise = if burst > 0 then math.random() * 1.2 else 0
			local h = math.clamp(math.abs(carrier) * 14 + noise * 12 + 2, 2, 26)
			bar.Size = UDim2.new(1 / count, -2, 0, h)
		end
		live.BackgroundTransparency = 0.15 + (math.sin(t * 4) * 0.5 + 0.5) * 0.6
		if not calm then
			-- rare glitch: the red word jumps a pixel and drops out for a frame
			if burst > 0.42 then
				relay.Position = UDim2.fromOffset(relayX - 3 + math.random(-3, 3), relayY)
				relay.TextTransparency = math.random() * 0.5
			else
				relay.Position = UDim2.fromOffset(relayX - 3, relayY)
				relay.TextTransparency = 0
			end
		end
	end)
end

-- Bottom-right: avatar, name, signal marks.
function MainMenu.PlayerCard(root: GuiObject, app)
	local player = Players.LocalPlayer
	local card = Components.Panel({ Name = "PlayerCard", Size = UDim2.fromOffset(280, 64), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -20), Parent = root })
	local avatar = Instance.new("ImageLabel")
	avatar.BackgroundColor3 = Theme.Colors.PanelRaised
	avatar.BorderSizePixel = 0
	avatar.Size = UDim2.fromOffset(48, 48)
	avatar.Position = UDim2.fromOffset(8, 8)
	avatar.Parent = card
	Components.Corner(avatar, 24)
	Components.Stroke(avatar, Theme.Colors.Accent, 0.4)
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and avatar.Parent then
			avatar.Image = image
		end
	end)
	Components.Text({ Text = player.DisplayName, Font = Theme.Fonts.Bold, TextSize = 18, Color = Theme.Colors.TextBright, Wrapped = false, Size = UDim2.new(1, -72, 0, 22), Position = UDim2.fromOffset(66, 10), Parent = card }).TextTruncate = Enum.TextTruncate.AtEnd
	Components.Text({ Key = "EXTRAS_BALANCE", Params = { amount = (app.Profile and app.Profile.signalMarks) or 0 }, Font = Theme.Fonts.Mono, TextSize = 13, Color = Theme.Colors.Radio, Wrapped = false, Size = UDim2.new(1, -72, 0, 18), Position = UDim2.fromOffset(66, 34), Parent = card })
end

function MainMenu.new(router, args)
	local app = router.App
	local pause = args and args.mode == "pause"
	-- phones in landscape: compact logo and slimmer buttons so everything fits without scrolling
	local compact = Components.LogicalHeight() < 600
	local buttonHeight = if compact then 38 else nil
	local root, column = Components.ScreenRoot(if pause then "PauseMenu" else "MainMenu")
	local layout = Components.List(column, Theme.Sizes.Gap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	if pause then
		Components.Heading(column, "PAUSE_TITLE", 1)
		Components.Text({ Key = "PAUSE_NOTE", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 2, Parent = column })
	else
		MainMenu.Logo(column, app, root, compact)
	end
	Components.Spacer(column, if compact then 4 else 14, 3)

	local Lobby = require(script.Parent.Lobby)
	local Settings = require(script.Parent.Settings)
	local Extras = require(script.Parent.Extras)
	local Shop = require(script.Parent.Shop)
	local Play = require(script.Parent.Play)
	local UpdatesScreen = require(script.Parent.Updates)

	local primary
	if pause then
		primary = Components.Button({ Key = "MENU_RESUME", Height = buttonHeight, Index = 1, LayoutOrder = 10, Parent = column, OnActivated = function()
			app.Resume()
		end })
	else
		-- Lost connection a moment ago? Offer the way back to the team first.
		if game:GetService("Players").LocalPlayer:GetAttribute("FZ_RejoinAvailable") then
			local rejoin = Components.Button({ Key = "MENU_REJOIN", Height = buttonHeight, Index = 1, LayoutOrder = 8, Parent = column, OnActivated = function()
				app.Rejoin()
			end })
			rejoin.Label.TextColor3 = Theme.Colors.Relay
			primary = rejoin
		end
		-- "Continue" only when the team in this server is already playing something.
		if type(SessionState.Get("Mode")) == "string" then
			primary = Components.Button({ Key = "MENU_CONTINUE", Height = buttonHeight, Index = 1, LayoutOrder = 9, Parent = column, OnActivated = function()
				app.Join()
			end })
		end
		local play = Components.Button({ Key = "MENU_PLAY", Height = buttonHeight, Index = 2, TagKey = if app.HasNewContent() then "CONTENT_NEW" else nil, LayoutOrder = 10, Parent = column, OnActivated = function()
			router:Push(Play)
		end })
		play.Tag.TextColor3 = Theme.Colors.Accent
		primary = primary or play
	end
	Components.Button({ Key = "MENU_LOBBY", Height = buttonHeight, Index = 3, LayoutOrder = 11, Parent = column, OnActivated = function()
		router:Push(Lobby)
	end })
	Components.Button({ Key = "ARCHIVE_TITLE", Height = buttonHeight, Index = 4, LayoutOrder = 12, Parent = column, OnActivated = function()
		router:Push(require(script.Parent.Archive))
	end })
	Components.Button({ Key = "MENU_SHOP", Height = buttonHeight, Index = 5, LayoutOrder = 13, Parent = column, OnActivated = function()
		router:Push(Shop)
	end })
	Components.Button({ Key = "MENU_SETTINGS", Height = buttonHeight, Index = 6, LayoutOrder = 14, Parent = column, OnActivated = function()
		router:Push(Settings)
	end })
	Components.Button({ Key = "MENU_EXTRAS", Height = buttonHeight, Index = 7, LayoutOrder = 15, Parent = column, OnActivated = function()
		router:Push(Extras)
	end })
	if pause then
		local mic = Components.Button({ Key = if app.Radio.IsMuted() then "MIC_UNMUTE" else "MIC_MUTE", Height = buttonHeight, Index = 8, LayoutOrder = 16, Parent = column })
		mic.Instance.Activated:Connect(function()
			app.Radio.ToggleMute()
			Localization.Bind(mic.Label, if app.Radio.IsMuted() then "MIC_UNMUTE" else "MIC_MUTE")
		end)
		Components.Button({ Key = "MENU_LEAVE", Height = buttonHeight, Index = 9, LayoutOrder = 17, Parent = column, OnActivated = function()
			app.Leave()
		end })
	else
		-- Quiet "What's new" link with a small dot when there is an unseen update.
		local updates = Components.Button({ Key = "MENU_UPDATES", TagKey = if app.HasNewUpdate() then "CONTENT_DOT" else nil, Height = 36, LayoutOrder = 20, Parent = column, OnActivated = function()
			router:Push(UpdatesScreen)
		end })
		updates.Label.TextSize = Theme.Sizes.TextSmall
		if compact then
			-- no room in the column on phones: small link above the player card
			updates.Instance.Parent = root
			updates.Instance.AnchorPoint = Vector2.new(1, 1)
			updates.Instance.Position = UDim2.new(1, -24, 1, -92)
			updates.Instance.Size = UDim2.fromOffset(220, 32)
		end
		updates.Label.TextColor3 = Theme.Colors.TextDim
		updates.Tag.TextColor3 = Theme.Colors.Accent
	end

	-- number the entries in display order (01, 02, ...) whatever subset is shown
	local numbered = {}
	for _, child in column:GetChildren() do
		if child:IsA("TextButton") and child:FindFirstChild("Index") then
			table.insert(numbered, child)
		end
	end
	table.sort(numbered, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i, button in numbered do
		(button:FindFirstChild("Index") :: TextLabel).Text = string.format("%02d", i)
	end
	if not pause then
		MainMenu.PlayerCard(root, app)
	end
	Components.Text({
		Text = "SILENT RELAY  ·  v" .. Config.Version .. "  ·  RELAY 07",
		Font = Theme.Fonts.Mono,
		TextSize = 13,
		Color = Theme.Colors.TextFaint,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, Theme.Sizes.Margin + 16, 1, -12),
		Size = UDim2.fromOffset(320, 18),
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
