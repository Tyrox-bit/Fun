-- Die Mine - chapter 4 "Frequency Zero": the Echo-Array lies deep in the old mine.
--
--                 [ ARRAY-KERN (core cavern) ]
--                        ║ Panzertür
--   Schleife ══╗   [ Trafokammer ]
--   (loop)     ║        ║  verschütteter Gang (open only in the 2009 layer)
--   [Förderkorb]══[ Kreuzung ]══[Pumpenkammer]
--                        ║  Hauptstollen
--   ─────────── Portal ──╨── Felswand ─────────────
--      [Fördermaschinenhaus]   Förderturm   Hof (start)
--
-- Time layers: parts tagged FZ_Layer (Layer = "now" | "2009") exist only in their layer;
-- chapter 4 switches the layer with every Array pulse.
-- InteractIds: c4_winch, c4_brake, c4_pump, c4_breaker, c4_override, c4_core.

local CollectionService = game:GetService("CollectionService")

local MapKit = require(script.Parent.MapKit)
local MapDress = require(script.Parent.MapDress)
local C = MapKit.C

local Map = {}

local TH = 12 -- tunnel wall height
local ROCK = Color3.fromRGB(76, 70, 64)
local TIMBER = Color3.fromRGB(96, 70, 46)

-- Every carved space (used to carve the mountain terrain at load time).
local CARVE = {
	{ -6, -122, 6, 2 }, -- main adit (incl. portal)
	{ -21, -141, 21, -119 }, -- junction
	{ 20, -136, 41, -124 }, { 39, -151, 81, -109 }, -- pump branch + room
	{ -41, -136, -20, -124 }, { -81, -151, -39, -109 }, -- lift branch + room
	{ -6, -221, 6, -139 }, -- collapsed passage
	{ -67, -251, -55, -149 }, { -67, -251, -5, -239 }, -- loop
	{ -21, -261, 21, -219 }, -- transformer room
	{ -46, -341, 46, -259 }, -- core cavern
}
Map.Carve = CARVE

