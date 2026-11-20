-- Greybox: a small, script-built test area (gate + gatehouse) so every system can be
-- tested on any device right after syncing - before the real map exists.
-- It is only built when Workspace has no "FZ_Map" model. Replace it by building the real
-- map in Studio, naming its root model "FZ_Map" and placing the same tags/attributes.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Greybox = {}

local COLORS = {
	Asphalt = Color3.fromRGB(38, 40, 42),
	Concrete = Color3.fromRGB(112, 110, 104),
	ConcreteDark = Color3.fromRGB(72, 72, 70),
	PaintedSteel = Color3.fromRGB(70, 92, 88),
	Linoleum = Color3.fromRGB(96, 84, 64),
	Wood = Color3.fromRGB(86, 64, 46),
	Plastic = Color3.fromRGB(196, 190, 176),
	Paper = Color3.fromRGB(226, 220, 204),
	Sodium = Color3.fromRGB(255, 170, 96),
}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- World text that every client renders in its own language (see WorldTextController).
local function worldText(target: BasePart, face: Enum.NormalId, key: string?, staticText: string?, params: { [string]: string }?, textColor: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 1
	gui.AutoLocalize = false
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.RobotoMono
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = textColor or Color3.fromRGB(30, 28, 26)
	label.Text = staticText or ""
	label.AutoLocalize = false
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	if key then
		label:SetAttribute("LocKey", key)
		for name, value in params or {} do
			label:SetAttribute("LocParam_" .. name, value)
		end
		CollectionService:AddTag(label, "FZ_WorldText")
	end
	label.Parent = gui
end

local function buildLighting()
	Lighting.ClockTime = 0.6
	Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(18, 21, 24)
	Lighting.OutdoorAmbient = Color3.fromRGB(34, 40, 46)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.38
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(112, 124, 130)
	atmosphere.Decay = Color3.fromRGB(52, 62, 68)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
end

function Greybox.Build()
	local root = Instance.new("Model")
	root.Name = "FZ_Greybox"

	-- Ground and access road
	part(root, "Ground", Vector3.new(220, 1, 220), CFrame.new(0, -0.5, 0), COLORS.Asphalt, Enum.Material.Asphalt)

	-- Gate: two concrete pillars, a steel beam, the station sign and a sodium lamp
	local gateZ = 10
	part(root, "GatePillarL", Vector3.new(2, 9, 2), CFrame.new(-9, 4.5, gateZ), COLORS.Concrete, Enum.Material.Concrete)
	part(root, "GatePillarR", Vector3.new(2, 9, 2), CFrame.new(9, 4.5, gateZ), COLORS.Concrete, Enum.Material.Concrete)
	part(root, "GateBeam", Vector3.new(20, 0.8, 0.8), CFrame.new(0, 8.6, gateZ), COLORS.PaintedSteel, Enum.Material.Metal)
	local sign = part(root, "StationSign", Vector3.new(10, 2.6, 0.3), CFrame.new(0, 6.6, gateZ + 0.6), COLORS.Plastic, Enum.Material.SmoothPlastic)
	worldText(sign, Enum.NormalId.Back, "SIGN_STATION")

	local lampPost = part(root, "LampPost", Vector3.new(0.5, 12, 0.5), CFrame.new(-13, 6, gateZ + 2), COLORS.PaintedSteel, Enum.Material.Metal)
	local lampHead = part(root, "LampHead", Vector3.new(1.8, 0.5, 1), lampPost.CFrame * CFrame.new(0.8, 6, 0), COLORS.Plastic, Enum.Material.Neon)
	lampHead.Color = COLORS.Sodium
	local lamp = Instance.new("SpotLight")
	lamp.Face = Enum.NormalId.Bottom
	lamp.Angle = 100
	lamp.Range = 34
	lamp.Brightness = 3
	lamp.Color = COLORS.Sodium
	lamp.Shadows = true
	lamp.Parent = lampHead
	CollectionService:AddTag(lampHead, "FZ_KeyLight")

	-- Gatehouse (behind the gate, door facing the players)
	local gx, gz = 0, -14
	local w, d, h = 16, 12, 9
	part(root, "GH_Floor", Vector3.new(w, 0.4, d), CFrame.new(gx, 0.2, gz), COLORS.Linoleum, Enum.Material.Plastic)
	part(root, "GH_Roof", Vector3.new(w + 1, 0.6, d + 1), CFrame.new(gx, h + 0.3, gz), COLORS.ConcreteDark, Enum.Material.Concrete)
	part(root, "GH_WallBack", Vector3.new(w, h, 0.6), CFrame.new(gx, h / 2, gz - d / 2), COLORS.Concrete, Enum.Material.Concrete)
	part(root, "GH_WallL", Vector3.new(0.6, h, d), CFrame.new(gx - w / 2, h / 2, gz), COLORS.Concrete, Enum.Material.Concrete)
	part(root, "GH_WallR", Vector3.new(0.6, h, d), CFrame.new(gx + w / 2, h / 2, gz), COLORS.Concrete, Enum.Material.Concrete)
	-- Front wall with a door opening (4 studs wide, 7 high) in the middle
	local side = (w - 4) / 2
	part(root, "GH_FrontL", Vector3.new(side, h, 0.6), CFrame.new(gx - 2 - side / 2, h / 2, gz + d / 2), COLORS.Concrete, Enum.Material.Concrete)
	part(root, "GH_FrontR", Vector3.new(side, h, 0.6), CFrame.new(gx + 2 + side / 2, h / 2, gz + d / 2), COLORS.Concrete, Enum.Material.Concrete)
	part(root, "GH_FrontTop", Vector3.new(4, h - 7, 0.6), CFrame.new(gx, 7 + (h - 7) / 2, gz + d / 2), COLORS.Concrete, Enum.Material.Concrete)

	-- Ceiling light (warm, slightly weak)
	local ceilingLamp = part(root, "GH_CeilingLamp", Vector3.new(3, 0.2, 0.8), CFrame.new(gx, h - 0.1, gz), COLORS.Plastic, Enum.Material.Neon)
	ceilingLamp.Color = Color3.fromRGB(255, 214, 160)
	local ceilingLight = Instance.new("PointLight")
	ceilingLight.Range = 16
	ceilingLight.Brightness = 0.9
	ceilingLight.Color = Color3.fromRGB(255, 206, 150)
	ceilingLight.Shadows = true
	ceilingLight.Parent = ceilingLamp
	CollectionService:AddTag(ceilingLamp, "FZ_KeyLight")

	-- Desk, fax machine (interactable) and logbook (code VESPER-0214)
	local desk = part(root, "GH_Desk", Vector3.new(7, 3, 2.6), CFrame.new(gx + 3, 1.9, gz - d / 2 + 1.8), COLORS.Wood, Enum.Material.Wood)
	local fax = part(root, "GH_Fax", Vector3.new(1.6, 0.6, 1.2), desk.CFrame * CFrame.new(1.6, 1.8, 0), COLORS.Plastic, Enum.Material.SmoothPlastic)
	fax:SetAttribute("InteractId", "c1_fax")
	fax:SetAttribute("ActionKey", "INTERACT_READ")
	fax:SetAttribute("ObjectKey", "OBJECT_FAX")
	fax:SetAttribute("MaxDistance", 7)
	CollectionService:AddTag(fax, "FZ_Interactable")
	local faxLed = Instance.new("PointLight")
	faxLed.Range = 3
	faxLed.Brightness = 1.5
	faxLed.Color = Color3.fromRGB(255, 90, 60)
	faxLed.Parent = fax

	local logbook = part(root, "GH_Logbook", Vector3.new(1.4, 0.1, 1), desk.CFrame * CFrame.new(-1.8, 1.55, 0.2), COLORS.Paper, Enum.Material.Fabric)
	worldText(logbook, Enum.NormalId.Top, nil, "02:14  VESPER-0214")

	-- Notice board with the maintenance note (code SIGNAL-017)
	local board = part(root, "GH_NoticeBoard", Vector3.new(4.5, 3.2, 0.2), CFrame.new(gx - w / 2 + 0.45, 4.6, gz - 1) * CFrame.Angles(0, math.rad(-90), 0), Color3.fromRGB(120, 96, 70), Enum.Material.Cardboard)
	local note = part(root, "GH_Note", Vector3.new(2.4, 1.9, 0.05), board.CFrame * CFrame.new(0.4, 0.2, -0.13), COLORS.Paper, Enum.Material.SmoothPlastic)
	worldText(note, Enum.NormalId.Front, "NOTE_MAINTENANCE", nil, { code = "SIGNAL-017" })

	-- Spawn, team checkpoint and menu camera
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "FZ_Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.5, 46) -- behind the menu camera, out of shot
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	local checkpoint = part(root, "CP_C1_START", Vector3.new(4, 1, 4), CFrame.new(0, 0.5, 22) * CFrame.Angles(0, 0, 0), COLORS.Asphalt, Enum.Material.Asphalt)
	checkpoint.Transparency = 1
	checkpoint.CanCollide = false
	checkpoint.CanQuery = false
	checkpoint:SetAttribute("CheckpointId", "C1_START")
	CollectionService:AddTag(checkpoint, "FZ_Checkpoint")

	local menuCamera = part(root, "MenuCamera", Vector3.new(1, 1, 1), CFrame.lookAt(Vector3.new(-7, 3.2, 36), Vector3.new(0, 4.5, gz)), COLORS.Asphalt, Enum.Material.Plastic)
	menuCamera.Transparency = 1
	menuCamera.CanCollide = false
	menuCamera.CanQuery = false
	CollectionService:AddTag(menuCamera, "FZ_MenuCamera")

	buildLighting()
	root.Parent = workspace
	return root
end

return Greybox
