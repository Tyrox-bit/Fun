-- PhotoView: renders a "supernatural" photograph from live avatar copies in a small
-- prepared scene (ViewportFrame). Sepia print, white border, a date from long ago.
-- Subjects that are no longer in the server are shown as dark silhouettes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))

local Theme = require(script.Parent.Theme)

local PhotoView = {}

local function slab(world: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.Parent = world
	return p
end

local function silhouette(world: Instance, cf: CFrame, tall: boolean?)
	local model = Instance.new("Model")
	local color = Color3.fromRGB(12, 10, 10)
	local scale = if tall then 1.7 else 1
	slab(model, Vector3.new(1.2, 2.2, 0.7) * scale, cf * CFrame.new(0, 3 * scale, 0), color, Enum.Material.SmoothPlastic)
	slab(model, Vector3.new(1, 1, 1) * scale, cf * CFrame.new(0, 4.7 * scale, 0), color, Enum.Material.SmoothPlastic)
	slab(model, Vector3.new(1.2, 2, 0.6) * scale, cf * CFrame.new(0, 1 * scale, 0), color, Enum.Material.SmoothPlastic)
	model.Parent = world
end

local function avatarCopy(userId: number): Model?
	local member = Players:GetPlayerByUserId(userId)
	local character = member and member.Character
	if not character then
		return nil
	end
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("Light") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return copy
end

-- Scene per area type: hallway, room, core door, antenna.
local function buildScene(world: Instance, area: string)
	local wall = Color3.fromRGB(110, 106, 98)
	if area == "CORE" then
		slab(world, Vector3.new(30, 1, 30), CFrame.new(0, -0.5, -10), Color3.fromRGB(70, 68, 64))
		slab(world, Vector3.new(18, 14, 1), CFrame.new(0, 7, -20), Color3.fromRGB(60, 66, 66), Enum.Material.Metal)
		slab(world, Vector3.new(14, 0.6, 1.2), CFrame.new(0, 7.5, -19.6), Color3.fromRGB(200, 60, 50), Enum.Material.Neon)
	elseif area == "ANTENNA" then
		slab(world, Vector3.new(60, 1, 60), CFrame.new(0, -0.5, -20), Color3.fromRGB(50, 56, 46), Enum.Material.Grass)
		for i = 0, 6 do
			slab(world, Vector3.new(0.6, 6, 0.6), CFrame.new(-4 + i * 0.2, 3 + i * 6, -30), Color3.fromRGB(90, 50, 40), Enum.Material.Metal)
		end
	elseif area == "HALL" then
		slab(world, Vector3.new(14, 1, 60), CFrame.new(0, -0.5, -20), Color3.fromRGB(60, 62, 58))
		slab(world, Vector3.new(1, 14, 60), CFrame.new(-7, 7, -20), wall)
		slab(world, Vector3.new(1, 14, 60), CFrame.new(7, 7, -20), wall)
	else
		slab(world, Vector3.new(30, 1, 30), CFrame.new(0, -0.5, -12), Color3.fromRGB(84, 76, 62), Enum.Material.Plastic)
		slab(world, Vector3.new(30, 14, 1), CFrame.new(0, 7, -26), wall)
		slab(world, Vector3.new(6, 0.3, 3), CFrame.new(-6, 3, -18), Color3.fromRGB(82, 62, 44), Enum.Material.Wood)
		slab(world, Vector3.new(3, 7, 2), CFrame.new(8, 3.5, -22), Color3.fromRGB(64, 84, 82), Enum.Material.Metal)
	end
end

-- photo = { id, kind, area, date, subjects = {userId...}, figureBehind? }
function PhotoView.Build(photo: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Photo"
	frame.Size = UDim2.new(1, 0, 0, 300)
	frame.BackgroundColor3 = Color3.fromRGB(236, 230, 214) -- white print border
	frame.BorderSizePixel = 0
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 34)
	padding.Parent = frame

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.fromRGB(40, 32, 22)
	viewport.ImageColor3 = Color3.fromRGB(235, 205, 160) -- sepia
	viewport.Ambient = Color3.fromRGB(150, 130, 100)
	viewport.LightColor = Color3.fromRGB(255, 225, 180)
	viewport.Parent = frame
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	buildScene(world, tostring(photo.area or "HALL"))

	local subjects = photo.subjects or {}
	for index, userId in subjects do
		local cf = CFrame.new((index - 1) * 3 - (#subjects - 1) * 1.5, 3, -14 - (index % 2) * 2) * CFrame.Angles(0, math.rad(if photo.kind == "past_self" then 160 else 180), 0)
		local copy = avatarCopy(userId)
		if copy then
			copy:PivotTo(cf)
			copy.Parent = world
		else
			silhouette(world, cf - Vector3.new(0, 3, 0))
		end
	end
	if photo.figureBehind or photo.kind == "mate_dark" then
		silhouette(world, CFrame.new(1.5, 0, -24), true)
	end

	local camera = Instance.new("Camera")
	camera.FieldOfView = 55
	camera.CFrame = CFrame.lookAt(Vector3.new(3, 8, 6), Vector3.new(0, 3, -16))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.AnchorPoint = Vector2.new(0, 0)
	caption.Position = UDim2.new(0, 0, 1, 4)
	caption.Size = UDim2.new(1, 0, 0, 24)
	caption.Font = Theme.Fonts.Mono
	caption.TextSize = 15
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.TextColor3 = Color3.fromRGB(60, 50, 40)
	caption.AutoLocalize = false
	caption.Text = Localization.T("PHOTO_CAPTION", { date = tostring(photo.date or "??.??.19??"), place = Localization.T("AREA_" .. tostring(photo.area or "UNKNOWN")) })
	caption.Parent = frame
	return frame
end

return PhotoView
