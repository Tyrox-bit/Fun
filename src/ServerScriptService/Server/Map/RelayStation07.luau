-- Relay Station 07 - script-built playable map following the concept floor plan:
--
--            N (-Z)
--   [Sektor C]──────[N-Halle]──────[Sektor D]
--   [Sektor B]─[W]─( ZENTRALKERN )─[O]─[Sektor A]
--   [Sektor E]──────[S-Halle]──────[Eingang/Kontrolle]──► Hof, Straße, Tor
--                     Außenbereich: Antenne (Extraktion)
--
-- Everything gameplay-relevant is expressed through tags + attributes, so you can replace
-- any part of it with your own Studio build later (see docs/MAP_CONTRACT.md):
--   FZ_Interactable, FZ_Door, FZ_SectorLight, FZ_FuseSpot, FZ_CreaturePatrol, FZ_Vent,
--   FZ_CreatureSpawn, FZ_Checkpoint, FZ_MenuCamera, FZ_WorldText, FZ_KeyLight.
-- It is only built when Workspace has no "FZ_Map" model.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Map = {}

local H = 14 -- wall height
local DOOR_H = 10
local T = 1 -- wall thickness

local C = {
	Concrete = Color3.fromRGB(104, 104, 100),
	ConcreteDark = Color3.fromRGB(64, 66, 66),
	Floor = Color3.fromRGB(78, 74, 66),
	Linoleum = Color3.fromRGB(92, 84, 66),
	Steel = Color3.fromRGB(64, 84, 82),
	SteelDark = Color3.fromRGB(42, 48, 50),
	Wood = Color3.fromRGB(82, 62, 44),
	Plastic = Color3.fromRGB(190, 184, 170),
	Paper = Color3.fromRGB(226, 220, 204),
	Sodium = Color3.fromRGB(255, 170, 96),
	Fluorescent = Color3.fromRGB(214, 236, 230),
	Emergency = Color3.fromRGB(200, 40, 30),
	Screen = Color3.fromRGB(90, 220, 140),
	Asphalt = Color3.fromRGB(36, 38, 40),
	Pine = Color3.fromRGB(28, 44, 34),
	Bark = Color3.fromRGB(52, 40, 32),
}

local root: Model
local rng = Random.new(707)

