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
background.BackgroundColor3 = Color3.fromRGB(6, 8, 9)
background.BorderSizePixel = 0
background.Parent = gui

local title = Instance.new("TextLabel")
title.Name = "Logo"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.48)
title.Size = UDim2.new(0.8, 0, 0, 40)
title.BackgroundTransparency = 1
title.Font = Enum.Font.Michroma
title.Text = "SILENT RELAY"
title.TextColor3 = Color3.fromRGB(216, 212, 202)
title.TextSize = 30
title.AutoLocalize = false
title.Parent = background

-- A thin signal line that slowly "searches" - the only motion on screen.
local line = Instance.new("Frame")
line.Name = "Signal"
line.AnchorPoint = Vector2.new(0.5, 0.5)
line.Position = UDim2.new(0.5, 0, 0.48, 34)
line.Size = UDim2.fromOffset(0, 2)
line.BackgroundColor3 = Color3.fromRGB(201, 64, 48)
line.BorderSizePixel = 0
line.Parent = background

gui.Parent = playerGui

TweenService:Create(
	line,
	TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Size = UDim2.fromOffset(180, 2) }
):Play()
