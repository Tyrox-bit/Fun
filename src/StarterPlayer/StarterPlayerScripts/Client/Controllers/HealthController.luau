-- HealthController: health HUD (only visible when hurt), damage vignette, downed overlay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)

local HealthController = {}

local player = Players.LocalPlayer

function HealthController.Init(hudGui: ScreenGui, settings)
	-- Damage flash: a red screen edge (UIStroke), no texture asset required.
	local edge = Instance.new("Frame")
	edge.Name = "DamageEdge"
	edge.BackgroundTransparency = 1
	edge.Size = UDim2.fromScale(1, 1)
	edge.Parent = hudGui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Accent
	stroke.Thickness = 28
	stroke.Transparency = 1
	stroke.Parent = edge
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new(0.2)
	gradient.Parent = stroke

	local bar = Instance.new("Frame")
	bar.Name = "Health"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 24, 1, -16)
	bar.Size = UDim2.fromOffset(180, 4)
	bar.BackgroundColor3 = Theme.Colors.TextFaint
	bar.BackgroundTransparency = 0.4
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = hudGui
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Theme.Colors.TextBright
	fill.Size = UDim2.fromScale(1, 1)
	Components.Corner(fill, 2)
	Components.Corner(bar, 2)
	fill.Parent = bar

	local downed = Components.Text({ Key = "HUD_DOWNED", Font = Theme.Fonts.Medium, TextSize = Theme.Sizes.TextHeading, Color = Theme.Colors.TextBright, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(0.8, 0, 0, 40), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Parent = hudGui })
	downed.TextStrokeTransparency = 0.4
	downed.Visible = false

	local function cameraScale(): number
		local value = settings.Get("cameraEffects")
		return if value == "off" then 0 elseif value == "reduced" then 0.5 else 1
	end

	local function bindHumanoid(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		local function update()
			local ratio = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
			bar.Visible = (ratio < 0.999 or settings.Get("alwaysShowHealth") == true) and player:GetAttribute("FZ_InGame") == true and not player:GetAttribute("FZ_MonsterMode")
			fill.Size = UDim2.fromScale(ratio, 1)
			fill.BackgroundColor3 = if ratio < 0.35 then Theme.Colors.Accent else Theme.Colors.TextBright
		end
		humanoid.HealthChanged:Connect(update)
		settings.Changed:Connect(function(key)
			if key == "alwaysShowHealth" then
				update()
			end
		end)
		player:GetAttributeChangedSignal("FZ_InGame"):Connect(update)
		update()
	end
	player.CharacterAdded:Connect(bindHumanoid)
	if player.Character then
		task.spawn(bindHumanoid, player.Character)
	end

	Net.Event("Hurt").OnClientEvent:Connect(function()
		stroke.Transparency = 0.15
		TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
		local camera = workspace.CurrentCamera
		local scale = cameraScale()
		if camera and scale > 0 then
			-- short, small kick (no strong shake)
			local original = camera.FieldOfView
			camera.FieldOfView = original - 3 * scale
			TweenService:Create(camera, TweenInfo.new(0.35), { FieldOfView = original }):Play()
		end
	end)

	-- (the downed countdown is shown by RescueController)
	downed:Destroy()
end

return HealthController