---------------------------------------------------------------------------
-- Primitive helpers
---------------------------------------------------------------------------
local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function folder(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

local function tag(instance: Instance, tagName: string, attributes: { [string]: any }?)
	for key, value in attributes or {} do
		instance:SetAttribute(key, value)
	end
	CollectionService:AddTag(instance, tagName)
end

local function worldText(target: BasePart, face: Enum.NormalId, key: string?, staticText: string?, params: { [string]: string }?, color: Color3?, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.AutoLocalize = false
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font or Enum.Font.RobotoMono
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color or Color3.fromRGB(30, 28, 26)
	label.Text = staticText or ""
	label.AutoLocalize = false
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label
	if key then
		label:SetAttribute("LocKey", key)
		for name, value in params or {} do
			label:SetAttribute("LocParam_" .. name, value)
		end
		CollectionService:AddTag(label, "FZ_WorldText")
	end
	label.Parent = gui
	return label
end

---------------------------------------------------------------------------
-- Walls with door gaps. gaps = { { center, width } }
---------------------------------------------------------------------------
local walls: Folder

local function wallSegments(a: number, b: number, gaps: { { number } }?): { { number } }
	local segments = {}
	local cursor = a
	local sorted = table.clone(gaps or {})
	table.sort(sorted, function(x, y)
		return x[1] < y[1]
	end)
	for _, gap in sorted do
		local g0, g1 = gap[1] - gap[2] / 2, gap[1] + gap[2] / 2
		if g0 > cursor then
			table.insert(segments, { cursor, g0, false })
		end
		table.insert(segments, { g0, g1, true })
		cursor = g1
	end
	if cursor < b then
		table.insert(segments, { cursor, b, false })
	end
	return segments
end

-- Wall running along X at constant z.
local function wallZ(z: number, x0: number, x1: number, gaps: { { number } }?, color: Color3?)
	for _, s in wallSegments(x0, x1, gaps) do
		local width = s[2] - s[1]
		local mid = (s[1] + s[2]) / 2
		if s[3] then
			block(walls, "Lintel", Vector3.new(width, H - DOOR_H, T), CFrame.new(mid, DOOR_H + (H - DOOR_H) / 2, z), color or C.Concrete, Enum.Material.Concrete)
		else
			block(walls, "Wall", Vector3.new(width, H, T), CFrame.new(mid, H / 2, z), color or C.Concrete, Enum.Material.Concrete)
		end
	end
end

-- Wall running along Z at constant x.
local function wallX(x: number, z0: number, z1: number, gaps: { { number } }?, color: Color3?)
	for _, s in wallSegments(z0, z1, gaps) do
		local depth = s[2] - s[1]
		local mid = (s[1] + s[2]) / 2
		if s[3] then
			block(walls, "Lintel", Vector3.new(T, H - DOOR_H, depth), CFrame.new(x, DOOR_H + (H - DOOR_H) / 2, mid), color or C.Concrete, Enum.Material.Concrete)
		else
			block(walls, "Wall", Vector3.new(T, H, depth), CFrame.new(x, H / 2, mid), color or C.Concrete, Enum.Material.Concrete)
		end
	end
end

---------------------------------------------------------------------------
-- Doors: sliding steel doors, optionally power-locked
---------------------------------------------------------------------------
local doors: Folder
local doorCount = 0

local function door(center: Vector3, alongX: boolean, width: number, locked: boolean?, sector: string?)
	doorCount += 1
	local size = if alongX then Vector3.new(width, DOOR_H, 0.6) else Vector3.new(0.6, DOOR_H, width)
	local closed = CFrame.new(center.X, DOOR_H / 2, center.Z)
	local slide = if alongX then Vector3.new(width - 0.4, 0, 0) else Vector3.new(0, 0, width - 0.4)
	local panel = block(doors, "Door" .. doorCount, size, closed, C.Steel, Enum.Material.Metal)
	local stripe = block(panel, "Stripe", if alongX then Vector3.new(width, 0.4, 0.7) else Vector3.new(0.7, 0.4, width), closed * CFrame.new(0, 1.5, 0), if locked then C.Emergency else C.Plastic, Enum.Material.Neon)
	stripe.CanCollide = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = panel
	weld.Part1 = stripe
	weld.Parent = panel
	stripe.Anchored = false
	local modifier = Instance.new("PathfindingModifier")
	modifier.PassThrough = not locked
	modifier.Parent = panel
	tag(panel, "FZ_Door", {
		DoorId = "D" .. doorCount,
		Open = false,
		Locked = locked == true,
		PowerSector = sector or "",
		ClosedCFrame = closed,
		OpenCFrame = closed + slide,
	})
	tag(panel, "FZ_Interactable", {
		InteractId = "door",
		ActionKey = "INTERACT_OPEN",
		ObjectKey = "OBJECT_DOOR",
		MaxDistance = 9,
	})
	return panel
end

---------------------------------------------------------------------------
-- Lights (tagged by sector so PowerService can switch them)
---------------------------------------------------------------------------
local lights: Folder
local lightsPerSector: { [string]: number } = {}

-- The first light of every sector is a key light (on at every graphics level), so no
-- room is ever pitch black on low-end devices; further lights are decorative.
local function ceilingLight(position: Vector3, sector: string, color: Color3?, shadows: boolean?, forceKey: boolean?)
	lightsPerSector[sector] = (lightsPerSector[sector] or 0) + 1
	local key = forceKey or lightsPerSector[sector] == 1
	local fixture = block(lights, "Fixture_" .. sector, Vector3.new(6, 0.3, 1), CFrame.new(position.X, H - 0.2, position.Z), color or C.Fluorescent, Enum.Material.Neon)
	fixture.CanCollide = false
	fixture.CastShadow = false
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 22
	light.Angle = 120
	light.Brightness = 1.1
	light.Color = color or C.Fluorescent
	light.Shadows = shadows == true
	light.Parent = fixture
	tag(fixture, "FZ_SectorLight", { Sector = sector, OnColor = color or C.Fluorescent })
	if key then
		CollectionService:AddTag(fixture, "FZ_KeyLight")
	else
		CollectionService:AddTag(fixture, "FZ_DecorLight")
	end
	return fixture
end

local function emergencyLight(position: Vector3, sector: string)
	local lamp = block(lights, "Emergency", Vector3.new(0.8, 0.5, 0.8), CFrame.new(position), C.Emergency, Enum.Material.Neon)
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 0.7
	light.Color = C.Emergency
	light.Parent = lamp
	CollectionService:AddTag(lamp, "FZ_KeyLight") -- emergency lights never turn off: readable darkness
	lamp:SetAttribute("Sector", sector)
	return lamp
end

---------------------------------------------------------------------------
-- Props
---------------------------------------------------------------------------
local props: Folder

local function desk(cf: CFrame)
	block(props, "Desk", Vector3.new(6, 0.3, 3), cf * CFrame.new(0, 3, 0), C.Wood, Enum.Material.Wood)
	for _, x in { -2.7, 2.7 } do
		block(props, "DeskLeg", Vector3.new(0.4, 3, 2.6), cf * CFrame.new(x, 1.5, 0), C.SteelDark, Enum.Material.Metal)
	end
end

local function console(cf: CFrame)
	block(props, "Console", Vector3.new(7, 3.4, 2.4), cf * CFrame.new(0, 1.7, 0), C.SteelDark, Enum.Material.Metal)
	block(props, "ConsoleTop", Vector3.new(7, 0.3, 2.6), cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(math.rad(-12), 0, 0), C.Steel, Enum.Material.Metal)
	local screens = {}
	for i = -1, 1 do
		local screen = block(props, "Monitor", Vector3.new(1.9, 1.5, 1.2), cf * CFrame.new(i * 2.2, 4.6, 0.4), C.ConcreteDark, Enum.Material.SmoothPlastic)
		local glass = block(props, "Screen", Vector3.new(1.6, 1.1, 0.05), screen.CFrame * CFrame.new(0, 0, -0.62), C.Screen, Enum.Material.Neon)
		glass.Transparency = 0.25
		glass.CanCollide = false
		table.insert(screens, glass)
	end
	return screens
end


local function cabinet(cf: CFrame)
	block(props, "Cabinet", Vector3.new(3, 7, 2), cf * CFrame.new(0, 3.5, 0), C.Steel, Enum.Material.Metal)
end

local function shelf(cf: CFrame)
	block(props, "Shelf", Vector3.new(8, 9, 2), cf * CFrame.new(0, 4.5, 0), C.Wood, Enum.Material.Wood)
	for row = 1, 4 do
		block(props, "Files", Vector3.new(7.2, 1.4, 1.6), cf * CFrame.new(0, row * 2 - 0.3, -0.1), C.Paper:Lerp(C.Wood, rng:NextNumber(0.2, 0.6)), Enum.Material.Cardboard)
	end
end

local function bunk(cf: CFrame)
	for _, y in { 1.6, 5.2 } do
		block(props, "Bed", Vector3.new(4, 0.8, 8), cf * CFrame.new(0, y, 0), C.Plastic:Lerp(C.Steel, 0.5), Enum.Material.Fabric)
	end
	for _, x in { -1.9, 1.9 } do
		for _, z in { -3.8, 3.8 } do
			block(props, "BunkPost", Vector3.new(0.3, 6.4, 0.3), cf * CFrame.new(x, 3.2, z), C.SteelDark, Enum.Material.Metal)
		end
	end
end

local function locker(cf: CFrame)
	block(props, "Locker", Vector3.new(2, 7, 2), cf * CFrame.new(0, 3.5, 0), C.Steel:Lerp(C.Plastic, 0.2), Enum.Material.Metal)
end

local function labTable(cf: CFrame)
	block(props, "LabTable", Vector3.new(8, 3.2, 3.5), cf * CFrame.new(0, 1.6, 0), C.Plastic, Enum.Material.SmoothPlastic)
	for i = -1, 1 do
		local flask = block(props, "Instrument", Vector3.new(1, 1.4, 1), cf * CFrame.new(i * 2.5, 3.9, 0), C.Screen:Lerp(C.Plastic, 0.6), Enum.Material.Glass)
		flask.Transparency = 0.3
	end
end

local function generator(cf: CFrame)
	local body = block(props, "Generator", Vector3.new(8, 6, 5), cf * CFrame.new(0, 3, 0), C.Steel:Lerp(C.Emergency, 0.15), Enum.Material.Metal)
	local drum = block(props, "Drum", Vector3.new(7, 4, 4), cf * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(90)), C.SteelDark, Enum.Material.Metal)
	drum.Shape = Enum.PartType.Cylinder
	drum.Size = Vector3.new(7, 4, 4)
	drum.CFrame = cf * CFrame.new(0, 7.5, 0)
	return body
end

local function pipeRun(from: Vector3, to: Vector3, radius: number?)
	local length = (to - from).Magnitude
	local pipe = block(props, "Pipe", Vector3.new(length, (radius or 0.6) * 2, (radius or 0.6) * 2), CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0), C.SteelDark, Enum.Material.Metal)
	pipe.Shape = Enum.PartType.Cylinder
	pipe.CanCollide = false
end

local function sign(position: Vector3, facing: Vector3, key: string)
	local plate = block(props, "Sign", Vector3.new(8, 2.4, 0.2), CFrame.lookAt(position, position + facing), C.Plastic, Enum.Material.SmoothPlastic)
	plate.CanCollide = false
	worldText(plate, Enum.NormalId.Front, key)
end

local function vent(position: Vector3, facing: Vector3, group: string)
	local grate = block(props, "Vent", Vector3.new(3, 2, 0.3), CFrame.lookAt(position, position + facing), C.SteelDark, Enum.Material.DiamondPlate)
	grate.CanCollide = false
	tag(grate, "FZ_Vent", { VentGroup = group })
