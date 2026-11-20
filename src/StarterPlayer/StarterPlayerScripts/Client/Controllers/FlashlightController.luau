-- FlashlightController: precise camera-aligned light for the local player, plus the
-- replicated head light (FlashlightService) so teammates see it too. The local player's
-- own replicated copy is muted locally to avoid a double light.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local InputController = require(script.Parent.InputController)

local FlashlightController = {}

local player = Players.LocalPlayer
local enabled = false
local lightPart: Part? = nil
local follow: RBXScriptConnection? = nil
local setRemote = Net.Event("SetFlashlight")

local OFFSET = CFrame.new(0.6, -0.5, -0.4)

local function ensurePart(): Part
	if lightPart and lightPart.Parent then
		return lightPart
	end
	local part = Instance.new("Part")
	part.Name = "FZ_LocalFlashlight"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	local light = Instance.new("SpotLight")
	light.Name = "Light"
	light.Face = Enum.NormalId.Front
	light.Angle = 50
	light.Range = 40
	light.Brightness = 2.4
	light.Color = Color3.fromRGB(255, 236, 206)
	light.Shadows = true
	light.Parent = part
	part.Parent = workspace.CurrentCamera
	lightPart = part
	return part
end

local function muteOwnReplicatedLight(character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	local function mute(child: Instance)
		if child.Name == "FZ_Flashlight" and child:IsA("SpotLight") then
			child.Brightness = 0 -- local only; the server never changes Brightness
		end
	end
	for _, child in head:GetChildren() do
		mute(child)
	end
	head.ChildAdded:Connect(mute)
end

function FlashlightController.Set(value: boolean)
	enabled = value
	local part = ensurePart()
	local light = part:FindFirstChild("Light") :: SpotLight
	light.Enabled = value
	if value and not follow then
		follow = RunService.RenderStepped:Connect(function()
			local camera = workspace.CurrentCamera
			if camera then
				part.CFrame = camera.CFrame * OFFSET
			end
		end)
	elseif not value and follow then
		follow:Disconnect()
		follow = nil
	end
	InputController.SetTouchActive("Flashlight", value)
	setRemote:FireServer(value)
end

function FlashlightController.IsOn(): boolean
	return enabled
end

function FlashlightController.Init()
	InputController.Action:Connect(function(name, pressed)
		if name == "Flashlight" and pressed then
			FlashlightController.Set(not enabled)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		muteOwnReplicatedLight(character)
		if enabled then
			setRemote:FireServer(true) -- new character, re-sync state
		end
	end)
	if player.Character then
		task.spawn(muteOwnReplicatedLight, player.Character)
	end
end

return FlashlightController
