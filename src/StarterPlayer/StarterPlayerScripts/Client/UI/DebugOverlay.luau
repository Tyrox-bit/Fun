-- DebugOverlay: real measured performance numbers (admin only, toggled from Maintenance).
-- Runs no per-frame work while hidden.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)

local DebugOverlay = {}

local label: TextLabel? = nil
local connection: RBXScriptConnection? = nil
local providers = {}

function DebugOverlay.Init(gui: ScreenGui, infoProviders)
	providers = infoProviders
	label = Components.Text({
		Name = "Debug",
		Text = "",
		Font = Theme.Fonts.Mono,
		TextSize = 14,
		Color = Theme.Colors.TextBright,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 520, 0, 20),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -136, 0, 18),
		Parent = gui,
	})
	;(label :: TextLabel).TextStrokeTransparency = 0.4
	;(label :: TextLabel).Visible = false
end

function DebugOverlay.IsVisible(): boolean
	return connection ~= nil
end

function DebugOverlay.Toggle()
	local l = label :: TextLabel
	if connection then
		connection:Disconnect()
		connection = nil
		l.Visible = false
		return
	end
	l.Visible = true
	local frames, elapsed, worst = 0, 0, 0
	connection = RunService.RenderStepped:Connect(function(dt)
		frames += 1
		elapsed += dt
		worst = math.max(worst, dt)
		if elapsed < 0.5 then
			return
		end
		local fps = frames / elapsed
		local ping = math.floor(Players.LocalPlayer:GetNetworkPing() * 1000 + 0.5)
		local memory = math.floor(Stats:GetTotalMemoryUsageMb())
		l.Text = string.format(
			"%d FPS (min %d) | %d ms | %d MB | %s Q%d | %s | %s",
			math.floor(fps + 0.5),
			math.floor(1 / worst + 0.5),
			ping,
			memory,
			providers.profile(),
			providers.quality(),
			providers.device(),
			providers.input()
		)
		frames, elapsed, worst = 0, 0, 0
	end)
end

return DebugOverlay