end

local function patrol(position: Vector3, area: string)
	local node = block(props, "PatrolNode", Vector3.new(1, 1, 1), CFrame.new(position.X, 3, position.Z), C.Concrete)
	node.Transparency = 1
	node.CanCollide = false
	node.CanQuery = false
	node.CanTouch = false
	tag(node, "FZ_CreaturePatrol", { Area = area })
end

local function fuseSpot(cf: CFrame, sector: string)
	local spot = block(props, "FuseSpot", Vector3.new(1, 1, 1), cf, C.Concrete)
	spot.Transparency = 1
	spot.CanCollide = false
	spot.CanQuery = false
	tag(spot, "FZ_FuseSpot", { Sector = sector })
end

local function checkpoint(id: string, cf: CFrame)
	local p = block(props, "CP_" .. id, Vector3.new(4, 1, 4), cf, C.Concrete)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	tag(p, "FZ_Checkpoint", { CheckpointId = id })
end

local function interactable(part: BasePart, id: string, action: string, object: string, extra: { [string]: any }?)
	local attributes = { InteractId = id, ActionKey = action, ObjectKey = object }
	for key, value in extra or {} do
		attributes[key] = value
	end
	tag(part, "FZ_Interactable", attributes)
end

-- Breaker cabinet on a wall (forecasts are broken by holding the right breaker).
local function breakerBox(cf: CFrame, sector: string, interactId: string)
	local box = block(props, "Breaker" .. sector, Vector3.new(3, 4, 0.8), cf, C.Steel:Lerp(C.Emergency, 0.25), Enum.Material.Metal)
	interactable(box, interactId, "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER_" .. sector, { MaxDistance = 8, Sector = sector })
	return box
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function buildShell()
	walls = folder("Walls")
	doors = folder("Doors")
	lights = folder("Lights")
	props = folder("Props")
	local structure = folder("Structure")

	-- Floors
	block(structure, "Floor_West", Vector3.new(50, 1, 170), CFrame.new(-75, -0.5, 0), C.Floor, Enum.Material.Concrete)
	block(structure, "Floor_East", Vector3.new(50, 1, 155), CFrame.new(75, -0.5, -7.5), C.Linoleum, Enum.Material.Plastic)
	block(structure, "Floor_Center", Vector3.new(100, 1, 120), CFrame.new(0, -0.5, 0), C.Floor, Enum.Material.Concrete)
	-- Roofs (separate per block so the shape reads from outside)
	block(structure, "Roof_West", Vector3.new(52, 1.2, 172), CFrame.new(-75, H + 0.6, 0), C.ConcreteDark, Enum.Material.Concrete)
	block(structure, "Roof_East", Vector3.new(52, 1.2, 157), CFrame.new(75, H + 0.6, -7.5), C.ConcreteDark, Enum.Material.Concrete)
	block(structure, "Roof_Center", Vector3.new(100, 1.2, 122), CFrame.new(0, H + 0.6, 0), C.ConcreteDark, Enum.Material.Concrete)

	-- Radome on the roof above the core: the landmark visible from the whole site.
	local radome = block(structure, "Radome", Vector3.new(30, 30, 30), CFrame.new(0, H + 10, 0), Color3.fromRGB(200, 202, 198), Enum.Material.Fabric)
	radome.Shape = Enum.PartType.Ball
	block(structure, "RadomeBase", Vector3.new(24, 4, 24), CFrame.new(0, H + 2.5, 0), C.ConcreteDark, Enum.Material.Concrete)

	-- Outer walls
	wallZ(-85, -100, -50)
	wallZ(-85, 50, 100)
	wallZ(-60, -50, 50)
	wallX(-100, -85, 85)
	wallX(100, -85, 70)
	wallZ(85, -100, -50)
	wallZ(60, -50, 50)
	wallZ(70, 50, 100, { { 75, 8 } }) -- main entrance

	-- West block: C | B | E
	wallZ(-25, -100, -50, { { -75, 6 } })
	wallZ(25, -100, -50, { { -75, 6 } })
	wallX(-50, -85, -25, { { -55, 10 } })
	wallX(-50, -25, 25, { { 0, 18 } })
	wallX(-50, 25, 85, { { 55, 10 } })

	-- East block: D | A | Control
	wallZ(-25, 50, 100, { { 75, 6 } })
	wallZ(25, 50, 100, { { 75, 6 } })
	wallX(50, -85, -25, { { -55, 10 } })
	wallX(50, -25, 25, { { 0, 18 } })
	wallX(50, 25, 70, { { 55, 10 }, { 65, 6 } })
	-- Window from the control room to the dark outside (sill + glass)
	block(walls, "WindowSill", Vector3.new(T, 3.5, 6), CFrame.new(50, 1.75, 65), C.Concrete, Enum.Material.Concrete)
	local window = block(walls, "Window", Vector3.new(0.3, 6.5, 6), CFrame.new(50, 6.75, 65), Color3.fromRGB(150, 170, 175), Enum.Material.Glass)
	window.Transparency = 0.55
	CollectionService:AddTag(window, "FZ_Window")

	-- Halls
	wallZ(-50, -50, 50, { { 0, 18 } })
	wallZ(50, -50, 50, { { 0, 18 } })

	-- Corridors to the core (18 wide = the core openings). The four pockets between
	-- corridors, halls and the core ring are closed off by these walls.
	wallZ(-9, -50, -20)
	wallZ(9, -50, -20)
	wallZ(-9, 20, 50)
	wallZ(9, 20, 50)
	wallX(-9, -50, -20)
	wallX(9, -50, -20)
	wallX(-9, 20, 50)
	wallX(9, 20, 50)

	-- Core: 16-sided ring, radius 22, openings N/E/S/W
	local core = folder("Core")
	local segments = 16
	local radius = 22
	for i = 0, segments - 1 do
		local angle = (i + 0.5) / segments * math.pi * 2
		local onAxis = (i % 4 == 0) or (i % 4 == 3) -- the two segments around each axis
		local glass = i == 2 or i == 10 -- observation glass into the dark gaps behind the core
		local mid = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local length = 2 * radius * math.tan(math.pi / segments) + 0.4
		if onAxis then
			-- opening (17.5 studs over two segments) with a lintel above
			local y = DOOR_H + (H - DOOR_H) / 2
			block(core, "CoreLintel", Vector3.new(length, H - DOOR_H, T), CFrame.lookAt(mid + Vector3.new(0, y, 0), Vector3.new(0, y, 0)), C.SteelDark, Enum.Material.Metal)
		else
			local segment = block(core, "CoreWall", Vector3.new(length, H, T), CFrame.lookAt(mid + Vector3.new(0, H / 2, 0), Vector3.new(0, H / 2, 0)), C.SteelDark, Enum.Material.Metal)
			if glass then
				segment.Material = Enum.Material.Glass
				segment.Color = Color3.fromRGB(120, 140, 145)
				segment.Transparency = 0.6
				CollectionService:AddTag(segment, "FZ_Window")
			end
		end
	end
	-- The core machine
	local column = block(core, "CoreColumn", Vector3.new(H, 10, 10), CFrame.new(0, H / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Steel, Enum.Material.Metal)
	column.Shape = Enum.PartType.Cylinder
	local ringA = block(core, "CoreRing", Vector3.new(1, 18, 18), CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), C.SteelDark, Enum.Material.Metal)
	ringA.Shape = Enum.PartType.Cylinder
	local glow = block(core, "CoreGlow", Vector3.new(0.4, 11, 11), CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Emergency, Enum.Material.Neon)
	glow.Shape = Enum.PartType.Cylinder
	glow.CanCollide = false
	tag(glow, "FZ_SectorLight", { Sector = "CORE", OnColor = Color3.fromRGB(150, 210, 255) })
	local coreLight = Instance.new("PointLight")
	coreLight.Range = 30
	coreLight.Brightness = 1.4
	coreLight.Color = C.Emergency
	coreLight.Parent = glow

	local coreConsole = block(core, "CoreConsole", Vector3.new(5, 3.6, 2.4), CFrame.new(0, 1.8, 11), C.SteelDark, Enum.Material.Metal)
	local coreScreen = block(core, "CoreScreen", Vector3.new(4, 1.6, 0.1), CFrame.new(0, 4.4, 10.4) * CFrame.Angles(math.rad(-15), 0, 0), C.Screen, Enum.Material.Neon)
	coreScreen.CanCollide = false
	worldText(coreScreen, Enum.NormalId.Back, nil, "RELAIS 07 · DURCHLAUF 0007", nil, Color3.fromRGB(10, 40, 20))
	interactable(coreConsole, "c1_core", "INTERACT_ACTIVATE", "OBJECT_CORE", { HoldDuration = 3, MaxDistance = 8 })

	-- Core doors: locked until Relay Sector B is restored
	door(Vector3.new(0, 0, -21.6), true, 17.6, true, "B")
	door(Vector3.new(0, 0, 21.6), true, 17.6, true, "B")
	door(Vector3.new(-21.6, 0, 0), false, 17.6, true, "B")
	door(Vector3.new(21.6, 0, 0), false, 17.6, true, "B")

	-- Interior doors between sectors
	door(Vector3.new(-75, 0, -25), true, 6)
	door(Vector3.new(-75, 0, 25), true, 6)
	door(Vector3.new(75, 0, -25), true, 6)
	door(Vector3.new(75, 0, 25), true, 6)

	-- Signs at sector entrances
	-- (signs hang on the hall/corridor side of each lintel, facing the approaching player)
	sign(Vector3.new(-49.35, 12, -55), Vector3.new(1, 0, 0), "SIGN_SECTOR_C")
	sign(Vector3.new(-49.35, 12, 0), Vector3.new(1, 0, 0), "SIGN_SECTOR_B")
	sign(Vector3.new(-49.35, 12, 55), Vector3.new(1, 0, 0), "SIGN_SECTOR_E")
	sign(Vector3.new(49.35, 12, -55), Vector3.new(-1, 0, 0), "SIGN_SECTOR_D")
	sign(Vector3.new(49.35, 12, 0), Vector3.new(-1, 0, 0), "SIGN_SECTOR_A")
	sign(Vector3.new(75, 12, 70.65), Vector3.new(0, 0, 1), "SIGN_CONTROL")
	sign(Vector3.new(0, 12, -22.3), Vector3.new(0, 0, -1), "SIGN_CORE")
	sign(Vector3.new(0, 12, 22.3), Vector3.new(0, 0, 1), "SIGN_CORE")
