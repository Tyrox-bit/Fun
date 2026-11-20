-- FlashlightService: replicated flashlight so teammates see each other's light.
-- The owning client additionally renders a camera-aligned local light for precision
-- and mutes its own replicated copy (see FlashlightController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local FlashlightService = {}

local function attach(character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") or head:FindFirstChild("FZ_Flashlight") then
		return
	end
	local light = Instance.new("SpotLight")
	light.Name = "FZ_Flashlight"
	light.Face = Enum.NormalId.Front
	light.Angle = 55
	light.Range = 38
	light.Brightness = 2.2
	light.Color = Color3.fromRGB(255, 236, 206)
	light.Shadows = true
	light.Enabled = false
	light.Parent = head
end

function FlashlightService.Start()
	local limiter = RateLimiter.new(6, 3)
	Net.Event("SetFlashlight").OnServerEvent:Connect(function(player: Player, enabled: any)
		if type(enabled) ~= "boolean" or not limiter:Allow(player) then
			return
		end
		local head = player.Character and player.Character:FindFirstChild("Head")
		local light = head and head:FindFirstChild("FZ_Flashlight")
		if light and light:IsA("SpotLight") then
			light.Enabled = enabled
		end
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(attach)
		if player.Character then
			task.spawn(attach, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return FlashlightService