local function build()
	local kit = MapKit.new("FZ_Mine", "Mine", 505)
	local block, deco = kit.block, kit.deco
	local structure = kit.folder("Structure")
	local props = kit.folder("Props")
	local outside = kit.folder("Outside")

	-- A tunnel/room with rock walls, rough ceiling and timber frames along its long axis.
	local function tunnel(x0: number, z0: number, x1: number, z1: number, gaps: any?, h: number?, sector: string?, lamps: boolean?)
		local height = h or TH
		kit.room(x0, z0, x1, z1, {
			h = height,
			gaps = gaps,
			floor = Color3.fromRGB(64, 58, 52),
			floorMaterial = Enum.Material.Ground,
			wall = ROCK,
			wallMaterial = Enum.Material.Rock,
			roof = C.RockDark,
		})
		local alongZ = (z1 - z0) >= (x1 - x0)
		local length = if alongZ then z1 - z0 else x1 - x0
		local width = if alongZ then x1 - x0 else z1 - z0
		if width <= 14 then
			for d = 4, length - 2, 8 do
				local cf = if alongZ then CFrame.new((x0 + x1) / 2, 0, z0 + d) else CFrame.new(x0 + d, 0, (z0 + z1) / 2) * CFrame.Angles(0, math.rad(90), 0)
				for _, side in { -1, 1 } do
					block(structure, "Timber", Vector3.new(0.9, height - 0.5, 0.9), cf * CFrame.new(side * (width / 2 - 0.9), (height - 0.5) / 2, 0), TIMBER, Enum.Material.Wood)
				end
				block(structure, "TimberCap", Vector3.new(width - 1, 0.9, 1), cf * CFrame.new(0, height - 0.9, 0), TIMBER, Enum.Material.Wood)
				if lamps ~= false and d % 16 == 4 then
					kit.bulb((cf * CFrame.new(0, height - 2, 0.9)).Position, C.Warm, 20, 1.1, sector or "MINE", d % 32 == 4)
				end
			end
		end
		-- rubble along the walls
		for _ = 1, math.floor(length / 10) do
			local t = kit.rng:NextNumber(0.05, 0.95)
			local side = if kit.rng:NextNumber() < 0.5 then -1 else 1
			local p = if alongZ then Vector3.new((x0 + x1) / 2 + side * (width / 2 - 1.5), 0, z0 + t * length) else Vector3.new(x0 + t * length, 0, (z0 + z1) / 2 + side * (width / 2 - 1.5))
			local stone = block(props, "Rubble", Vector3.new(1.6, 1, 1.4) * kit.rng:NextNumber(0.6, 1.5), CFrame.new(p + Vector3.new(0, 0.4, 0)) * CFrame.Angles(kit.rng:NextNumber(0, 1), kit.rng:NextNumber(0, 6), 0), C.Rock, Enum.Material.Slate)
			stone.CanCollide = false
		end
	end

	local function rails(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		for _, side in { -1.2, 1.2 } do
			deco(props, "Rail", Vector3.new(0.25, 0.25, length), CFrame.lookAt((a + b) / 2, b) * CFrame.new(side, 0.15, 0), C.SteelDark, Enum.Material.Metal)
		end
		for d = 0, length, 2.5 do
			deco(props, "Sleeper", Vector3.new(3.4, 0.15, 0.5), CFrame.lookAt(a, b) * CFrame.new(0, 0.05, -d), TIMBER, Enum.Material.Wood)
		end
	end

	-- layer parts (only solid/visible in their time layer)
	local function layerPart(part: BasePart, layer: string)
		part:SetAttribute("Layer", layer)
		part:SetAttribute("BaseTransparency", part.Transparency)
		part:SetAttribute("BaseCollide", part.CanCollide)
		CollectionService:AddTag(part, "FZ_Layer")
		if layer ~= "now" then
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
		end
		return part
	end

	---------------------------------------------------------------------------
	-- Main adit + portal
	---------------------------------------------------------------------------
	tunnel(-5, -120, 5, 0, { s = { { 0, 8 } }, n = { { 0, 8 } } })
	rails(Vector3.new(0, 0, -2), Vector3.new(0, 0, -118))
	local gate = kit.door(Vector3.new(0, 0, 0), true, 8, true, "", { color = C.SteelDark, material = Enum.Material.DiamondPlate, prefix = "DM" })
	gate.Name = "MineGate"
	gate:SetAttribute("MineGate", true)
	-- portal: timber frame + rock face around
	block(structure, "PortalBeam", Vector3.new(14, 1.6, 1.6), CFrame.new(0, 12.8, 1), TIMBER, Enum.Material.Wood)
	for _, x in { -6.5, 6.5 } do
		block(structure, "PortalPost", Vector3.new(1.6, 12, 1.6), CFrame.new(x, 6, 1), TIMBER, Enum.Material.Wood)
	end
	local sign = deco(structure, "PortalSign", Vector3.new(10, 2.2, 0.3), CFrame.new(0, 15, 1.4), TIMBER, Enum.Material.Wood)
	kit.worldText(sign, Enum.NormalId.Back, nil, "GLÜCK AUF  ·  STOLLEN 3", nil, Color3.fromRGB(230, 214, 180), Enum.Font.Garamond)
	sign.CFrame = CFrame.lookAt(Vector3.new(0, 15, 1.4), Vector3.new(0, 15, 10))
	local cliff = block(outside, "EditPreviewCliff", Vector3.new(300, 40, 4), CFrame.new(0, 20, -1), Color3.fromRGB(70, 66, 60), Enum.Material.Rock)
	cliff:SetAttribute("FZ_EditPreview", true)
	cliff.Transparency = 0.5
	cliff.CanCollide = false
	kit.bulb(Vector3.new(0, 11, 3), C.Sodium, 26, 1.6, nil, true)
	kit.patrol(Vector3.new(0, 0, -60), "ADIT")

	---------------------------------------------------------------------------
	-- Junction, pump branch, lift branch
	---------------------------------------------------------------------------
	tunnel(-20, -140, 20, -120, { s = { { 0, 8 } }, n = { { 0, 8 } }, e = { { -130, 8 } }, w = { { -130, 8 } } }, 14)
	kit.lightGrid(-20, 20, -140, -120, "MINE", C.Warm, 0, 14)
	kit.sign(Vector3.new(0, 11, -121), Vector3.new(0, 0, 1), "SIGN_JUNCTION")
	kit.patrol(Vector3.new(0, 0, -130), "JUNCTION")
	kit.checkpoint("C4_JUNCTION", CFrame.new(0, 0.5, -110))
	-- pump room
	tunnel(20, -135, 40, -125, { w = { { -130, 8 } }, e = { { -130, 8 } } })
	tunnel(40, -150, 80, -110, { w = { { -130, 8 } } }, 14)
	local pumpDoor = kit.door(Vector3.new(40, 0, -130), false, 8, false, nil, { prefix = "DM" })
	pumpDoor:SetAttribute("PumpDoor", true)
	local pump = block(props, "Pump", Vector3.new(6, 5, 4), CFrame.new(70, 2.5, -130), Color3.fromRGB(60, 80, 96), Enum.Material.Metal)
	pump:SetAttribute("SoundLoop", "water_rush_loop")
	CollectionService:AddTag(pump, "FZ_AmbientSource")
	kit.interactable(pump, "c4_pump", "INTERACT_RESTART", "OBJECT_PUMP", { HoldDuration = 3, MaxDistance = 9 })
	kit.pipeRun(Vector3.new(66, 3, -130), Vector3.new(44, 3, -148), 0.9, Color3.fromRGB(60, 80, 96))
	deco(props, "Sump", Vector3.new(14, 0.2, 10), CFrame.new(60, 0.1, -142), Color3.fromRGB(30, 50, 56), Enum.Material.Glass).Transparency = 0.3
	kit.lightGrid(40, 80, -150, -110, "PUMP", C.Fluorescent, 0, 14)
	kit.firstAid(CFrame.new(79.4, 5, -118) * CFrame.Angles(0, math.rad(-90), 0))
	kit.patrol(Vector3.new(60, 0, -130), "PUMP")
	kit.vent(Vector3.new(79.3, 1.5, -140), Vector3.new(-1, 0, 0), "deep")
	-- flood water (shown when the water forecast comes true)
	for _, w in { { Vector3.new(0, 1.2, -130), Vector3.new(38, 2.4, 18) }, { Vector3.new(0, 1.2, -100), Vector3.new(9, 2.4, 40) } } do
		local water = block(kit.folder("Flood"), "FloodWater", w[2], CFrame.new(w[1]), Color3.fromRGB(40, 64, 70), Enum.Material.Glass)
		water.Transparency = 1
		water.CanCollide = false
		water.CanQuery = false
		water.CastShadow = false
		CollectionService:AddTag(water, "FZ_FloodWater")
	end
	-- lift room (cage in a shaft, brake lever)
	tunnel(-40, -135, -20, -125, { w = { { -130, 8 } }, e = { { -130, 8 } } })
	tunnel(-80, -150, -40, -110, { e = { { -130, 8 } }, n = { { -61, 8 } } }, 14)
	local shaftWall = Color3.fromRGB(50, 48, 46)
	for _, w in { { Vector3.new(-78, 7, -122), Vector3.new(1, 14, 8) }, { Vector3.new(-70, 7, -122), Vector3.new(1, 14, 8) }, { Vector3.new(-74, 7, -118), Vector3.new(9, 14, 1) } } do
		block(structure, "ShaftWall", w[2], CFrame.new(w[1]), shaftWall, Enum.Material.DiamondPlate)
	end
	local cage = block(props, "LiftCage", Vector3.new(6, 8, 6), CFrame.new(-74, 9, -122), C.SteelDark, Enum.Material.DiamondPlate)
	cage.Transparency = 0.35
	cage.CanCollide = false
	cage:SetAttribute("LiftCage", true)
	deco(props, "LiftCable", Vector3.new(0.3, 40, 0.3), CFrame.new(-74, 33, -122), C.SteelDark, Enum.Material.Metal)
	local brake = block(props, "BrakeLever", Vector3.new(1, 4, 1), CFrame.new(-62, 2, -114) * CFrame.Angles(math.rad(20), 0, 0), C.Emergency:Lerp(C.SteelDark, 0.3), Enum.Material.Metal)
	block(props, "BrakeBase", Vector3.new(3, 1, 2), CFrame.new(-62, 0.5, -114), C.SteelDark, Enum.Material.Metal)
	kit.interactable(brake, "c4_brake", "INTERACT_PULL", "OBJECT_BRAKE", { HoldDuration = 2, MaxDistance = 8 })
	kit.lightGrid(-80, -40, -150, -110, "LIFT", C.Warm, 0, 14)
	kit.patrol(Vector3.new(-60, 0, -132), "LIFT")
	kit.vent(Vector3.new(-79.3, 1.5, -140), Vector3.new(1, 0, 0), "deep")
	local loopDoor = kit.door(Vector3.new(-61, 0, -150), true, 8, false, nil, { prefix = "DM" })
	loopDoor:SetAttribute("LoopDoor", true)

	---------------------------------------------------------------------------
	-- Collapsed passage (rubble in "now", open in "2009") and the long loop
	---------------------------------------------------------------------------
	tunnel(-5, -220, 5, -140, { s = { { 0, 8 } }, n = { { 0, 8 } } })
	rails(Vector3.new(0, 0, -142), Vector3.new(0, 0, -218))
	for i = 0, 5 do
		local rubble = block(structure, "CollapseRubble", Vector3.new(10, 12 - i * 0.6, 3), CFrame.new(0, (12 - i * 0.6) / 2, -176 - i * 3) * CFrame.Angles(kit.rng:NextNumber(-0.1, 0.1), 0, kit.rng:NextNumber(-0.08, 0.08)), C.Rock:Lerp(C.RockDark, i / 6), Enum.Material.Slate)
		layerPart(rubble, "now")
	end
	-- the 2009 layer shows the passage as it was: lit, a sign, a lamp - and a figure in a helmet
	local oldSign = deco(props, "OldSign", Vector3.new(6, 1.6, 0.2), CFrame.new(0, 9, -158), Color3.fromRGB(220, 200, 120), Enum.Material.SmoothPlastic)
	kit.worldText(oldSign, Enum.NormalId.Front, nil, "ARRAY  ↑  14.11.2009")
	oldSign.CFrame = CFrame.lookAt(Vector3.new(0, 9, -158), Vector3.new(0, 9, -150))
	layerPart(oldSign, "2009")
	for z = -150, -210, -20 do
		local lamp = deco(props, "Lamp2009", Vector3.new(0.6, 0.8, 0.6), CFrame.new(0, 10, z), C.Warm, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Parent = lamp
		layerPart(lamp, "2009")
	end
	kit.patrol(Vector3.new(0, 0, -160), "PASSAGE")
	kit.patrol(Vector3.new(0, 0, -205), "PASSAGE")
	-- loop: north from the lift room, then east to the transformer room
	tunnel(-66, -240, -56, -150, { s = { { -61, 8 } }, n = { { -61, 8 } } })
	tunnel(-66, -250, -20, -240, { e = { { -245, 8 } }, s = { { -61, 8 } } })
	kit.recorder(CFrame.new(-61, 0.6, -200), "c4_loop_tape")
	kit.patrol(Vector3.new(-61, 0, -195), "LOOP")
	kit.patrol(Vector3.new(-40, 0, -245), "LOOP")
	kit.vent(Vector3.new(-65.3, 1.5, -230), Vector3.new(1, 0, 0), "deep")

	---------------------------------------------------------------------------
	-- Transformer room + blast door
	---------------------------------------------------------------------------
	tunnel(-20, -260, 20, -220, { s = { { 0, 8 } }, w = { { -245, 8 } }, n = { { 0, 10 } } }, 14)
	kit.lightGrid(-20, 20, -260, -220, "TRANSFORMER", C.Fluorescent, 0, 14)
	for _, x in { -14, 14 } do
		local tr = block(props, "Transformer", Vector3.new(6, 8, 6), CFrame.new(x, 4, -238), Color3.fromRGB(70, 90, 80), Enum.Material.Metal)
		for k = 0, 3 do
			deco(props, "Fin", Vector3.new(6.4, 7, 0.2), tr.CFrame * CFrame.new(0, 0, -2.4 + k * 1.6), C.SteelDark, Enum.Material.Metal)
		end
		deco(props, "Insulator", Vector3.new(0.6, 2, 0.6), tr.CFrame * CFrame.new(0, 5, 0), Color3.fromRGB(150, 90, 60), Enum.Material.SmoothPlastic)
	end
	kit.panel(CFrame.new(19.4, 5, -230) * CFrame.Angles(0, math.rad(-90), 0), "c4_breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { HoldDuration = 3, Sector = "TRANSFORMER" })
	kit.panel(CFrame.new(6, 5, -259.4), "c4_override", "INTERACT_HOLD_OVERRIDE", "OBJECT_BLAST_OVERRIDE", { HoldDuration = 3 })
	local blast = kit.door(Vector3.new(0, 0, -260), true, 10, true, "", { color = Color3.fromRGB(80, 84, 76), material = Enum.Material.DiamondPlate, prefix = "DB" })
	blast.Name = "BlastDoor"
	blast:SetAttribute("BlastDoor", true)
	kit.emergencyLight(Vector3.new(-18.5, 11, -255), "TRANSFORMER")
	kit.emergencyLight(Vector3.new(18.5, 11, -225), "TRANSFORMER")
	kit.document(CFrame.new(-16, 0.1, -226) * CFrame.Angles(0, 0.7, 0), "c4_shift_log")
	kit.firstAid(CFrame.new(-19.4, 5, -230) * CFrame.Angles(0, math.rad(90), 0))
	kit.checkpoint("C4_TRANSFORMER", CFrame.new(0, 0.5, -226))
	kit.patrol(Vector3.new(0, 0, -240), "TRANSFORMER")

	---------------------------------------------------------------------------
	-- Core cavern: the Echo-Array
	---------------------------------------------------------------------------
	local CH = 30
	tunnel(-45, -340, 45, -260, { s = { { 0, 10 } } }, CH, "ARRAY", false)
	local center = Vector3.new(0, 0, -300)
	deco(structure, "Grating", Vector3.new(60, 0.2, 60), CFrame.new(center + Vector3.new(0, 0.1, 0)), C.SteelDark, Enum.Material.DiamondPlate)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * 26, 0, math.sin(a) * 26)
		block(props, "ArrayMast", Vector3.new(1.2, 22, 1.2), CFrame.new(p + Vector3.new(0, 11, 0)), C.SteelDark, Enum.Material.Metal)
		local dish = block(props, "ArrayDish", Vector3.new(0.6, 6, 6), CFrame.lookAt(p + Vector3.new(0, 20, 0), center + Vector3.new(0, 14, 0)) * CFrame.Angles(0, math.rad(90), 0), C.Plastic, Enum.Material.Metal)
		dish.Shape = Enum.PartType.Cylinder
		local tip = deco(props, "ArrayTip", Vector3.new(0.8, 0.8, 0.8), CFrame.new(p + Vector3.new(0, 22.5, 0)), Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
		tip.Shape = Enum.PartType.Ball
		kit.tag(tip, "FZ_SectorLight", { Sector = "ARRAY", OnColor = Color3.fromRGB(120, 200, 255) })
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(120, 200, 255)
		light.Parent = tip
		CollectionService:AddTag(tip, "FZ_KeyLight")
	end
	local column = block(props, "CoreColumn", Vector3.new(24, 8, 8), CFrame.new(center + Vector3.new(0, 12, 0)) * CFrame.Angles(0, 0, math.rad(90)), C.Steel, Enum.Material.Metal)
	column.Shape = Enum.PartType.Cylinder
	local glow = deco(props, "CoreGlow", Vector3.new(14, 8.6, 8.6), CFrame.new(center + Vector3.new(0, 14, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 210, 255), Enum.Material.Neon)
	glow.Shape = Enum.PartType.Cylinder
	glow.Transparency = 0.35
	kit.tag(glow, "FZ_SectorLight", { Sector = "ARRAY", OnColor = Color3.fromRGB(150, 210, 255) })
	glow:SetAttribute("CoreGlow", true)
	local coreLight = Instance.new("PointLight")
	coreLight.Range = 50
	coreLight.Brightness = 2
	coreLight.Color = Color3.fromRGB(150, 210, 255)
	coreLight.Parent = glow
	CollectionService:AddTag(glow, "FZ_KeyLight")
	for r = 0, 2 do
		local ring = deco(props, "CoreRing", Vector3.new(0.6, 14 + r * 4, 14 + r * 4), CFrame.new(center + Vector3.new(0, 4 + r * 7, 0)) * CFrame.Angles(0, 0, math.rad(90)), C.SteelDark, Enum.Material.Metal)
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.3
	end
	local console = block(props, "CoreConsole", Vector3.new(6, 3.6, 2.4), CFrame.new(center + Vector3.new(0, 1.8, 14)), C.SteelDark, Enum.Material.Metal)
	local screen = deco(props, "CoreScreen", Vector3.new(5, 1.8, 0.1), CFrame.new(center + Vector3.new(0, 4.5, 13.3)) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
	kit.worldText(screen, Enum.NormalId.Back, nil, "FREQ 000.000  ·  DURCHLAUF 0007", nil, Color3.fromRGB(10, 30, 50))
	kit.interactable(console, "c4_core", "INTERACT_ACTIVATE", "OBJECT_ARRAY_CORE", { HoldDuration = 2, MaxDistance = 9 })
	-- cavern lights: tall floodlights on the walls
	for _, p in { Vector3.new(-42, 18, -280), Vector3.new(42, 18, -280), Vector3.new(-42, 18, -330), Vector3.new(42, 18, -330) } do
		kit.floodLight(p, center + Vector3.new(0, 4, 0), Color3.fromRGB(200, 220, 255), 70)
	end
	kit.checkpoint("C4_CORE", CFrame.new(0, 0.5, -270))
	kit.patrol(Vector3.new(-30, 0, -300), "CORE")
	kit.patrol(Vector3.new(30, 0, -320), "CORE")
	kit.vent(Vector3.new(44.3, 1.5, -320), Vector3.new(-1, 0, 0), "deep")
	kit.speaker(Vector3.new(0, 20, -339), Vector3.new(0, 0, 1))
	kit.speaker(Vector3.new(0, 10, -121), Vector3.new(0, 0, -1))

	---------------------------------------------------------------------------
	-- Surface: yard, headframe, winding house
	---------------------------------------------------------------------------
	kit.previewGround(Vector3.new(0, -0.62, 150), Vector3.new(700, 1, 320), Color3.fromRGB(56, 54, 46))
	block(outside, "Yard", Vector3.new(120, 1, 90), CFrame.new(10, -0.45, 55), Color3.fromRGB(70, 64, 56), Enum.Material.Pebble)
	block(outside, "Road", Vector3.new(14, 1, 140), CFrame.new(0, -0.45, 170), C.Asphalt, Enum.Material.Asphalt)
	rails(Vector3.new(0, 0, 4), Vector3.new(0, 0, 60))
	-- headframe (lattice tower with sheaves)
	local hf = Vector3.new(38, 0, 30)
	for _, c in { { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } } do
		block(structure, "HeadframeLeg", Vector3.new(1, 36, 1), CFrame.new(hf + Vector3.new(c[1] * (1 - 0.3), 18, c[2] * (1 - 0.3))) * CFrame.Angles(c[2] * 0.04, 0, -c[1] * 0.04), C.Emergency:Lerp(C.SteelDark, 0.6), Enum.Material.Metal)
	end
	for y = 6, 30, 8 do
		block(structure, "HeadframeRing", Vector3.new(9, 0.6, 9), CFrame.new(hf + Vector3.new(0, y, 0)), C.SteelDark, Enum.Material.Metal).CanCollide = false
	end
	for _, dx in { -2, 2 } do
		local sheave = deco(structure, "Sheave", Vector3.new(0.6, 7, 7), CFrame.new(hf + Vector3.new(dx, 36, 0)), C.SteelDark, Enum.Material.Metal)
		sheave.Shape = Enum.PartType.Cylinder
	end
	-- winding house x 60..90, z 40..70 (the gate lever is inside)
	kit.room(60, 40, 90, 70, { h = 14, gaps = { w = { { 55, 6 } } }, wall = Color3.fromRGB(120, 60, 46), wallMaterial = Enum.Material.Brick, roof = Color3.fromRGB(60, 56, 54) })
	kit.door(Vector3.new(60, 0, 55), false, 6, false, nil, { prefix = "DW" })
	local drum = block(props, "WindingDrum", Vector3.new(8, 8, 8), CFrame.new(78, 5, 55), C.SteelDark, Enum.Material.Metal)
	drum.Shape = Enum.PartType.Cylinder
	kit.wheel(CFrame.new(68, 0, 48), "c4_winch", "INTERACT_PULL", "OBJECT_GATE_LEVER", { HoldDuration = 3 })
	kit.lightGrid(60, 90, 40, 70, "SURFACE", C.Warm)
	kit.document(CFrame.new(84, 3.25, 66) * CFrame.Angles(0, 0.4, 0), "c4_mine_notice")
	kit.desk(CFrame.new(84, 0, 66))
	kit.firstAid(CFrame.new(89.4, 5, 48) * CFrame.Angles(0, math.rad(-90), 0))
	for x = 64, 86, 11 do
		local pane = deco(structure, "Window", Vector3.new(4, 2.4, 0.15), CFrame.new(x, 9, 70.6), Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
		pane.Transparency = 0.3
	end
	-- yard props
	for i = 0, 3 do
		local cart = block(props, "MineCart", Vector3.new(4, 3, 6), CFrame.new(0, 1.9, 20 + i * 8), Color3.fromRGB(90, 60, 40), Enum.Material.CorrodedMetal)
		cart.CanCollide = i ~= 0
	end
	for i = 0, 7 do
		kit.barrel(CFrame.new(-30 + (i % 4) * 3, 0, 40 + math.floor(i / 4) * 3), if i % 2 == 0 then Color3.fromRGB(150, 60, 34) else Color3.fromRGB(60, 70, 60))
	end
	for _ = 1, 6 do
		kit.crate(CFrame.new(kit.rng:NextNumber(-40, -20), 0, kit.rng:NextNumber(60, 90)) * CFrame.Angles(0, kit.rng:NextNumber(0, 6), 0))
	end
	block(outside, "SpoilHeap", Vector3.new(30, 12, 26), CFrame.new(-60, 3, 40) * CFrame.Angles(0, 0.3, math.rad(10)), Color3.fromRGB(52, 48, 44), Enum.Material.Slate)
	for _, p in { Vector3.new(-14, 0, 30), Vector3.new(24, 0, 80), Vector3.new(-14, 0, 110) } do
		block(outside, "LampPost", Vector3.new(0.5, 12, 0.5), CFrame.new(p + Vector3.new(0, 6, 0)), C.SteelDark, Enum.Material.Metal).CanCollide = false
		kit.bulb(p + Vector3.new(0, 12, 0), C.Sodium, 32, 1.8, "SURFACE", true)
	end
	kit.floodLight(Vector3.new(38, 30, 30), Vector3.new(0, 0, 10), C.Fluorescent, 70)
	kit.forest(130, -320, 320, 30, 380, { { -80, 0, 100, 130 }, { -16, 100, 16, 400 }, { -40, 130, 40, 260 } }, 0.2)
	kit.patrol(Vector3.new(0, 0, 50), "SURFACE")
	kit.patrol(Vector3.new(70, 0, 30), "SURFACE")

	---------------------------------------------------------------------------
	-- Survival ("Mine - Tiefschicht"): generators, stations, breakers, keys, fuses
	---------------------------------------------------------------------------
	kit.generator(CFrame.new(-50, 0, -142) * CFrame.Angles(0, math.rad(90), 0), 1)
	kit.generator(CFrame.new(50, 0, -117), 2)
	kit.station(CFrame.new(16, 1.5, -122), "mine_station_1")
	kit.station(CFrame.new(76, 1.5, -112), "mine_station_2")
	kit.station(CFrame.new(-36, 1.5, -336), "mine_station_3")
	kit.panel(CFrame.new(79.4, 5, -126) * CFrame.Angles(0, math.rad(-90), 0), "breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { Sector = "PUMP" })
	kit.panel(CFrame.new(-79.4, 5, -112) * CFrame.Angles(0, math.rad(90), 0), "breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { Sector = "LIFT" })
	kit.panel(CFrame.new(89.4, 5, 62) * CFrame.Angles(0, math.rad(-90), 0), "breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { Sector = "SURFACE" })
	kit.panel(CFrame.new(-19.4, 5, -123) * CFrame.Angles(0, math.rad(90), 0), "mine_relay", "INTERACT_INSERT", "OBJECT_FUSE_PANEL", { HoldDuration = 3 }, C.Steel)
	kit.syncKey(CFrame.new(-4.4, 4.5, -56) * CFrame.Angles(0, math.rad(90), 0), 1)
	kit.syncKey(CFrame.new(-79.4, 4.5, -128) * CFrame.Angles(0, math.rad(90), 0), 2)
	for _, f in {
		{ CFrame.new(3.5, 0.4, -30), "MINE" }, { CFrame.new(-3.5, 0.4, -90), "MINE" },
		{ CFrame.new(18, 0.4, -138), "MINE" }, { CFrame.new(74, 0.4, -146), "PUMP" },
		{ CFrame.new(-76, 0.4, -146), "LIFT" }, { CFrame.new(-61, 0.4, -230), "LIFT" },
		{ CFrame.new(16, 0.4, -256), "TRANSFORMER" }, { CFrame.new(-40, 0.4, -300), "ARRAY" },
		{ CFrame.new(86.5, 3.45, 66.5), "SURFACE" },
	} do
		kit.fuseSpot(f[1], f[2])
	end
	local truck = block(outside, "Truck", Vector3.new(8, 7, 16), CFrame.new(-22, 3.6, 105) * CFrame.Angles(0, math.rad(-10), 0), Color3.fromRGB(150, 120, 40), Enum.Material.Metal)
	kit.interactable(truck, "mine_extract", "INTERACT_LEAVE", "OBJECT_TRUCK", { HoldDuration = 2, MaxDistance = 11 })
	kit.checkpoint("CP_SV_MINE", CFrame.new(20, 0.5, 70))

	---------------------------------------------------------------------------
	-- Markers
	---------------------------------------------------------------------------
	kit.checkpoint("C4_START", CFrame.new(0, 0.5, 115))
	kit.spawnLocation(CFrame.new(0, 0.5, 250))
	kit.creatureSpawn(CFrame.new(-74, 3, -122))
	for _, cf in {
		CFrame.new(3, 0.4, -40), CFrame.new(-3, 0.4, -100), CFrame.new(15, 0.4, -138), CFrame.new(76, 0.4, -146),
		CFrame.new(-44, 0.4, -146), CFrame.new(-61, 0.4, -220), CFrame.new(-16, 0.4, -256), CFrame.new(40, 0.4, -336),
		CFrame.new(84, 3.45, 65), CFrame.new(-28, 0.4, 70),
	} do
		kit.itemSpot(cf)
	end
	kit.menuCamera(1, Vector3.new(-30, 5, 100), Vector3.new(20, 18, 10), 7)
	kit.menuCamera(2, Vector3.new(0, 5, -112), Vector3.new(0, 4, -30), 4)
	kit.menuCamera(3, Vector3.new(-35, 10, -270), Vector3.new(0, 12, -300), 6)

	-- finishing pass: only the winding house gets painted walls (tunnels stay raw rock)
	local model = kit.root
	MapDress.Walls(model, { lower = Color3.fromRGB(70, 60, 50), rail = Color3.fromRGB(50, 40, 30), skirting = Color3.fromRGB(26, 24, 22), skip = { Enum.Material.Rock } })
	MapDress.LightCones(model, { "FloodLight" }, 50)
	MapDress.Mist(model, Vector3.new(0, 0, 60), Vector3.new(160, 0, 110), Color3.fromRGB(160, 160, 168), 1.1)
	MapDress.Mist(model, Vector3.new(0, 0, -300), Vector3.new(80, 0, 70), Color3.fromRGB(150, 190, 220), 1.6) -- cold mist on the Array floor
	MapDress.Mist(model, Vector3.new(0, 0, -200), Vector3.new(8, 0, 60), Color3.fromRGB(140, 140, 140), 0.6)
	MapDress.Steam(model, Vector3.new(-74, 13, -122), Vector3.yAxis) -- out of the lift shaft
	MapDress.Steam(model, Vector3.new(0, 26, -300), Vector3.yAxis, Color3.fromRGB(170, 210, 240)) -- the Array breathes
	MapDress.Steam(model, Vector3.new(66, 3, -130), Vector3.new(0, 1, 0.2))
	MapDress.Puddles(model, { { 2, -40, 4, 3 }, { -2, -95, 5, 3 }, { 0, -132, 7, 4 }, { 56, -138, 6, 5 }, { -60, -205, 4, 6 }, { 12, 40, 6, 4 } })
	MapDress.Flicker(model, 0.2, 55)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Roof" and d.CFrame.Position.Y > 10 and d.CFrame.Position.Z > 30 then
			d.Material = Enum.Material.RoofShingles -- winding house
		end
	end
	return kit.finish()
end

function Map.BuildTerrain(model: Instance?)
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -5.1, 180), Vector3.new(900, 10, 400), Enum.Material.Ground)
	-- the mountain, then the tunnels carved out of it (each tunnel has its own walls/roof)
	terrain:FillBlock(CFrame.new(0, 30, -200), Vector3.new(700, 80, 400), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(0, 75, -230), Vector3.new(600, 30, 300), Enum.Material.Grass)
	for _, r in CARVE do
		local x0, z0, x1, z1 = r[1] - 1, r[2] - 1, r[3] + 1, r[4] + 1
		local h = if z1 < -258 then 33 else 17
		terrain:FillBlock(CFrame.new((x0 + x1) / 2, h / 2 - 0.5, (z0 + z1) / 2), Vector3.new(x1 - x0, h, z1 - z0), Enum.Material.Air)
	end
	local patches = Random.new(31)
	for _ = 1, 20 do
		local x, z = patches:NextNumber(-380, 380), patches:NextNumber(20, 400)
		if not (x > -80 and x < 100 and z < 130) and math.abs(x) > 10 then
			terrain:FillBall(Vector3.new(x, -2.4, z), patches:NextNumber(10, 24), if patches:NextNumber() < 0.5 then Enum.Material.Grass else Enum.Material.Mud)
		end
	end
	MapKit.ApplyClouds("mine")
	MapDress.TerrainLook({
		Grass = Color3.fromRGB(62, 70, 50),
		LeafyGrass = Color3.fromRGB(56, 64, 46),
		Ground = Color3.fromRGB(74, 66, 56),
		Mud = Color3.fromRGB(54, 48, 42),
		Rock = Color3.fromRGB(84, 80, 76),
	})
	MapKit.RemovePreview(model)
end

function Map.ApplyLighting()
	MapKit.ApplyLighting("mine")
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