end

local function furnish()
	-- Control room (start area, x 50..100, z 25..70)
	local cctv = console(CFrame.new(62, 0, 66) * CFrame.Angles(0, math.rad(180), 0))
	CollectionService:AddTag(cctv[2], "FZ_CctvScreen") -- the "future" camera feed
	CollectionService:AddTag(cctv[3], "FZ_CctvText") -- live creature location (cameras powered)

	-- Emergency power panel: the generator only carries two of three systems.
	block(props, "PowerPanel", Vector3.new(0.6, 6, 12), CFrame.new(50.8, 4.5, 38), C.SteelDark, Enum.Material.Metal)
	worldText(block(props, "PowerTitle", Vector3.new(10, 1, 0.1), CFrame.new(51.15, 8.1, 38) * CFrame.Angles(0, math.rad(90), 0), C.Plastic, Enum.Material.SmoothPlastic), Enum.NormalId.Back, "SYS_PANEL")
	for index, system in { "cameras", "halls", "vents" } do
		local z = 34 + (index - 1) * 4
		local lever = block(props, "Lever_" .. system, Vector3.new(0.8, 2.2, 0.8), CFrame.new(51.5, 4.4, z), C.Plastic, Enum.Material.Metal)
		interactable(lever, "c1_power", "INTERACT_SWITCH", "SYS_" .. string.upper(system), { System = system, MaxDistance = 8 })
		local lamp = block(props, "LeverLamp_" .. system, Vector3.new(0.3, 0.5, 0.5), CFrame.new(51.25, 6.4, z), C.ConcreteDark, Enum.Material.Neon)
		lamp:SetAttribute("LeverLamp", system)
		CollectionService:AddTag(lamp, "FZ_LeverLamp")
		local label = block(props, "LeverLabel_" .. system, Vector3.new(0.1, 0.8, 3.4), CFrame.new(51.2, 2.6, z) * CFrame.Angles(0, math.rad(90), 0), C.Plastic, Enum.Material.SmoothPlastic)
		label.Size = Vector3.new(3.4, 0.8, 0.1)
		worldText(label, Enum.NormalId.Back, "SYS_" .. string.upper(system))
	end
	console(CFrame.new(88, 0, 66) * CFrame.Angles(0, math.rad(180), 0))
	console(CFrame.new(96, 0, 40) * CFrame.Angles(0, math.rad(90), 0))
	local terminal = block(props, "ControlTerminal", Vector3.new(4, 3.6, 2.4), CFrame.new(75, 1.8, 38), C.SteelDark, Enum.Material.Metal)
	local screen = block(props, "TerminalScreen", Vector3.new(3.4, 1.5, 0.1), CFrame.new(75, 4.3, 37.2) * CFrame.Angles(math.rad(-15), 0, 0), C.Screen, Enum.Material.Neon)
	screen.CanCollide = false
	worldText(screen, Enum.NormalId.Front, nil, "KERN: OFFLINE  0/3", nil, Color3.fromRGB(10, 40, 20))
	interactable(terminal, "c1_terminal", "INTERACT_ACTIVATE", "OBJECT_CORE", { MaxDistance = 8 })
	desk(CFrame.new(62, 0, 45))
	cabinet(CFrame.new(98, 0, 30))
	for z = 35, 60, 12 do
		ceilingLight(Vector3.new(66, 0, z), "CONTROL", nil, z == 35, true)
		ceilingLight(Vector3.new(84, 0, z), "CONTROL")
	end
	checkpoint("C1_CONTROL", CFrame.new(75, 0.5, 52))

	-- Sector A: administration
	for x = 58, 92, 11 do
		desk(CFrame.new(x, 0, -10))
		desk(CFrame.new(x, 0, 10))
	end
	shelf(CFrame.new(99, 0, -14) * CFrame.Angles(0, math.rad(90), 0))
	cabinet(CFrame.new(98, 0, 18))
	local breaker = block(props, "BreakerA", Vector3.new(3, 4, 0.8), CFrame.new(99.2, 5, 4) * CFrame.Angles(0, math.rad(-90), 0), C.Steel:Lerp(C.Emergency, 0.25), Enum.Material.Metal)
	interactable(breaker, "c1_breaker_a", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { MaxDistance = 8, Sector = "A" })
	breaker:SetAttribute("Armed", false)
	for x = 60, 90, 15 do
		ceilingLight(Vector3.new(x, 0, -12), "A")
		ceilingLight(Vector3.new(x, 0, 12), "A")
	end
	emergencyLight(Vector3.new(99, 11, -20), "A")
	fuseSpot(CFrame.new(91, 3.45, 10), "A")
	fuseSpot(CFrame.new(58, 3.45, -10), "A")

	-- Sector D: quarters
	for z = -78, -38, 13 do
		bunk(CFrame.new(60, 0, z))
		bunk(CFrame.new(93, 0, z))
	end
	for z = -80, -60, 3 do
		locker(CFrame.new(75 + (z % 2), 0, z) * CFrame.Angles(0, math.rad(90), 0))
	end
	ceilingLight(Vector3.new(66, 0, -70), "D", Color3.fromRGB(255, 214, 170))
	ceilingLight(Vector3.new(84, 0, -45), "D", Color3.fromRGB(255, 214, 170))
	breakerBox(CFrame.new(99.2, 5, -30) * CFrame.Angles(0, math.rad(-90), 0), "D", "breaker")
	-- Break room corner: coffee still warm, calendar on November 2009 (document)
	local table_ = block(props, "CoffeeTable", Vector3.new(4, 3, 3), CFrame.new(90, 1.5, -30), C.Wood, Enum.Material.Wood)
	local mug = block(props, "Mug", Vector3.new(0.5, 0.6, 0.5), table_.CFrame * CFrame.new(0.8, 1.8, 0), C.Plastic, Enum.Material.SmoothPlastic)
	mug.Shape = Enum.PartType.Cylinder
	mug.CFrame = table_.CFrame * CFrame.new(0.8, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90))
	local calendar = block(props, "Calendar", Vector3.new(2, 2.6, 0.1), CFrame.new(99.4, 6, -36) * CFrame.Angles(0, math.rad(-90), 0), C.Paper, Enum.Material.SmoothPlastic)
	worldText(calendar, Enum.NormalId.Front, nil, "NOV 2009\n14", nil, Color3.fromRGB(140, 30, 24))
	interactable(calendar, "lore", "INTERACT_READ", "OBJECT_CALENDAR", { MaxDistance = 7, LogId = "calendar_2009" })
	fuseSpot(CFrame.new(93, 5.8, -65), "D")
	fuseSpot(CFrame.new(60, 2.2, -39), "D")

	-- Sector C: research / archive
	for z = -80, -35, 11 do
		shelf(CFrame.new(-90, 0, z) * CFrame.Angles(0, math.rad(90), 0))
		shelf(CFrame.new(-74, 0, z) * CFrame.Angles(0, math.rad(90), 0))
	end
	desk(CFrame.new(-60, 0, -40))
	ceilingLight(Vector3.new(-82, 0, -70), "C", nil, true)
	ceilingLight(Vector3.new(-62, 0, -45), "C")
	breakerBox(CFrame.new(-99.2, 5, -45) * CFrame.Angles(0, math.rad(90), 0), "C", "breaker")
	fuseSpot(CFrame.new(-60, 3.45, -40), "C")
	fuseSpot(CFrame.new(-82, 0.4, -82), "C")

	-- Sector B: laboratories + Relay panel (starts without power)
	for z = -15, 15, 10 do
		labTable(CFrame.new(-86, 0, z))
		labTable(CFrame.new(-68, 0, z))
	end
	local relay = block(props, "RelayPanelB", Vector3.new(0.8, 7, 6), CFrame.new(-99.2, 4.5, 0), C.Steel, Enum.Material.Metal)
	local relayLamp = block(props, "RelayLampB", Vector3.new(0.3, 0.8, 4), CFrame.new(-98.7, 8.6, 0), C.Emergency, Enum.Material.Neon)
	relayLamp.CanCollide = false
	tag(relayLamp, "FZ_SectorLight", { Sector = "B", OnColor = C.Screen })
	interactable(relay, "c1_relay_b", "INTERACT_INSERT", "OBJECT_RELAY_B", { HoldDuration = 4, MaxDistance = 8 })
	for z = -15, 15, 15 do
		ceilingLight(Vector3.new(-78, 0, z), "B")
	end
	emergencyLight(Vector3.new(-51.5, 9, 8), "B")

	-- Sector E: engineering
	local gen = generator(CFrame.new(-80, 0, 70))
	local gen2 = generator(CFrame.new(-80, 0, 45))
	gen:SetAttribute("SoundLoop", "generator_loop")
	CollectionService:AddTag(gen, "FZ_AmbientSource")
	-- Generators are survival objectives (restart them); chapter 1 ignores them.
	for index, g in { gen, gen2 } do
		interactable(g, "generator", "INTERACT_RESTART", "OBJECT_GENERATOR", { HoldDuration = 3, MaxDistance = 9, GeneratorId = index })
	end
	pipeRun(Vector3.new(-98, 12, 30), Vector3.new(-98, 12, 84))
	pipeRun(Vector3.new(-60, 12.5, 30), Vector3.new(-60, 12.5, 84), 0.9)
	ceilingLight(Vector3.new(-70, 0, 40), "E", C.Sodium)
	ceilingLight(Vector3.new(-70, 0, 72), "E", C.Sodium)
	breakerBox(CFrame.new(-99.2, 5, 35) * CFrame.Angles(0, math.rad(90), 0), "E", "breaker")
	fuseSpot(CFrame.new(-66, 0.4, 82), "E")
	fuseSpot(CFrame.new(-95, 0.4, 56), "E")

	-- Halls and corridors: emergency lighting only (readable, tense)
	for x = -40, 40, 20 do
		emergencyLight(Vector3.new(x, 12, -59), "HALL")
		emergencyLight(Vector3.new(x, 12, 59), "HALL")
	end
	for x = -35, 35, 35 do
		ceilingLight(Vector3.new(x, 0, -55), "HALLS", nil, false, true)
		ceilingLight(Vector3.new(x, 0, 55), "HALLS", nil, false, true)
	end
	pipeRun(Vector3.new(-50, 13, -51), Vector3.new(50, 13, -51))
	pipeRun(Vector3.new(-50, 13, 51), Vector3.new(50, 13, 51))
	for _, p in { Vector3.new(0, 12, -36), Vector3.new(0, 12, 36), Vector3.new(-36, 12, 0), Vector3.new(36, 12, 0) } do
		emergencyLight(p + Vector3.new(if p.X == 0 then 8.3 else 0, 0, if p.X == 0 then 0 else 8.3), "HALL")
	end
	checkpoint("C1_CORE", CFrame.new(0, 0.5, 40))

	-- Vents (creature shortcuts, always announced by a rattle)
	vent(Vector3.new(99.3, 1.5, -40), Vector3.new(-1, 0, 0), "east")
	vent(Vector3.new(99.3, 1.5, 15), Vector3.new(-1, 0, 0), "east")
	vent(Vector3.new(-99.3, 1.5, -60), Vector3.new(1, 0, 0), "west")
	vent(Vector3.new(-99.3, 1.5, 70), Vector3.new(1, 0, 0), "west")
	vent(Vector3.new(-20, 1.5, -59.3), Vector3.new(0, 0, 1), "hall")
	vent(Vector3.new(20, 1.5, 59.3), Vector3.new(0, 0, -1), "hall")

	-- Patrol graph: one node per space
	for _, node in {
		{ Vector3.new(75, 0, -55), "D" }, { Vector3.new(75, 0, 0), "A" }, { Vector3.new(75, 0, 45), "CONTROL" },
		{ Vector3.new(-75, 0, -55), "C" }, { Vector3.new(-75, 0, 0), "B" }, { Vector3.new(-75, 0, 55), "E" },
		{ Vector3.new(-30, 0, -55), "HALL" }, { Vector3.new(30, 0, -55), "HALL" },
		{ Vector3.new(-30, 0, 55), "HALL" }, { Vector3.new(30, 0, 55), "HALL" },
		{ Vector3.new(0, 0, -36), "HALL" }, { Vector3.new(0, 0, 36), "HALL" },
		{ Vector3.new(-36, 0, 0), "HALL" }, { Vector3.new(36, 0, 0), "HALL" },
	} do
		patrol(node[1], node[2])
	end

	-- Supernatural photographs (EvidenceService decides what they show)
	for _, ph in {
		{ "photo_past_self", "past_self", CFrame.new(80, 3.2, -10) }, -- administration desk
		{ "photo_team_future", "team_future", CFrame.new(-60, 3.2, -41.2) }, -- research desk
		{ "photo_mate_dark", "mate_dark", CFrame.new(93, 2.05, -52) }, -- quarters, on a bunk
	} do
		local frame = block(props, "Photo", Vector3.new(1.2, 0.05, 0.9), ph[3] * CFrame.Angles(0, math.random() * 0.6 - 0.3, 0), C.Paper, Enum.Material.SmoothPlastic)
		frame.CanCollide = false
		interactable(frame, "photo", "INTERACT_LOOK", "OBJECT_PHOTO", { MaxDistance = 7, PhotoId = ph[1], Kind = ph[2] })
	end

	-- First-aid cabinets (medkits for reviving teammates)
	for _, cab in {
		{ CFrame.new(99.3, 5, 62) * CFrame.Angles(0, math.rad(-90), 0) }, -- control room: security station
		{ CFrame.new(-99.3, 5, 18) * CFrame.Angles(0, math.rad(90), 0) }, -- laboratories: medical corner
		{ CFrame.new(-99.3, 5, 78) * CFrame.Angles(0, math.rad(90), 0) }, -- engineering: supply depot
		{ CFrame.new(99.3, 5, -80) * CFrame.Angles(0, math.rad(-90), 0) }, -- quarters
	} do
		local cabinet = block(props, "FirstAid", Vector3.new(2.6, 3.2, 0.9), cab[1], Color3.fromRGB(226, 224, 216), Enum.Material.SmoothPlastic)
		local crossV = block(props, "Cross", Vector3.new(0.4, 1.4, 0.05), cabinet.CFrame * CFrame.new(0, 0.2, -0.47), Color3.fromRGB(190, 40, 34), Enum.Material.Neon)
		local crossH = block(props, "Cross", Vector3.new(1.4, 0.4, 0.05), cabinet.CFrame * CFrame.new(0, 0.2, -0.47), Color3.fromRGB(190, 40, 34), Enum.Material.Neon)
		crossV.CanCollide = false
		crossH.CanCollide = false
		interactable(cabinet, "medcabinet", "INTERACT_TAKE_MEDKIT", "OBJECT_MEDCABINET", { MaxDistance = 7 })
		CollectionService:AddTag(cabinet, "FZ_MedCabinet")
	end

	-- PA loudspeakers (the station sometimes speaks with a voice nobody recognises)
	for _, sp in {
		{ Vector3.new(0, 12.5, -59.2), Vector3.new(0, 0, 1) }, { Vector3.new(0, 12.5, 59.2), Vector3.new(0, 0, -1) },
		{ Vector3.new(-49.2, 12.5, 20), Vector3.new(1, 0, 0) }, { Vector3.new(99.2, 12.5, 50), Vector3.new(-1, 0, 0) },
		{ Vector3.new(-99.2, 12.5, -10), Vector3.new(1, 0, 0) },
	} do
		local speaker = block(props, "Speaker", Vector3.new(1.4, 1.4, 1.6), CFrame.lookAt(sp[1], sp[1] + sp[2]), C.SteelDark, Enum.Material.Metal)
		speaker.CanCollide = false
		CollectionService:AddTag(speaker, "FZ_Speaker")
	end

	-- Hidden finds (ghost logs): tape recorders with a note
	for _, find in {
		{ "log_okafor", CFrame.new(-62, 0.6, -80) },
		{ "log_venn", CFrame.new(-86, 3.6, -15) },
		{ "log_ehle", CFrame.new(-60, 0.6, 30) },
		{ "log_0006", CFrame.new(-8, 0.6, 8) },
	} do
		local recorder = block(props, "Recorder", Vector3.new(1.4, 0.6, 1), find[2], Color3.fromRGB(48, 44, 40), Enum.Material.SmoothPlastic)
		local reel = block(props, "Reel", Vector3.new(0.1, 0.5, 0.5), find[2] * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Plastic, Enum.Material.SmoothPlastic)
		reel.Shape = Enum.PartType.Cylinder
		reel.CanCollide = false
		local led = Instance.new("PointLight")
		led.Range = 3
		led.Brightness = 0.6
		led.Color = Color3.fromRGB(255, 120, 60)
		led.Parent = recorder
		interactable(recorder, "lore", "INTERACT_LISTEN", "OBJECT_RECORDER", { MaxDistance = 7, LogId = find[1] })
	end

	-- Item spots (bandages / syringes are placed at random spots per session)
	for _, cf in {
		CFrame.new(69, 3.45, -10), CFrame.new(80, 3.45, 10), CFrame.new(57.2, 2.2, -52), CFrame.new(-60, 3.45, -40.8),
		CFrame.new(-86, 3.4, 5), CFrame.new(-68, 3.4, -15), CFrame.new(-90, 0.4, 82), CFrame.new(62, 3.45, 45),
		CFrame.new(-30, 0.4, -58), CFrame.new(30, 0.4, 58), CFrame.new(4, 0.4, -16), CFrame.new(90, 3.2, -30),
	} do
		local spot = block(props, "ItemSpot", Vector3.new(1, 1, 1), cf, C.Concrete)
		spot.Transparency = 1
		spot.CanCollide = false
		spot.CanQuery = false
		CollectionService:AddTag(spot, "FZ_ItemSpot")
	end

	local spawn = block(props, "CreatureSpawn", Vector3.new(2, 1, 2), CFrame.new(-80, 3, -78), C.Concrete)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	CollectionService:AddTag(spawn, "FZ_CreatureSpawn")
