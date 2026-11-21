-- Boot screen: shown instantly, before anything else loads. Deliberately language-neutral
-- (only the game logo) so the player never sees text in a wrong language while the saved
-- language is still loading. The main client script fades it out when ready.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "FZ_Boot"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.AutoLocalize = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(5, 7, 10)
background.BorderSizePixel = 0
background.Parent = gui

-- Two-tone logo: SILENT (white) RELAY (signal red)
local title = Instance.new("TextLabel")
title.Name = "Logo"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.47)
title.Size = UDim2.new(0.9, 0, 0, 60)
title.BackgroundTransparency = 1
title.Font = Enum.Font.Michroma
title.RichText = true
title.Text = 'SILENT <font color="#E83E32">RELAY</font>'
title.TextColor3 = Color3.fromRGB(246, 246, 242)
title.TextSize = 46
title.TextScaled = false
title.AutoLocalize = false
title.Parent = background
local sizeCap = Instance.new("UITextSizeConstraint")
sizeCap.MaxTextSize = 46
sizeCap.Parent = title

local kicker = Instance.new("TextLabel")
kicker.Name = "Kicker"
kicker.AnchorPoint = Vector2.new(0.5, 0.5)
kicker.Position = UDim2.new(0.5, 0, 0.47, -46)
kicker.Size = UDim2.new(0.8, 0, 0, 18)
kicker.BackgroundTransparency = 1
kicker.Font = Enum.Font.RobotoMono
kicker.Text = "RELAY 07  ·  147.300 MHz"
kicker.TextColor3 = Color3.fromRGB(136, 146, 156)
kicker.TextSize = 14
kicker.AutoLocalize = false
kicker.Parent = background

-- A thin signal line that slowly "searches" - the only motion on screen.
local line = Instance.new("Frame")
line.Name = "Signal"
line.AnchorPoint = Vector2.new(0.5, 0.5)
line.Position = UDim2.new(0.5, 0, 0.47, 46)
line.Size = UDim2.fromOffset(0, 2)
line.BackgroundColor3 = Color3.fromRGB(232, 62, 50)
line.BorderSizePixel = 0
line.Parent = background

gui.Parent = playerGui

TweenService:Create(
	line,
	TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Size = UDim2.fromOffset(320, 2) }
):Play()
