-- Staumauer 3 (Dam 3) - chapter 2 "The Wrong Voice" and the survival map "Floodgate".
--
--                    STAUSEE (lake, north)
--   ═══════════════ DAMMKRONE y=44 (crest) ═══════════════════════
--   [Messraum]─── Kontrollgalerie (inside the dam, y=0) ──┐  Schrägstollen ─► Schieberhaus (crest)
--               Antennenhof (crest, over the lake)         │
--   ─────────────────── Portal (x=0) ─────────────────────┘  Serpentinen-Rampe (dam face, east)
--   [Mannschaftstrakt: Kantine | Büro | Schlafsaal]      [Turbinenhalle | Schieberkammer | Leitstand]
--                         Talstraße (south) ─► Schranke (start)
--
-- Gameplay objects follow docs/MAP_CONTRACT.md. Chapter-2 objects use InteractIds "c2_*".

local CollectionService = game:GetService("CollectionService")

local MapKit = require(script.Parent.MapKit)
local MapDress = require(script.Parent.MapDress)
local Textures = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Textures"))
local C = MapKit.C

local Map = {}

local CREST = 44 -- crest walkway height
local LAKE = 38 -- water level of the reservoir

local function build()
	local kit = MapKit.new("FZ_Dam03", "Dam03", 303)
	local block, deco = kit.block, kit.deco
	local structure = kit.folder("Structure")
	local props = kit.folder("Props")
	local outside = kit.folder("Outside")
	local concrete = Color3.fromRGB(118, 116, 108)
	local concreteWet = Color3.fromRGB(84, 86, 84)

	---------------------------------------------------------------------------
	-- The dam: front shell (valley), back shell (lake), end caps, crest slab
	---------------------------------------------------------------------------
	-- front face with the gallery portal (x -4..4, height 9)
	block(structure, "DamFront", Vector3.new(146, CREST, 3), CFrame.new(-77, CREST / 2, -1.5), concreteWet, Enum.Material.Concrete)
	block(structure, "DamFront", Vector3.new(146, CREST, 3), CFrame.new(77, CREST / 2, -1.5), concreteWet, Enum.Material.Concrete)
	block(structure, "DamFrontPortalTop", Vector3.new(8, CREST - 9, 3), CFrame.new(0, 9 + (CREST - 9) / 2, -1.5), concreteWet, Enum.Material.Concrete)
	block(structure, "DamBack", Vector3.new(300, CREST, 3), CFrame.new(0, CREST / 2, -18.5), concreteWet, Enum.Material.Concrete)
	block(structure, "DamCapW", Vector3.new(4, CREST, 20), CFrame.new(-152, CREST / 2, -10), concreteWet, Enum.Material.Concrete)
	block(structure, "DamCapE", Vector3.new(4, CREST, 20), CFrame.new(152, CREST / 2, -10), concreteWet, Enum.Material.Concrete)
	-- crest slab, open above the inclined shaft (x 98..132, z -14..-8) so there is head room
	-- all the way up; the shaft housing rises through the crest there.
	local crestY = CREST - 1.5
	block(structure, "Crest", Vector3.new(248, 3, 20), CFrame.new(-26, crestY, -10), concrete, Enum.Material.Concrete)
	block(structure, "Crest", Vector3.new(52, 3, 6), CFrame.new(124, crestY, -17), concrete, Enum.Material.Concrete)
	block(structure, "Crest", Vector3.new(52, 3, 8), CFrame.new(124, crestY, -4), concrete, Enum.Material.Concrete)
	block(structure, "Crest", Vector3.new(18, 3, 6), CFrame.new(141, crestY, -11), concrete, Enum.Material.Concrete)
	-- buttresses on the valley face (rhythm + scale)
	for x = -140, 140, 20 do
		if math.abs(x) > 6 and not (x > 24 and x < 150) then
			block(structure, "Buttress", Vector3.new(4, CREST - 2, 6), CFrame.new(x, (CREST - 2) / 2, 3), concreteWet, Enum.Material.Concrete)
		end
	end
	-- streaks of damp concrete and a plaque
	for i = 1, 14 do
		local x = kit.rng:NextNumber(-140, 140)
		deco(structure, "Stain", Vector3.new(kit.rng:NextNumber(2, 6), kit.rng:NextNumber(12, 30), 0.1), CFrame.new(x, CREST - 18, 0.05), Color3.fromRGB(58, 64, 60), Enum.Material.Slate)
	end
	local plaque = deco(props, "DamPlaque", Vector3.new(14, 3, 0.3), CFrame.new(0, 13, 0.2), C.Plastic, Enum.Material.SmoothPlastic)
	kit.worldText(plaque, Enum.NormalId.Back, nil, "STAUMAUER 3  ·  1962")
	plaque.CFrame = CFrame.lookAt(Vector3.new(0, 13, 0.2), Vector3.new(0, 13, 10))

	-- crest parapets, lamp posts
	local function parapet(z: number, x0: number, x1: number)
		block(structure, "Parapet", Vector3.new(x1 - x0, 3.4, 1), CFrame.new((x0 + x1) / 2, CREST + 1.7, z), concrete, Enum.Material.Concrete)
	end
	parapet(-19.5, -150, -30)
	parapet(-19.5, 30, 150)
	parapet(-0.5, -150, 140)
	for x = -135, 135, 30 do
		local post = block(outside, "CrestLamp", Vector3.new(0.4, 9, 0.4), CFrame.new(x, CREST + 4.5, -1.5), C.SteelDark, Enum.Material.Metal)
		post.CanCollide = false
		kit.bulb(Vector3.new(x, CREST + 9, -2.5), C.Sodium, 26, 1.6, "CREST", true)
	end

	---------------------------------------------------------------------------
	-- Inspection gallery (inside the dam, y = 0)
	---------------------------------------------------------------------------
	local galleryWall = Color3.fromRGB(96, 98, 94)
	kit.slab("GalleryFloor", -130, -18, 12, -3, 0, 1, Color3.fromRGB(70, 72, 70))
	kit.wallZ(-14, -112, 12, nil, { h = 9, color = galleryWall })
	kit.wallZ(-8, -112, 12, { { 0, 8 } }, { h = 9, doorH = 9, color = galleryWall })
	block(structure, "GalleryCeiling", Vector3.new(124, 1, 6), CFrame.new(-50, 9.5, -11), Color3.fromRGB(56, 58, 58), Enum.Material.Concrete)
	-- portal corridor x -4..4, z -8..-3
	kit.wallX(-4, -8, -3, nil, { h = 9, color = galleryWall })
	kit.wallX(4, -8, -3, nil, { h = 9, color = galleryWall })
	block(structure, "PortalCeiling", Vector3.new(8, 1, 5), CFrame.new(0, 9.5, -5.5), Color3.fromRGB(56, 58, 58), Enum.Material.Concrete)
	kit.door(Vector3.new(0, 0, -1.5), true, 7, false, nil, { doorH = 9, prefix = "DG" }):SetAttribute("Gallery", "portal")
	-- measuring room (west end)
	kit.room(-130, -18, -112, -3, { h = 9, gaps = { e = { { -11, 6 } } }, floor = Color3.fromRGB(70, 72, 70), noFloor = true, wall = galleryWall })
	kit.lightGrid(-130, -112, -18, -3, "GALLERY", C.Fluorescent, 0, 9)
	kit.console(CFrame.new(-121, 0, -16) * CFrame.Angles(0, math.rad(180), 0))
	kit.shelf(CFrame.new(-128.5, 0, -10) * CFrame.Angles(0, math.rad(90), 0))
	kit.document(CFrame.new(-118, 3.25, -15) * CFrame.Angles(0, 0.4, 0), "c2_correction_3")
	kit.desk(CFrame.new(-118, 0, -15))
	-- gallery lights, pipes, drainage channel, water marks
	for x = -104, 8, 14 do
		kit.bulb(Vector3.new(x, 8.2, -11), C.Fluorescent, 16, 1, "GALLERY", x % 28 == 0)
	end
	kit.pipeRun(Vector3.new(-112, 7.6, -13.3), Vector3.new(12, 7.6, -13.3), 0.35)
	kit.pipeRun(Vector3.new(-112, 6.9, -13.3), Vector3.new(12, 6.9, -13.3), 0.25, Color3.fromRGB(120, 40, 30))
	deco(structure, "Drain", Vector3.new(124, 0.1, 0.8), CFrame.new(-50, 0.02, -8.8), Color3.fromRGB(30, 34, 36), Enum.Material.DiamondPlate)
	for x = -100, 0, 25 do
		deco(structure, "WaterMark", Vector3.new(16, 0.15, 0.05), CFrame.new(x, 3.2, -13.45), Color3.fromRGB(60, 70, 66), Enum.Material.Slate)
	end
	-- flood water (hidden; shown when the chapter-2 forecast comes true)
	for _, seg in { { -71, 82 }, { 12 - 15, 22 } } do
		local water = block(kit.folder("Flood"), "FloodWater", Vector3.new(seg[2], 4.2, 5.8), CFrame.new(seg[1], 2.1, -11), Color3.fromRGB(40, 70, 80), Enum.Material.Glass)
		water.Transparency = 1
		water.CanCollide = false
		water.CanQuery = false
		water.CastShadow = false
		CollectionService:AddTag(water, "FZ_FloodWater")
	end
	local floodRoom = block(kit.folder("Flood"), "FloodWater", Vector3.new(18, 4.2, 15), CFrame.new(-121, 2.1, -10.5), Color3.fromRGB(40, 70, 80), Enum.Material.Glass)
	floodRoom.Transparency = 1
	floodRoom.CanCollide = false
	floodRoom.CanQuery = false
	CollectionService:AddTag(floodRoom, "FZ_FloodWater")

	-- inclined shaft x 12 -> 132 (y 0 -> 44), z -14..-8
	local a, b = Vector3.new(12, 0, -11), Vector3.new(132, CREST, -11)
	local ramp = kit.ramp(a, b, 6, Color3.fromRGB(80, 80, 76))
	ramp.Name = "InclineFloor"
	local slope = CFrame.lookAt((a + b) / 2, b)
	local length = (b - a).Magnitude
	for _, side in { -3.3, 3.3 } do
		block(structure, "InclineWall", Vector3.new(0.8, 10, length + 2), slope * CFrame.new(side, 4.5, 0), galleryWall, Enum.Material.Concrete)
	end
	block(structure, "InclineCeiling", Vector3.new(7.4, 0.8, length + 2), slope * CFrame.new(0, 9.4, 0), Color3.fromRGB(56, 58, 58), Enum.Material.Concrete)
	for i = 1, 9 do
		local p = a:Lerp(b, i / 10)
		kit.bulb(p + Vector3.new(0, 7.6, 0), C.Fluorescent, 16, 0.9, "GALLERY", i % 3 == 0)
		deco(structure, "Step", Vector3.new(6, 0.12, 0.4), slope * CFrame.new(0, 0.07, -length / 2 + i * length / 10) , C.Hazard, Enum.Material.SmoothPlastic)
	end
	kit.door(Vector3.new(14, 0, -11), false, 5.6, false, nil, { doorH = 9, prefix = "DG" }):SetAttribute("Gallery", "incline")
	kit.recorder(CFrame.new(70, 22.6, -12.8), "log_kessler")

	---------------------------------------------------------------------------
	-- Crest buildings: valve house (top of the incline), antenna yard over the lake
	---------------------------------------------------------------------------
	-- valve house x 118..146, z -19..-1 on the crest (incline arrives inside)
	kit.room(118, -19, 146, -1, { y = CREST, h = 12, gaps = { w = { { -10, 6 } } }, noFloor = true, wall = Color3.fromRGB(132, 126, 112), roof = Color3.fromRGB(70, 60, 54) })
	kit.door(Vector3.new(118, CREST, -10), false, 6, false, "", { prefix = "DV" })
	kit.lightGrid(118, 146, -19, -1, "CREST", C.Fluorescent, CREST, 12)
	kit.console(CFrame.new(140, CREST, -5) * CFrame.Angles(0, math.rad(-90), 0))
	kit.wheel(CFrame.new(140, CREST, -15), "c2_spillway", "INTERACT_TURN", "OBJECT_SPILLWAY", { HoldDuration = 4 })
	kit.panel(CFrame.new(145.4, CREST + 5, -10) * CFrame.Angles(0, math.rad(-90), 0), "breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { Sector = "CREST" })
	kit.interactable(kit.block(props, "StationValve", Vector3.new(2, 3, 2), CFrame.new(122, CREST + 1.5, -16), C.Steel, Enum.Material.Metal), "dam_station_2", "INTERACT_ACTIVATE", "OBJECT_STATION", { MaxDistance = 8 })
	kit.firstAid(CFrame.new(118.6, CREST + 5, -16) * CFrame.Angles(0, math.rad(90), 0))
	kit.checkpoint("C2_CREST", CFrame.new(110, CREST + 0.5, -10))

	-- antenna yard: platform over the lake x -30..30, z -44..-20, fenced, gated
	block(structure, "YardPlatform", Vector3.new(60, 3, 24), CFrame.new(0, crestY, -32), concrete, Enum.Material.Concrete)
	for _, x in { -26, -9, 9, 26 } do
		block(structure, "YardPillar", Vector3.new(4, CREST, 4), CFrame.new(x, CREST / 2 - 1, -40), concreteWet, Enum.Material.Concrete)
	end
	kit.railing(Vector3.new(-30, CREST, -44), Vector3.new(30, CREST, -44))
	kit.railing(Vector3.new(-30, CREST, -44), Vector3.new(-30, CREST, -20))
	kit.railing(Vector3.new(30, CREST, -44), Vector3.new(30, CREST, -20))
	-- fence with the yard gate on the crest side (locked until the team chose whom to trust)
	kit.wallZ(-19.5, -30, 30, { { 0, 8 } }, { y = CREST, h = 9, doorH = 8, color = C.SteelDark, material = Enum.Material.DiamondPlate, t = 0.4 })
	local yardGate = kit.door(Vector3.new(0, CREST, -19.5), true, 7.6, true, "", { doorH = 8, prefix = "DY" })
	yardGate:SetAttribute("YardGate", true)
	local ax, az = 0, -34
	local antenna = Instance.new("Model")
	antenna.Name = "StormAntenna"
	antenna.Parent = outside
	for i = 0, 5 do
		local y0, y1 = CREST + i * 7, CREST + (i + 1) * 7
		local w0, w1 = 4 - i * 0.5, 4 - (i + 1) * 0.5
		for _, corner in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
			local p0 = Vector3.new(ax + corner[1] * w0, y0, az + corner[2] * w0)
			local p1 = Vector3.new(ax + corner[1] * w1, y1, az + corner[2] * w1)
			block(antenna, "Leg", Vector3.new(0.5, 0.5, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), C.Emergency:Lerp(C.SteelDark, 0.55), Enum.Material.Metal)
		end
	end
	local beacon = deco(antenna, "Beacon", Vector3.new(1, 1, 1), CFrame.new(ax, CREST + 43, az), C.Emergency, Enum.Material.Neon)
	local beaconLight = Instance.new("PointLight")
	beaconLight.Range = 24
	beaconLight.Brightness = 2
	beaconLight.Color = C.Emergency
	beaconLight.Parent = beacon
	CollectionService:AddTag(beacon, "FZ_Beacon")
	local uplink = block(props, "UplinkCabinet", Vector3.new(3, 5, 2), CFrame.new(ax + 8, CREST + 2.5, az), C.Steel, Enum.Material.Metal)
	kit.interactable(uplink, "c2_uplink", "INTERACT_ACTIVATE", "OBJECT_UPLINK", { HoldDuration = 2, MaxDistance = 8 })
	kit.floodLight(Vector3.new(-26, CREST + 8, -22), Vector3.new(0, CREST, -34), C.Fluorescent, 60)
	kit.floodLight(Vector3.new(26, CREST + 8, -22), Vector3.new(0, CREST, -34), C.Fluorescent, 60)
	kit.patrol(Vector3.new(0, CREST, -30), "ANTENNA")

	---------------------------------------------------------------------------
	-- Switchback ramp on the dam face (east): three legs to the crest
	---------------------------------------------------------------------------
	local legs = {
		{ Vector3.new(30, 0, 3), Vector3.new(140, 15, 3) },
		{ Vector3.new(140, 15, 9), Vector3.new(30, 30, 9) },
		{ Vector3.new(30, 30, 15), Vector3.new(140, CREST, 15) },
	}
	for i, leg in legs do
		local r = kit.ramp(leg[1], leg[2], 6, concrete)
		r.Name = "SwitchbackRamp" .. i
		-- outer and inner rails (the legs run side by side at different heights)
		kit.railing(leg[1] + Vector3.new(0, 0, 3), leg[2] + Vector3.new(0, 0, 3))
		if i > 1 then
			kit.railing(leg[1] - Vector3.new(0, 0, 3), leg[2] - Vector3.new(0, 0, 3))
		end
		-- supports
		for t = 0.15, 0.95, 0.2 do
			local p = leg[1]:Lerp(leg[2], t)
			if p.Y > 2 then
				block(structure, "RampSupport", Vector3.new(1.2, p.Y, 1.2), CFrame.new(p.X, p.Y / 2 - 0.5, p.Z + 2.2), concreteWet, Enum.Material.Concrete)
			end
		end
	end
	-- landings
	kit.slab("Landing1", 140, 0, 148, 12, 15, 1, concrete)
	kit.slab("Landing2", 22, 6, 30, 18, 30, 1, concrete)
	kit.slab("Landing3", 140, 0, 152, 18, CREST, 1, concrete)
	block(structure, "LandingPost", Vector3.new(2, 15, 2), CFrame.new(147, 7, 11), concreteWet, Enum.Material.Concrete)
	block(structure, "LandingPost", Vector3.new(2, 30, 2), CFrame.new(23, 15, 17), concreteWet, Enum.Material.Concrete)
	block(structure, "LandingPost", Vector3.new(2, CREST, 2), CFrame.new(151, CREST / 2, 17), concreteWet, Enum.Material.Concrete)
	kit.railing(Vector3.new(148, 15, 0), Vector3.new(148, 15, 12))
	kit.railing(Vector3.new(140, 15, 12), Vector3.new(148, 15, 12))
	kit.railing(Vector3.new(22, 30, 6), Vector3.new(30, 30, 6))
	kit.railing(Vector3.new(22, 30, 18), Vector3.new(30, 30, 18))
	kit.railing(Vector3.new(22, 30, 6), Vector3.new(22, 30, 18))
	kit.railing(Vector3.new(152, CREST, 0), Vector3.new(152, CREST, 18))
	kit.railing(Vector3.new(140, CREST, 18), Vector3.new(152, CREST, 18))
	for i, p in { Vector3.new(144, 15, 6), Vector3.new(26, 30, 12), Vector3.new(146, CREST, 9) } do
		local post = block(outside, "RampLamp", Vector3.new(0.3, 6, 0.3), CFrame.new(p + Vector3.new(0, 3, 0)), C.SteelDark, Enum.Material.Metal)
		post.CanCollide = false
		kit.bulb(p + Vector3.new(0, 6.2, 0), C.Sodium, 22, 1.4, "CREST", i == 1)
	end
	kit.patrol(Vector3.new(85, 7.5, 3), "RAMP")
	kit.patrol(Vector3.new(85, 22.5, 9), "RAMP")
	kit.patrol(Vector3.new(85, 37, 15), "RAMP")
	kit.patrol(Vector3.new(-80, CREST, -10), "CREST")
	kit.patrol(Vector3.new(60, CREST, -10), "CREST")
	kit.patrol(Vector3.new(-60, 0, -11), "GALLERY")
	kit.patrol(Vector3.new(-120, 0, -10), "GALLERY")
	kit.patrol(Vector3.new(72, 22, -11), "INCLINE")

	---------------------------------------------------------------------------
	-- Crew building (Mannschaftstrakt): canteen | office | dorm
	---------------------------------------------------------------------------
	local wallColor = Color3.fromRGB(150, 140, 120)
	kit.slab("CrewFloor", -110, 40, -50, 100, 0, 1, Color3.fromRGB(92, 84, 66), Enum.Material.Plastic)
	kit.slab("CrewRoof", -111, 39, -49, 101, kit.H + 1.2, 1.2, Color3.fromRGB(70, 60, 54))
	local wo = { color = wallColor }
	kit.wallZ(40, -110, -50, { { -95, 6 }, { -65, 6 } }, wo) -- north (dam side): canteen + office doors
	kit.wallZ(100, -110, -50, nil, wo)
	kit.wallX(-110, 40, 100, nil, wo)
	kit.wallX(-50, 40, 100, { { 55, 6 } }, wo) -- east: office entrance
	kit.wallX(-80, 40, 100, { { 55, 6 }, { 85, 6 } }, wo) -- canteen | office/dorm
	kit.wallZ(70, -80, -50, { { -65, 6 } }, wo) -- office | dorm
	local canteenDoorN = kit.door(Vector3.new(-95, 0, 40), true, 6, false, nil, { prefix = "DC" })
	local canteenDoorI = kit.door(Vector3.new(-80, 0, 55), false, 6, false, nil, { prefix = "DC" })
	local canteenDoorD = kit.door(Vector3.new(-80, 0, 85), false, 6, false, nil, { prefix = "DC" })
	for _, d in { canteenDoorN, canteenDoorI, canteenDoorD } do
		d:SetAttribute("Canteen", true)
	end
	kit.door(Vector3.new(-65, 0, 40), true, 6, false, nil, { prefix = "DC" })
	kit.door(Vector3.new(-50, 0, 55), false, 6, false, nil, { prefix = "DC" })
	kit.door(Vector3.new(-65, 0, 70), true, 6, false, nil, { prefix = "DC" })
	-- canteen
	for z = 52, 88, 12 do
		kit.table_(CFrame.new(-100, 0, z))
		kit.bench(CFrame.new(-100, 0, z - 2.6))
		kit.bench(CFrame.new(-100, 0, z + 2.6))
		kit.table_(CFrame.new(-88, 0, z))
		kit.bench(CFrame.new(-88, 0, z - 2.6))
		kit.bench(CFrame.new(-88, 0, z + 2.6))
	end
	block(props, "Counter", Vector3.new(26, 3.6, 2.6), CFrame.new(-95, 1.8, 96), Color3.fromRGB(170, 170, 166), Enum.Material.Metal)
	for x = -106, -84, 6 do
		block(props, "Pot", Vector3.new(1.6, 1.2, 1.6), CFrame.new(x, 4.2, 96), C.SteelDark, Enum.Material.Metal)
	end
	local coffee = block(props, "CoffeeMachine", Vector3.new(2, 2.4, 1.6), CFrame.new(-84, 4.8, 96), C.Emergency:Lerp(C.SteelDark, 0.5), Enum.Material.SmoothPlastic)
	kit.interactable(coffee, "lore", "INTERACT_LOOK", "OBJECT_COFFEE", { MaxDistance = 7, LogId = "c2_coffee" })
	kit.lightGrid(-110, -80, 40, 100, "CREW", C.Warm)
	kit.vent(Vector3.new(-109.3, 1.5, 70), Vector3.new(1, 0, 0), "crew")
	kit.patrol(Vector3.new(-95, 0, 70), "CANTEEN")
	-- office (dam keeper)
	kit.desk(CFrame.new(-60, 0, 48))
	kit.deskLamp(CFrame.new(-62, 3.15, 47.5))
	kit.document(CFrame.new(-58.5, 3.2, 48) * CFrame.Angles(0, 0.3, 0), "c2_keeper_log")
	kit.document(CFrame.new(-74, 0.1, 66) * CFrame.Angles(0, -0.6, 0), "c2_correction_1")
	kit.shelf(CFrame.new(-51, 0, 62) * CFrame.Angles(0, math.rad(-90), 0))
	kit.cabinet(CFrame.new(-77, 0, 44))
	local override = kit.panel(CFrame.new(-79.4, 5, 62) * CFrame.Angles(0, math.rad(90), 0), "c2_override", "INTERACT_HOLD_OVERRIDE", "OBJECT_DOOR_OVERRIDE", { HoldDuration = 2 })
	override.Name = "CanteenOverride"
	kit.panel(CFrame.new(-50.6, 5, 64) * CFrame.Angles(0, math.rad(-90), 0), "breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { Sector = "CREW" })
	kit.lightGrid(-80, -50, 40, 70, "CREW", C.Warm)
	kit.patrol(Vector3.new(-65, 0, 55), "OFFICE")
	-- dorm
	for x = -74, -56, 9 do
		kit.bunk(CFrame.new(x, 0, 90))
	end
	for z = 74, 82, 2.5 do
		kit.locker(CFrame.new(-52, 0, z) * CFrame.Angles(0, math.rad(-90), 0))
	end
	kit.recorder(CFrame.new(-57, 2.2, 85), "c2_dorm_tape")
	kit.lightGrid(-80, -50, 70, 100, "CREW", C.Warm)
	kit.firstAid(CFrame.new(-50.6, 5, 92) * CFrame.Angles(0, math.rad(-90), 0))
	kit.patrol(Vector3.new(-65, 0, 85), "DORM")
	kit.vent(Vector3.new(-50.7, 1.5, 78), Vector3.new(-1, 0, 0), "crew")
	-- facade: lit windows, a porch light over each door
	for _, x in { -103, -87, -73, -57 } do
		local pane = deco(structure, "Window", Vector3.new(5, 2.2, 0.15), CFrame.new(x, 9, 39.4), Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
		pane.Transparency = 0.25
	end
	for _, p in { Vector3.new(-95, 11, 38.5), Vector3.new(-65, 11, 38.5), Vector3.new(-48.5, 11, 55) } do
		kit.bulb(p, C.Warm, 18, 1.2, nil, true)
	end
	kit.sign(Vector3.new(-80, 12, 39.3), Vector3.new(0, 0, -1), "SIGN_CREW")

	---------------------------------------------------------------------------
	-- Powerhouse (Turbinenhalle): hall | valve room | control booth
	---------------------------------------------------------------------------
	local ph = { color = Color3.fromRGB(128, 120, 110), h = 18 }
	kit.slab("PowerFloor", 40, 30, 130, 90, 0, 1, Color3.fromRGB(80, 84, 80))
	kit.slab("PowerRoof", 39, 29, 131, 91, 19.2, 1.2, Color3.fromRGB(60, 62, 64))
	kit.wallZ(30, 40, 130, { { 60, 8 } }, ph)
	kit.wallZ(90, 40, 130, { { 75, 10 } }, ph)
	kit.wallX(40, 30, 90, nil, ph)
	kit.wallX(130, 30, 90, nil, ph)
	kit.wallX(110, 30, 90, { { 45, 6 }, { 75, 6 } }, ph)
	kit.wallZ(60, 110, 130, nil, ph)
	kit.door(Vector3.new(60, 0, 30), true, 8, false, nil, { prefix = "DP" })
	kit.door(Vector3.new(75, 0, 90), true, 10, false, nil, { prefix = "DP" })
	kit.door(Vector3.new(110, 0, 45), false, 6, false, nil, { prefix = "DP" })
	kit.door(Vector3.new(110, 0, 75), false, 6, false, nil, { prefix = "DP" })
	-- turbines
	for i, x in { 60, 90 } do
		local gen = kit.generator(CFrame.new(x, 0, 60), i)
		gen.Size = Vector3.new(10, 7, 7)
		gen.Position = Vector3.new(x, 3.5, 60)
		local housing = block(props, "TurbineHousing", Vector3.new(12, 9, 12), CFrame.new(x, 4.5, 60) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 96, 104), Enum.Material.Metal)
		housing.Shape = Enum.PartType.Cylinder
		housing.Size = Vector3.new(7, 12, 12)
		housing.CFrame = CFrame.new(x, 3.5, 70) * CFrame.Angles(0, 0, math.rad(90))
		deco(props, "TurbineRing", Vector3.new(14, 0.4, 14), CFrame.new(x, 0.1, 66), C.Hazard, Enum.Material.SmoothPlastic)
	end
	kit.pipeRun(Vector3.new(60, 16, 31), Vector3.new(60, 8, 58), 1.6, Color3.fromRGB(60, 80, 86))
	kit.pipeRun(Vector3.new(90, 16, 31), Vector3.new(90, 8, 58), 1.6, Color3.fromRGB(60, 80, 86))
	-- gantry crane
	block(props, "CraneBeam", Vector3.new(70, 1.4, 2), CFrame.new(75, 16.5, 45), C.Hazard, Enum.Material.Metal)
	block(props, "CraneBeam", Vector3.new(70, 1.4, 2), CFrame.new(75, 16.5, 75), C.Hazard, Enum.Material.Metal)
	block(props, "CraneBridge", Vector3.new(2, 1.4, 30), CFrame.new(70, 15.5, 60), C.Hazard:Lerp(C.SteelDark, 0.3), Enum.Material.Metal)
	kit.lightGrid(40, 110, 30, 90, "POWER", C.Fluorescent, 0, 18)
	kit.panel(CFrame.new(40.6, 5, 80) * CFrame.Angles(0, math.rad(90), 0), "breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { Sector = "POWER" })
	kit.patrol(Vector3.new(75, 0, 45), "TURBINE")
	kit.patrol(Vector3.new(75, 0, 80), "TURBINE")
	kit.vent(Vector3.new(40.7, 1.5, 50), Vector3.new(1, 0, 0), "power")
	-- valve room (forecast: close the bottom outlet)
	kit.wheel(CFrame.new(122, 0, 40), "c2_valve", "INTERACT_TURN", "OBJECT_VALVE", { HoldDuration = 3 })
	kit.pipeRun(Vector3.new(112, 2, 34), Vector3.new(128, 2, 34), 1.1, Color3.fromRGB(90, 50, 40))
	kit.lightGrid(110, 130, 30, 60, "POWER", C.Fluorescent, 0, 18)
	kit.patrol(Vector3.new(120, 0, 45), "VALVE")
	kit.vent(Vector3.new(129.3, 1.5, 52), Vector3.new(-1, 0, 0), "power")
	-- control booth
	kit.console(CFrame.new(120, 0, 85))
	kit.document(CFrame.new(116, 3.25, 66) * CFrame.Angles(0, -0.2, 0), "c2_correction_2")
	kit.desk(CFrame.new(116, 0, 66))
	local damRelay = kit.panel(CFrame.new(129.4, 5, 64) * CFrame.Angles(0, math.rad(-90), 0), "dam_relay", "INTERACT_INSERT", "OBJECT_DAM_RELAY", { HoldDuration = 3 }, C.Steel)
	damRelay.Name = "DamRelay"
	kit.interactable(block(props, "StationBooth", Vector3.new(2, 3, 2), CFrame.new(127, 1.5, 70), C.Steel, Enum.Material.Metal), "dam_station_1", "INTERACT_ACTIVATE", "OBJECT_STATION", { MaxDistance = 8 })
	kit.lightGrid(110, 130, 60, 90, "POWER", C.Fluorescent, 0, 18)
	kit.firstAid(CFrame.new(129.4, 5, 80) * CFrame.Angles(0, math.rad(-90), 0))
	-- facade
	for x = 48, 124, 12 do
		local pane = deco(structure, "Window", Vector3.new(6, 3, 0.15), CFrame.new(x, 14, 90.6), if x % 24 == 0 then Color3.fromRGB(220, 236, 255) else Color3.fromRGB(30, 36, 42), if x % 24 == 0 then Enum.Material.Neon else Enum.Material.Glass)
		pane.Transparency = 0.2
	end
	kit.sign(Vector3.new(75, 15, 90.7), Vector3.new(0, 0, 1), "SIGN_POWERHOUSE")
	kit.floodLight(Vector3.new(42, 17, 92), Vector3.new(20, 0, 130), C.Sodium, 70)

	-- security lock keys (survival): turbine control booth + valve room
	kit.syncKey(CFrame.new(129.4, 4.5, 84) * CFrame.Angles(0, math.rad(-90), 0), 1)
	kit.syncKey(CFrame.new(129.4, 4.5, 34) * CFrame.Angles(0, math.rad(-90), 0), 2)

	-- station 3 + breaker in the gallery (survival)
	kit.interactable(block(props, "StationGallery", Vector3.new(2, 3, 2), CFrame.new(-60, 1.5, -13), C.Steel, Enum.Material.Metal), "dam_station_3", "INTERACT_ACTIVATE", "OBJECT_STATION", { MaxDistance = 8 })
	kit.panel(CFrame.new(-90, 4.5, -13.4), "breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { Sector = "GALLERY" })

	---------------------------------------------------------------------------
	-- Valley: road, barrier (start), van, floodlights, forest
	---------------------------------------------------------------------------
	kit.previewGround(Vector3.new(0, -0.62, 120), Vector3.new(700, 1, 280))
	local lakePreview = block(outside, "EditPreviewLake", Vector3.new(700, 1, 380), CFrame.new(0, LAKE - 0.5, -210), Color3.fromRGB(30, 46, 56), Enum.Material.Glass)
	lakePreview:SetAttribute("FZ_EditPreview", true)
	lakePreview.CanCollide = false
	block(outside, "Road", Vector3.new(14, 1, 270), CFrame.new(0, -0.45, 140), C.Asphalt, Enum.Material.Asphalt)
	block(outside, "Yard", Vector3.new(220, 1, 26), CFrame.new(0, -0.45, 20), C.Asphalt, Enum.Material.Asphalt)
	block(outside, "CrewPath", Vector3.new(10, 1, 70), CFrame.new(-40, -0.45, 60), C.Asphalt, Enum.Material.Asphalt)
	for z = 50, 260, 10 do
		deco(outside, "RoadMark", Vector3.new(0.4, 0.05, 4), CFrame.new(0, 0.06, z), Color3.fromRGB(210, 206, 190), Enum.Material.SmoothPlastic)
	end
	-- barrier + booth at the start
	block(outside, "BarrierBox", Vector3.new(1.4, 3.6, 1.4), CFrame.new(9, 1.8, 205), C.Hazard, Enum.Material.Metal)
	for i = 0, 5 do
		deco(outside, "BarrierArm", Vector3.new(0.5, 2.4, 0.5), CFrame.new(9, 3.6, 205) * CFrame.Angles(0, 0, math.rad(80)) * CFrame.new(0, 1.2 + i * 2.4, 0), if i % 2 == 0 then Color3.fromRGB(200, 40, 34) else Color3.fromRGB(230, 230, 225), Enum.Material.SmoothPlastic)
	end
	local van = block(outside, "Van", Vector3.new(7, 7, 15), CFrame.new(-12, 3.6, 222) * CFrame.Angles(0, math.rad(-6), 0), Color3.fromRGB(150, 150, 140), Enum.Material.Metal)
	kit.interactable(van, "dam_extract", "INTERACT_LEAVE", "OBJECT_VAN", { HoldDuration = 2, MaxDistance = 10 })
	kit.bulb(Vector3.new(9, 6, 205), C.Sodium, 24, 1.6, nil, true)
	kit.sign(Vector3.new(-9, 5, 200), Vector3.new(0, 0, 1), "SIGN_DAM_ACCESS", nil, Vector3.new(7, 3, 0.2))
	for z = 40, 190, 30 do
		local post = block(outside, "LampPost", Vector3.new(0.5, 12, 0.5), CFrame.new(9, 6, z), C.SteelDark, Enum.Material.Metal)
		post.CanCollide = false
		kit.bulb(Vector3.new(8, 12, z), C.Sodium, 30, 1.8, "YARD", z % 60 == 40)
	end
	kit.floodLight(Vector3.new(-30, 30, 4), Vector3.new(-30, 0, 40), C.Fluorescent, 60)
	kit.floodLight(Vector3.new(0, 12, 6), Vector3.new(0, 0, 30), C.Fluorescent, 40)
	kit.forest(140, -330, 330, 60, 380, { { -120, 30, 140, 110 }, { -20, 100, 20, 400 }, { -40, 180, 40, 260 }, { -75, 120, 0, 185 } }, 0.15)
	for _ = 1, 30 do
		local x, z = kit.rng:NextNumber(-250, 250), kit.rng:NextNumber(10, 260)
		if not (x > -120 and x < 140 and z < 110) and math.abs(x) > 14 then
			kit.rock(Vector3.new(x, 0, z), kit.rng:NextNumber(1.5, 5))
		end
	end
	kit.patrol(Vector3.new(0, 0, 25), "YARD")
	kit.patrol(Vector3.new(-30, 0, 120), "YARD")
	kit.patrol(Vector3.new(60, 0, 110), "YARD")
	kit.vent(Vector3.new(-3.3, 1.5, -6), Vector3.new(1, 0, 0), "dam")
	kit.vent(Vector3.new(125, CREST + 1.5, -18.3), Vector3.new(0, 0, 1), "dam")

	---------------------------------------------------------------------------
	-- Markers: checkpoints, spawn, creature, items, fuses, speakers, menu shots
	---------------------------------------------------------------------------
	kit.checkpoint("C2_START", CFrame.new(0, 0.5, 232))
	kit.checkpoint("C2_VALLEY", CFrame.new(-40, 0.5, 30))
	kit.checkpoint("C2_POWER", CFrame.new(75, 0.5, 100))
	kit.checkpoint("CP_SV_DAM", CFrame.new(75, 0.5, 80))
	kit.spawnLocation(CFrame.new(0, 0.5, 290))
	kit.creatureSpawn(CFrame.new(-121, 3, -10))
	for _, cf in {
		CFrame.new(-100, 3.45, 64), CFrame.new(-88, 3.45, 88), CFrame.new(-60, 3.45, 49), CFrame.new(-65, 2.2, 90),
		CFrame.new(58, 0.4, 42), CFrame.new(100, 0.4, 84), CFrame.new(124, 0.4, 54), CFrame.new(-118, 3.45, -14),
		CFrame.new(-30, 0.4, -12), CFrame.new(130, CREST + 0.4, -4), CFrame.new(-12, CREST + 0.4, -30), CFrame.new(144, 15.4, 4),
	} do
		kit.itemSpot(cf)
	end
	for _, f in {
		{ CFrame.new(-106, 0.4, 98), "CREW" }, { CFrame.new(-56, 3.45, 47), "CREW" },
		{ CFrame.new(46, 0.4, 86), "POWER" }, { CFrame.new(126, 3.45, 86), "POWER" },
		{ CFrame.new(-100, 0.4, -12), "GALLERY" }, { CFrame.new(-125, 0.4, -6), "GALLERY" },
		{ CFrame.new(136, CREST + 0.4, -17), "CREST" }, { CFrame.new(20, CREST + 0.4, -40), "CREST" },
	} do
		kit.fuseSpot(f[1], f[2])
	end
	for _, sp in {
		{ Vector3.new(-80, 12.5, 41), Vector3.new(0, 0, 1) }, { Vector3.new(75, 16, 31), Vector3.new(0, 0, 1) },
		{ Vector3.new(-50, 8, -13.2), Vector3.new(0, 0, 1) }, { Vector3.new(132, CREST + 10, -18.2), Vector3.new(0, 0, 1) },
	} do
		kit.speaker(sp[1], sp[2])
	end
	kit.menuCamera(1, Vector3.new(-40, 6, 150), Vector3.new(10, 26, 0), 8)
	kit.menuCamera(2, Vector3.new(-60, CREST + 7, -6), Vector3.new(0, CREST + 14, -34), 5)
	kit.menuCamera(3, Vector3.new(100, 8, 86), Vector3.new(60, 4, 58), 5)
	kit.menuCamera(4, Vector3.new(160, 30, 70), Vector3.new(60, 22, 0), 9)

	-- finishing pass
	local model = kit.root
	MapDress.Walls(model, { lower = Color3.fromRGB(78, 88, 84), rail = Color3.fromRGB(60, 64, 66), skirting = Color3.fromRGB(26, 26, 26) })
	MapDress.LightCones(model, { "FloodLight" }, 46)
	MapDress.Mist(model, Vector3.new(0, LAKE, -90), Vector3.new(300, 0, 90), Color3.fromRGB(150, 160, 175), 1.4) -- over the lake
	MapDress.Mist(model, Vector3.new(-10, 0, 140), Vector3.new(220, 0, 120))
	MapDress.Mist(model, Vector3.new(0, 0, 30), Vector3.new(260, 0, 40), nil, 0.7) -- spray at the foot of the dam
	MapDress.Steam(model, Vector3.new(60, 16, 31.6), Vector3.new(0, 0, 1))
	MapDress.Steam(model, Vector3.new(90, 16, 31.6), Vector3.new(0, 0, 1))
	MapDress.Steam(model, Vector3.new(0, 8.5, -6), Vector3.new(0, -0.2, 1), Color3.fromRGB(180, 190, 200)) -- breath of the gallery
	MapDress.Puddles(model, {
		{ -20, -10, 8, 3, CREST }, { 40, -6, 6, 4, CREST }, { -90, -12, 9, 3, CREST }, { 0, -30, 7, 5, CREST },
		{ 4, 60, 6, 4 }, { -6, 120, 8, 5 }, { 5, 175, 5, 3 }, { -40, 30, 9, 4 }, { 75, 98, 7, 4 }, { 95, 20, 6, 3 },
	})
	MapDress.Flicker(model, 0.15, 33)
	-- materials: tiled canteen, wet crest
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "CrewFloor" then
				d.Material = Enum.Material.CeramicTiles
				d.Color = Color3.fromRGB(150, 146, 134)
			elseif d.Name == "Crest" or d.Name == "YardPlatform" or d.Name == "Landing1" or d.Name == "Landing2" or d.Name == "Landing3" then
				d.Material = Enum.Material.Pavement
			end
		end
	end

	MapDress.Surfaces(model, "dam03", Textures)
	MapDress.Grime(model, 303, 0.45)
	return kit.finish()
end

function Map.BuildTerrain(model: Instance?)
	local terrain = workspace.Terrain
	-- valley floor and the lake basin
	terrain:FillBlock(CFrame.new(0, -5.1, 150), Vector3.new(900, 10, 320), Enum.Material.Grass)
	terrain:FillBlock(CFrame.new(0, -6, -230), Vector3.new(900, 12, 420), Enum.Material.Mud)
	terrain:FillBlock(CFrame.new(0, LAKE / 2, -230), Vector3.new(900, LAKE, 420), Enum.Material.Water)
	-- valley flanks (they hold the lake), with rock faces near the dam
	for _, side in { -1, 1 } do
		terrain:FillBlock(CFrame.new(side * 290, 26, -150), Vector3.new(270, 64, 560), Enum.Material.Grass)
		terrain:FillBlock(CFrame.new(side * 170, 30, -12), Vector3.new(36, 60, 50), Enum.Material.Rock)
		terrain:FillWedge(CFrame.new(side * 290, 16, 175) * CFrame.Angles(0, if side < 0 then math.rad(180) else 0, 0), Vector3.new(270, 44, 90), Enum.Material.Grass)
	end
	local patches = Random.new(17)
	for _ = 1, 20 do
		local x, z = patches:NextNumber(-380, 380), patches:NextNumber(110, 400)
		if math.abs(x) > 20 then
			terrain:FillBall(Vector3.new(x, -2.4, z), patches:NextNumber(10, 24), if patches:NextNumber() < 0.5 then Enum.Material.LeafyGrass else Enum.Material.Ground)
		end
	end
	terrain.WaterWaveSize = 0.4
	terrain.WaterWaveSpeed = 14
	terrain.WaterColor = Color3.fromRGB(26, 40, 46)
	terrain.WaterTransparency = 0.6
	MapDress.TerrainLook({
		Grass = Color3.fromRGB(56, 70, 50),
		LeafyGrass = Color3.fromRGB(50, 64, 44),
		Ground = Color3.fromRGB(70, 62, 52),
		Mud = Color3.fromRGB(46, 42, 36),
		Rock = Color3.fromRGB(86, 88, 86),
	})
	MapKit.ApplyClouds("storm")
	MapKit.RemovePreview(model)
end

function Map.ApplyLighting()
	MapKit.ApplyLighting("storm")
end

function Map.Build(): Model
	local model = build()
	Map.ApplyLighting()
	if not Map.SkipTerrain then
		Map.BuildTerrain(model)
	end
	return model
end

return Map