end

---------------------------------------------------------------------------
-- Outside: terrain, road, fence, gatehouse, antenna, forest
---------------------------------------------------------------------------
local function tree(parent: Instance, position: Vector3, scale: number)
	local height = 26 * scale
	block(parent, "Trunk", Vector3.new(1.4 * scale, height, 1.4 * scale), CFrame.new(position + Vector3.new(0, height / 2, 0)), C.Bark, Enum.Material.Wood)
	for i, s in { 1, 0.75, 0.5 } do
		local layer = block(parent, "Needles", Vector3.new(1, 1, 1), CFrame.new(position + Vector3.new(0, height * (0.35 + i * 0.18), 0)), C.Pine, Enum.Material.Grass)
		layer.CanCollide = false
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(12 * s * scale, 10 * scale, 12 * s * scale)
		mesh.Parent = layer
	end
end

local function lampPost(parent: Instance, position: Vector3, facing: Vector3)
	local post = block(parent, "LampPost", Vector3.new(0.5, 14, 0.5), CFrame.new(position + Vector3.new(0, 7, 0)), C.SteelDark, Enum.Material.Metal)
	local head = block(parent, "LampHead", Vector3.new(2, 0.5, 1), CFrame.lookAt(post.Position + Vector3.new(0, 7, 0), post.Position + Vector3.new(0, 7, 0) + facing) * CFrame.new(0, 0, -1), C.Sodium, Enum.Material.Neon)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 110
	light.Range = 36
	light.Brightness = 2.4
	light.Color = C.Sodium
	light.Shadows = true
	light.Parent = head
	CollectionService:AddTag(head, "FZ_KeyLight")
end

local function buildOutside()
	local outside = folder("Outside")

	-- Terrain ground (cheap, looks natural). Building/road sit on top.
	workspace.Terrain:FillBlock(CFrame.new(0, -5.1, 80), Vector3.new(900, 10, 900), Enum.Material.Grass)
	workspace.Terrain:FillBlock(CFrame.new(-60, -1.2, 150), Vector3.new(60, 2, 40), Enum.Material.Mud)

	-- Yard and road (main entrance at x 75, z 70 -> gate at z 240)
	block(outside, "Yard", Vector3.new(120, 1, 60), CFrame.new(40, -0.45, 100), C.Asphalt, Enum.Material.Asphalt)
	block(outside, "Road", Vector3.new(16, 1, 140), CFrame.new(75, -0.45, 200), C.Asphalt, Enum.Material.Asphalt)
	block(outside, "RoadOut", Vector3.new(16, 1, 160), CFrame.new(75, -0.45, 350), C.Asphalt, Enum.Material.Asphalt)
	for z = 110, 230, 40 do
		lampPost(outside, Vector3.new(86, 0, z), Vector3.new(-1, 0, 0))
	end
	lampPost(outside, Vector3.new(40, 0, 82), Vector3.new(0, 0, 1))
	-- Parked service van (silhouette)
	block(outside, "Van", Vector3.new(7, 7, 15), CFrame.new(58, 3.6, 120) * CFrame.Angles(0, math.rad(8), 0), Color3.fromRGB(150, 150, 140), Enum.Material.Metal)

	-- Perimeter fence with gate gap
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = outside
	local function fenceLine(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		local count = math.max(1, math.floor(length / 12))
		for i = 0, count do
			local p = a:Lerp(b, i / count)
			block(fence, "Post", Vector3.new(0.4, 9, 0.4), CFrame.new(p + Vector3.new(0, 4.5, 0)), C.SteelDark, Enum.Material.Metal)
		end
		for _, y in { 0.6, 8.6 } do
			local rail = block(fence, "Rail", Vector3.new(0.25, 0.25, length), CFrame.lookAt((a + b) / 2 + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)), C.SteelDark, Enum.Material.Metal)
			rail.CanCollide = false
		end
		local mesh = block(fence, "Mesh", Vector3.new(0.1, 8, length), CFrame.lookAt((a + b) / 2 + Vector3.new(0, 4.6, 0), b + Vector3.new(0, 4.6, 0)), C.Steel, Enum.Material.DiamondPlate)
		mesh.Transparency = 0.75
	end
	fenceLine(Vector3.new(-130, 0, -110), Vector3.new(150, 0, -110))
	fenceLine(Vector3.new(150, 0, -110), Vector3.new(150, 0, 240))
	fenceLine(Vector3.new(150, 0, 240), Vector3.new(84, 0, 240))
	fenceLine(Vector3.new(66, 0, 240), Vector3.new(-130, 0, 240))
	fenceLine(Vector3.new(-130, 0, 240), Vector3.new(-130, 0, -110))

	-- Gate + gatehouse (opening sequence: fax, logbook code, maintenance note)
	block(outside, "GatePillarL", Vector3.new(2, 10, 2), CFrame.new(65, 5, 240), C.Concrete, Enum.Material.Concrete)
	block(outside, "GatePillarR", Vector3.new(2, 10, 2), CFrame.new(85, 5, 240), C.Concrete, Enum.Material.Concrete)
	local stationSign = block(outside, "StationSign", Vector3.new(14, 3, 0.3), CFrame.new(75, 8.5, 240.6), C.Plastic, Enum.Material.SmoothPlastic)
	worldText(stationSign, Enum.NormalId.Back, "SIGN_STATION")

	local gx, gz = 100, 232
	local gh = Instance.new("Model")
	gh.Name = "Gatehouse"
	gh.Parent = outside
	block(gh, "Floor", Vector3.new(14, 0.4, 12), CFrame.new(gx, 0.2, gz), C.Linoleum, Enum.Material.Plastic)
	block(gh, "Roof", Vector3.new(15, 0.6, 13), CFrame.new(gx, 9.3, gz), C.ConcreteDark, Enum.Material.Concrete)
	block(gh, "WallN", Vector3.new(14, 9, 0.6), CFrame.new(gx, 4.5, gz - 6), C.Concrete, Enum.Material.Concrete)
	block(gh, "WallE", Vector3.new(0.6, 9, 12), CFrame.new(gx + 7, 4.5, gz), C.Concrete, Enum.Material.Concrete)
	block(gh, "WallS", Vector3.new(14, 9, 0.6), CFrame.new(gx, 4.5, gz + 6), C.Concrete, Enum.Material.Concrete)
	block(gh, "WallW_A", Vector3.new(0.6, 9, 4), CFrame.new(gx - 7, 4.5, gz - 4), C.Concrete, Enum.Material.Concrete)
	block(gh, "WallW_B", Vector3.new(0.6, 9, 4), CFrame.new(gx - 7, 4.5, gz + 4), C.Concrete, Enum.Material.Concrete)
	block(gh, "WallW_Top", Vector3.new(0.6, 2, 4), CFrame.new(gx - 7, 8, gz), C.Concrete, Enum.Material.Concrete)
	local lamp = block(gh, "CeilingLamp", Vector3.new(3, 0.2, 0.8), CFrame.new(gx, 8.9, gz), Color3.fromRGB(255, 214, 160), Enum.Material.Neon)
	local lampLight = Instance.new("PointLight")
	lampLight.Range = 16
	lampLight.Brightness = 0.9
	lampLight.Color = Color3.fromRGB(255, 206, 150)
	lampLight.Shadows = true
	lampLight.Parent = lamp
	CollectionService:AddTag(lamp, "FZ_KeyLight")
	local deskTop = block(gh, "Desk", Vector3.new(2.6, 3, 7), CFrame.new(gx + 5, 1.9, gz), C.Wood, Enum.Material.Wood)
	local fax = block(gh, "Fax", Vector3.new(1.2, 0.6, 1.6), deskTop.CFrame * CFrame.new(0, 1.8, -1.6), C.Plastic, Enum.Material.SmoothPlastic)
	interactable(fax, "c1_fax", "INTERACT_READ", "OBJECT_FAX", { MaxDistance = 7 })
	local faxLed = Instance.new("PointLight")
	faxLed.Range = 3
	faxLed.Brightness = 1.5
	faxLed.Color = Color3.fromRGB(255, 90, 60)
	faxLed.Parent = fax
	local logbook = block(gh, "Logbook", Vector3.new(1, 0.1, 1.4), deskTop.CFrame * CFrame.new(0.1, 1.55, 1.8), C.Paper, Enum.Material.Fabric)
	worldText(logbook, Enum.NormalId.Top, nil, "02:14  VESPER-0214")
	local board = block(gh, "NoticeBoard", Vector3.new(4.5, 3.2, 0.2), CFrame.new(gx, 4.6, gz - 5.6), Color3.fromRGB(120, 96, 70), Enum.Material.Cardboard)
	local note = block(gh, "Note", Vector3.new(2.4, 1.9, 0.05), board.CFrame * CFrame.new(0.4, 0.2, 0.13), C.Paper, Enum.Material.SmoothPlastic)
	worldText(note, Enum.NormalId.Back, "NOTE_MAINTENANCE", nil, { code = "SIGNAL-017" })

	-- Antenna (extraction) south-west in the yard
	local antenna = Instance.new("Model")
	antenna.Name = "Antenna"
	antenna.Parent = outside
	local ax, az = -60, 150
	block(antenna, "Pad", Vector3.new(30, 1, 30), CFrame.new(ax, 0, az), C.ConcreteDark, Enum.Material.Concrete)
	local levels = 8
	local height = 110
	for i = 0, levels - 1 do
		local y0, y1 = i / levels * height, (i + 1) / levels * height
		local w0, w1 = 10 - i * 1.0, 10 - (i + 1) * 1.0
		for _, corner in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
			local a = Vector3.new(ax + corner[1] * w0, y0, az + corner[2] * w0)
			local b = Vector3.new(ax + corner[1] * w1, y1, az + corner[2] * w1)
			block(antenna, "Leg", Vector3.new(0.7, 0.7, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), C.Emergency:Lerp(C.SteelDark, 0.55), Enum.Material.Metal)
		end
		for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local a = Vector3.new(ax + side[1] * w0 + side[2] * w0, y0, az + side[2] * w0 - side[1] * w0)
			local b = Vector3.new(ax + side[1] * w1 - side[2] * w1, y1, az + side[2] * w1 + side[1] * w1)
			local brace = block(antenna, "Brace", Vector3.new(0.35, 0.35, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), C.SteelDark, Enum.Material.Metal)
			brace.CanCollide = false
		end
		if i % 2 == 1 then
			local beacon = block(antenna, "Beacon", Vector3.new(1, 1, 1), CFrame.new(ax + w1, y1, az + w1), C.Emergency, Enum.Material.Neon)
			beacon.CanCollide = false
			local beaconLight = Instance.new("PointLight")
			beaconLight.Range = 18
			beaconLight.Brightness = 2
			beaconLight.Color = C.Emergency
			beaconLight.Parent = beacon
			CollectionService:AddTag(beacon, "FZ_Beacon")
		end
	end
	local dish = block(antenna, "Dish", Vector3.new(1, 12, 12), CFrame.new(ax + 4, 40, az - 4) * CFrame.Angles(0, math.rad(40), math.rad(20)), C.Plastic, Enum.Material.Metal)
	dish.Shape = Enum.PartType.Cylinder
	local cabinetBox = block(antenna, "ExtractionCabinet", Vector3.new(3, 5, 2), CFrame.new(ax, 3, az + 12), C.Steel, Enum.Material.Metal)
	interactable(cabinetBox, "c1_antenna", "INTERACT_LEAVE", "OBJECT_ANTENNA", { HoldDuration = 2, MaxDistance = 8 })

	-- Forest ring outside the fence (deterministic)
	local forest = Instance.new("Folder")
	forest.Name = "Forest"
	forest.Parent = outside
	local placed = 0
	while placed < 170 do
		local x = rng:NextNumber(-360, 380)
		local z = rng:NextNumber(-330, 460)
		local insideCompound = x > -140 and x < 160 and z > -120 and z < 250
		local onRoad = math.abs(x - 75) < 16 and z > 240
		if not insideCompound and not onRoad then
			tree(forest, Vector3.new(x, 0, z), rng:NextNumber(0.8, 1.35))
			placed += 1
		end
	end

	-- Spawn (behind the menu camera), checkpoint at the gate, menu camera
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "FZ_Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(75, 0.5, 300)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = outside
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	checkpoint("C1_START", CFrame.new(75, 0.5, 252))
	local menuCamera = block(outside, "MenuCamera", Vector3.new(1, 1, 1), CFrame.lookAt(Vector3.new(58, 7, 286), Vector3.new(10, 26, 60)), C.Concrete)
	menuCamera.Transparency = 1
	menuCamera.CanCollide = false
	menuCamera.CanQuery = false
	CollectionService:AddTag(menuCamera, "FZ_MenuCamera")
end

local function buildLighting()
	Lighting.ClockTime = 0.4
	Lighting.Brightness = 0.7
	Lighting.Ambient = Color3.fromRGB(18, 21, 24)
	Lighting.OutdoorAmbient = Color3.fromRGB(38, 44, 52)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.36
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(112, 124, 134)
	atmosphere.Decay = Color3.fromRGB(46, 56, 66)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting
end

function Map.Build(): Model
	root = Instance.new("Model")
	root.Name = "FZ_RelayStation07"
	buildShell()
	furnish()
	buildOutside()
	buildLighting()
	root.Parent = workspace
	return root
end

return Map
