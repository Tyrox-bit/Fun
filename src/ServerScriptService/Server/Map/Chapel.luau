-- Die Kapelle - chapter 3 "The Protocol".
--
--                 ┌──────────── HÜGEL (hill) ─────────────┐
--                 │  [Operatorraum]  (sealed)              │
--   ( Apsis )     │  [   ARCHIV    ][Tonbandraum]          │
--   [Kirchenschiff]─[Sakristei]═══ Gang ═══┘               │
--   [Glockenturm]                                          │
--   ─ Friedhof ─ Tor ─ Waldweg (south, start)
--
-- InteractIds: c3_altar (opens the hidden passage), c3_breaker, c3_winch, c3_tape (5x,
-- TapeSlot 1-5), c3_deck (master deck), c3_relay_recorder (the twist), c3_bell (end).

local CollectionService = game:GetService("CollectionService")

local MapKit = require(script.Parent.MapKit)
local MapDress = require(script.Parent.MapDress)
local Textures = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Textures"))
local C = MapKit.C

local Map = {}

local STONE = Color3.fromRGB(132, 128, 118)
local STONE_DARK = Color3.fromRGB(92, 88, 82)
local ROOF = Color3.fromRGB(58, 52, 50)

local function build()
	local kit = MapKit.new("FZ_Chapel", "Chapel", 404)
	local block, deco = kit.block, kit.deco
	local structure = kit.folder("Structure")
	local props = kit.folder("Props")
	local outside = kit.folder("Outside")
	local stone = { color = STONE, material = Enum.Material.Cobblestone, t = 2 }

	---------------------------------------------------------------------------
	-- Nave x -18..18, z -40..40, wall height 24, stepped gables, pitched roof
	---------------------------------------------------------------------------
	local NH = 24
	kit.slab("NaveFloor", -18, -40, 18, 40, 0, 1, Color3.fromRGB(96, 90, 84), Enum.Material.Slate)
	local naveWall = { y = 0, h = NH, doorH = 12, color = STONE, material = Enum.Material.Cobblestone, t = 2 }
	kit.wallZ(40, -18, 18, { { 0, 8 } }, naveWall)
	kit.wallX(-18, -40, 40, nil, naveWall)
	kit.wallX(18, -40, 40, { { -20, 6 } }, naveWall)
	-- apse (north): half ring of wall segments
	local segments = 6
	for i = 0, segments - 1 do
		local a0, a1 = math.pi + i / segments * math.pi, math.pi + (i + 1) / segments * math.pi
		local p0 = Vector3.new(math.cos(a0) * 18, 0, -40 + math.sin(a0) * 14)
		local p1 = Vector3.new(math.cos(a1) * 18, 0, -40 + math.sin(a1) * 14)
		local mid = (p0 + p1) / 2
		block(structure, "ApseWall", Vector3.new((p1 - p0).Magnitude + 1, NH - 4, 2), CFrame.lookAt(mid + Vector3.new(0, (NH - 4) / 2, 0), mid + Vector3.new(0, (NH - 4) / 2, 0) + (p1 - p0):Cross(Vector3.yAxis)), STONE, Enum.Material.Cobblestone)
	end
	kit.slab("ApseFloor", -18, -54, 18, -40, 0, 1, Color3.fromRGB(96, 90, 84), Enum.Material.Slate)
	block(structure, "ApseRoof", Vector3.new(38, 1.4, 16), CFrame.new(0, NH - 3.3, -47), ROOF, Enum.Material.Slate)
	-- pitched roof planes
	local rise, half = 12, 19
	local angle = math.atan(rise / half)
	local planeWidth = math.sqrt(rise * rise + half * half) + 1
	for _, side in { -1, 1 } do
		block(structure, "RoofPlane", Vector3.new(planeWidth, 1.2, 84), CFrame.new(side * half / 2, NH + rise / 2, 0) * CFrame.Angles(0, 0, -side * angle), ROOF, Enum.Material.Slate)
	end
	-- stepped gables (north + south)
	for _, z in { -40, 40 } do
		for step = 0, 5 do
			local w = 36 - step * 6
			block(structure, "Gable", Vector3.new(w, 2.2, 2), CFrame.new(0, NH + 1.1 + step * 2, z), STONE, Enum.Material.Cobblestone)
		end
	end
	block(structure, "Ceiling", Vector3.new(36, 0.6, 80), CFrame.new(0, NH - 0.3, 0), Color3.fromRGB(70, 56, 44), Enum.Material.WoodPlanks)
	for z = -36, 36, 8 do
		deco(structure, "Rafter", Vector3.new(36, 1.2, 0.9), CFrame.new(0, NH - 1.2, z), C.WoodDark, Enum.Material.Wood)
	end
	-- buttresses + tall windows (dim stained glass)
	local glass = { Color3.fromRGB(110, 30, 30), Color3.fromRGB(30, 50, 110), Color3.fromRGB(120, 100, 36), Color3.fromRGB(36, 86, 58) }
	for i, z in { -30, -15, 0, 15, 30 } do
		for _, side in { -1, 1 } do
			block(structure, "Buttress", Vector3.new(3, 18, 3), CFrame.new(side * 20, 9, z + 7.5), STONE_DARK, Enum.Material.Cobblestone)
			local pane = deco(structure, "StainedGlass", Vector3.new(0.3, 9, 3.4), CFrame.new(side * 17.1, 13, z), glass[(i % #glass) + 1], Enum.Material.Neon)
			pane.Transparency = 0.62
			local glow = Instance.new("SurfaceLight")
			glow.Face = if side < 0 then Enum.NormalId.Right else Enum.NormalId.Left
			glow.Range = 10
			glow.Brightness = 0.35
			glow.Color = pane.Color
			glow.Parent = pane
			CollectionService:AddTag(pane, "FZ_DecorLight")
		end
	end
	-- pews, aisle runner, altar, candles
	for z = -22, 30, 6 do
		kit.bench(CFrame.new(-9, 0, z), 12, C.WoodDark)
		kit.bench(CFrame.new(9, 0, z), 12, C.WoodDark)
		block(props, "PewBack", Vector3.new(12, 2.2, 0.3), CFrame.new(-9, 3, z + 0.8), C.WoodDark, Enum.Material.Wood)
		block(props, "PewBack", Vector3.new(12, 2.2, 0.3), CFrame.new(9, 3, z + 0.8), C.WoodDark, Enum.Material.Wood)
	end
	deco(props, "Runner", Vector3.new(4, 0.05, 70), CFrame.new(0, 0.03, 2), Color3.fromRGB(110, 30, 30), Enum.Material.Fabric)
	block(props, "AltarStep", Vector3.new(26, 1, 12), CFrame.new(0, 0.5, -38), STONE_DARK, Enum.Material.Marble)
	local altar = block(props, "Altar", Vector3.new(10, 4, 4), CFrame.new(0, 3, -42), Color3.fromRGB(200, 196, 186), Enum.Material.Marble)
	deco(props, "AltarCloth", Vector3.new(10.4, 0.1, 4.4), CFrame.new(0, 5.05, -42), Color3.fromRGB(230, 226, 214), Enum.Material.Fabric)
	kit.interactable(altar, "c3_altar", "INTERACT_SEARCH", "OBJECT_ALTAR", { MaxDistance = 8, HoldDuration = 1.5 })
	local cross = block(props, "Cross", Vector3.new(0.6, 8, 0.6), CFrame.new(0, 14, -52), C.WoodDark, Enum.Material.Wood)
	block(props, "CrossBar", Vector3.new(4.5, 0.6, 0.6), cross.CFrame * CFrame.new(0, 1.8, 0), C.WoodDark, Enum.Material.Wood)
	for _, x in { -4, -2.5, 2.5, 4 } do
		kit.candle(Vector3.new(x, 5.1, -42), x == -4)
	end
	for _, p in { Vector3.new(-12, 1, -36), Vector3.new(12, 1, -36), Vector3.new(-16, 1, 36), Vector3.new(16, 1, 36) } do
		block(props, "Candelabrum", Vector3.new(0.5, 4, 0.5), CFrame.new(p + Vector3.new(0, 1, 0)), C.SteelDark, Enum.Material.Metal)
		kit.candle(p + Vector3.new(0, 3, 0), true)
	end
	-- chandeliers (sector NAVE: power cut by the forecast? no - candles keep it readable)
	for _, z in { -20, 0, 20 } do
		kit.bulb(Vector3.new(0, NH - 6, z), C.Candle, 30, 1.3, "NAVE", z == 0)
		deco(props, "Chain", Vector3.new(0.15, 5, 0.15), CFrame.new(0, NH - 3.4, z), C.SteelDark, Enum.Material.Metal)
		deco(props, "Chandelier", Vector3.new(4, 0.3, 4), CFrame.new(0, NH - 6.5, z), C.SteelDark, Enum.Material.Metal)
	end
	kit.document(CFrame.new(12, 3.3, 26) * CFrame.Angles(0, 0.5, 0), "c3_hymn")
	kit.patrol(Vector3.new(0, 0, 0), "NAVE")
	kit.patrol(Vector3.new(0, 0, -30), "NAVE")
	kit.vent(Vector3.new(-16.9, 1.5, -10), Vector3.new(1, 0, 0), "chapel")
	kit.checkpoint("C3_CHAPEL", CFrame.new(0, 0.5, 32))

	---------------------------------------------------------------------------
	-- Bell tower x -7..7, z 40..54 (entrance through its base)
	---------------------------------------------------------------------------
	local TH = 44
	kit.slab("TowerFloor", -7, 40, 7, 54, 0, 1, Color3.fromRGB(96, 90, 84), Enum.Material.Slate)
	local towerWall = { y = 0, h = 32, doorH = 11, color = STONE, material = Enum.Material.Cobblestone, t = 2 }
	kit.wallZ(54, -7, 7, { { 0, 6 } }, towerWall)
	kit.wallX(-7, 40, 54, nil, towerWall)
	kit.wallX(7, 40, 54, nil, towerWall)
	block(structure, "TowerCeiling", Vector3.new(14, 1, 14), CFrame.new(0, 12.5, 47), C.WoodDark, Enum.Material.WoodPlanks)
	for _, c in { { -6, 41 }, { 6, 41 }, { -6, 53 }, { 6, 53 } } do
		block(structure, "BelfryPillar", Vector3.new(2.4, TH - 32, 2.4), CFrame.new(c[1], 32 + (TH - 32) / 2, c[2]), STONE, Enum.Material.Cobblestone)
	end
	block(structure, "BelfryFloor", Vector3.new(15, 1, 15), CFrame.new(0, 32, 47), STONE_DARK, Enum.Material.Cobblestone)
	for step = 0, 6 do
		local w = 16 - step * 2.2
		block(structure, "Spire", Vector3.new(w, 2.4, w), CFrame.new(0, TH + 1.2 + step * 2.4, 47), ROOF, Enum.Material.Slate)
	end
	block(structure, "SpireCross", Vector3.new(0.5, 5, 0.5), CFrame.new(0, TH + 20, 47), C.SteelDark, Enum.Material.Metal)
	block(structure, "SpireCrossBar", Vector3.new(2.6, 0.5, 0.5), CFrame.new(0, TH + 21, 47), C.SteelDark, Enum.Material.Metal)
	local bell = block(props, "Bell", Vector3.new(5, 5, 5), CFrame.new(0, 37, 47), Color3.fromRGB(150, 120, 60), Enum.Material.Metal)
	bell.Shape = Enum.PartType.Ball
	block(props, "BellYoke", Vector3.new(9, 0.8, 0.8), CFrame.new(0, 40, 47), C.WoodDark, Enum.Material.Wood)
	local rope = block(props, "BellRope", Vector3.new(0.3, 11, 0.3), CFrame.new(3, 6.5, 50), Color3.fromRGB(160, 140, 100), Enum.Material.Fabric)
	rope.CanCollide = false
	local ropeHandle = block(props, "BellRopeHandle", Vector3.new(0.8, 1.6, 0.8), CFrame.new(3, 1.8, 50), Color3.fromRGB(110, 30, 30), Enum.Material.Fabric)
	kit.interactable(ropeHandle, "c3_bell", "INTERACT_RING", "OBJECT_BELL", { HoldDuration = 3, MaxDistance = 8 })
	kit.bulb(Vector3.new(0, 11, 47), C.Warm, 16, 1, "TOWER", true)
	kit.patrol(Vector3.new(0, 0, 47), "TOWER")
	local towerDoor = kit.door(Vector3.new(0, 0, 54), true, 6, false, nil, { doorH = 11, color = C.WoodDark, material = Enum.Material.Wood, prefix = "DT" })
	towerDoor.Name = "TowerDoor"
	local naveDoor = kit.door(Vector3.new(0, 0, 40), true, 8, false, nil, { doorH = 12, color = C.WoodDark, material = Enum.Material.Wood, prefix = "DT" })
	naveDoor.Name = "NaveDoor"

	---------------------------------------------------------------------------
	-- Sacristy x 18..34, z -30..-10 (hidden passage east, opened by the altar)
	---------------------------------------------------------------------------
	kit.room(18, -30, 34, -10, { h = 14, gaps = { w = { { -20, 6 } }, e = { { -20, 6 } } }, floor = Color3.fromRGB(90, 74, 60), floorMaterial = Enum.Material.WoodPlanks, wall = STONE, wallMaterial = Enum.Material.Cobblestone, roof = ROOF })
	kit.door(Vector3.new(18, 0, -20), false, 6, false, nil, { color = C.WoodDark, material = Enum.Material.Wood, prefix = "DS" })
	local passage = kit.door(Vector3.new(34, 0, -20), false, 6, true, "", { color = C.WoodDark, material = Enum.Material.Wood, prefix = "DS" })
	passage.Name = "HiddenPassage"
	passage:SetAttribute("Hidden", true)
	kit.shelf(CFrame.new(33, 0, -13) * CFrame.Angles(0, math.rad(-90), 0))
	kit.cabinet(CFrame.new(20, 0, -28))
	kit.desk(CFrame.new(26, 0, -28))
	kit.document(CFrame.new(26, 3.25, -28) * CFrame.Angles(0, 0.2, 0), "c3_priest_note")
	kit.candle(Vector3.new(24, 3.15, -27.5), true)
	kit.bulb(Vector3.new(26, 12, -20), C.Warm, 18, 1, "SACRISTY", true)
	kit.firstAid(CFrame.new(18.6 + 1, 5, -12) * CFrame.Angles(0, math.rad(90), 0))
	kit.patrol(Vector3.new(26, 0, -20), "SACRISTY")
	kit.vent(Vector3.new(33.3, 1.5, -27), Vector3.new(-1, 0, 0), "chapel")

	---------------------------------------------------------------------------
	-- Bunker inside the hill: corridor, archive, tape room, operator room
	---------------------------------------------------------------------------
	local bunkerWall = Color3.fromRGB(110, 112, 106)
	-- corridor x 34..60, z -24..-16
	kit.room(34, -24, 60, -16, { gaps = { w = { { -20, 6 } }, e = { { -20, 8 } } }, floor = Color3.fromRGB(74, 76, 72), wall = bunkerWall })
	for x = 38, 58, 10 do
		kit.bulb(Vector3.new(x, 12.5, -20), C.Fluorescent, 16, 1, "ARCHIVE", x == 38)
	end
	kit.panel(CFrame.new(44, 5, -23.4), "c3_breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { Sector = "ARCHIVE" })
	kit.checkpoint("C3_ARCHIVE", CFrame.new(48, 0.5, -20))
	kit.patrol(Vector3.new(48, 0, -20), "CORRIDOR")
	deco(props, "RoughWall", Vector3.new(26, 14, 0.4), CFrame.new(47, 7, -24.2), STONE_DARK, Enum.Material.Rock)
	-- archive x 60..110, z -60..0
	kit.room(60, -60, 110, 0, { gaps = { w = { { -20, 8 } }, e = { { -30, 8 } }, n = { { 85, 8 } } }, floor = Color3.fromRGB(84, 74, 58), wall = bunkerWall })
	for x = 66, 102, 9 do
		for _, z in { -50, -38 } do
			kit.shelf(CFrame.new(x, 0, z))
		end
	end
	for x = 70, 100, 15 do
		kit.shelf(CFrame.new(x, 0, -8))
	end
	kit.desk(CFrame.new(72, 0, -24))
	kit.deskLamp(CFrame.new(70, 3.15, -24.5))
	kit.document(CFrame.new(74, 3.25, -24) * CFrame.Angles(0, -0.3, 0), "c3_index_card")
	kit.recorder(CFrame.new(103, 0.6, -55), "log_marek")
	kit.lightGrid(60, 110, -60, 0, "ARCHIVE", Color3.fromRGB(235, 225, 200))
	kit.emergencyLight(Vector3.new(61.5, 11, -10), "ARCHIVE")
	kit.firstAid(CFrame.new(109.4, 5, -10) * CFrame.Angles(0, math.rad(-90), 0))
	kit.patrol(Vector3.new(85, 0, -28), "ARCHIVE")
	kit.patrol(Vector3.new(70, 0, -55), "ARCHIVE")
	kit.vent(Vector3.new(60.7, 1.5, -45), Vector3.new(1, 0, 0), "bunker")
	kit.creatureSpawn(CFrame.new(64, 3, -56))
	-- the archive gate (door kind forecast) + winch
	local gate = kit.door(Vector3.new(110, 0, -30), false, 8, false, nil, { prefix = "DA" })
	gate.Name = "ArchiveGate"
	gate:SetAttribute("ArchiveGate", true)
	kit.wheel(CFrame.new(106, 0, -24), "c3_winch", "INTERACT_TURN", "OBJECT_WINCH", { HoldDuration = 3 })
	-- tape room x 110..140, z -50..-10
	kit.room(110, -50, 140, -10, { gaps = { w = { { -30, 8 } } }, floor = Color3.fromRGB(70, 66, 60), wall = Color3.fromRGB(96, 92, 86) })
	local deck = block(props, "MasterDeck", Vector3.new(6, 4, 3), CFrame.new(125, 2, -30), Color3.fromRGB(60, 56, 50), Enum.Material.SmoothPlastic)
	for _, dx in { -1.6, 1.6 } do
		local reel = block(props, "DeckReel", Vector3.new(0.2, 2.2, 2.2), CFrame.new(125 + dx, 4.5, -30) * CFrame.Angles(0, math.rad(90), 0), C.Plastic, Enum.Material.SmoothPlastic)
		reel.Shape = Enum.PartType.Cylinder
		reel.CanCollide = false
	end
	local deckLamp = block(props, "DeckLamp", Vector3.new(0.5, 0.5, 0.1), CFrame.new(127.4, 3.4, -31.55), C.Emergency, Enum.Material.Neon)
	deckLamp.CanCollide = false
	deckLamp:SetAttribute("DeckLamp", true)
	kit.interactable(deck, "c3_deck", "INTERACT_INSERT_TAPE", "OBJECT_DECK", { MaxDistance = 8 })
	local tapeSpots = {
		CFrame.new(114, 3.6, -46), CFrame.new(136, 3.6, -46), CFrame.new(136, 3.6, -14),
		CFrame.new(64, 3.6, -26), CFrame.new(96, 3.6, -4),
	}
	for i, cf in tapeSpots do
		kit.table_(cf * CFrame.new(0, -3.6, 0), Vector3.new(4, 0.3, 2.4), Color3.fromRGB(70, 56, 44))
		local recorder = block(props, "TapeRecorder", Vector3.new(1.6, 0.7, 1.2), cf * CFrame.new(0, 0.35, 0), Color3.fromRGB(48, 44, 40), Enum.Material.SmoothPlastic)
		local reel = block(props, "Reel", Vector3.new(0.1, 0.6, 0.6), cf * CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Plastic, Enum.Material.SmoothPlastic)
		reel.Shape = Enum.PartType.Cylinder
		reel.CanCollide = false
		local led = Instance.new("PointLight")
		led.Range = 4
		led.Brightness = 0.7
		led.Color = Color3.fromRGB(255, 120, 60)
		led.Parent = recorder
		kit.interactable(recorder, "c3_tape", "INTERACT_LISTEN", "OBJECT_TAPE", { MaxDistance = 7, TapeSlot = i })
	end
	kit.lightGrid(110, 140, -50, -10, "TAPES", Color3.fromRGB(255, 214, 170))
	kit.patrol(Vector3.new(125, 0, -20), "TAPES")
	kit.vent(Vector3.new(139.3, 1.5, -40), Vector3.new(-1, 0, 0), "bunker")
	kit.firstAid(CFrame.new(139.4, 5, -24) * CFrame.Angles(0, math.rad(-90), 0))
	kit.speaker(Vector3.new(125, 12.5, -10.8), Vector3.new(0, 0, -1))
	-- sealed operator room x 70..100, z -90..-60 (behind a heavy door at z -60)
	kit.room(70, -90, 100, -60, { gaps = { s = { { 85, 8 } } }, floor = Color3.fromRGB(60, 62, 62), wall = Color3.fromRGB(80, 84, 86) })
	local sealed = kit.door(Vector3.new(85, 0, -60), true, 8, true, "", { color = Color3.fromRGB(90, 96, 98), prefix = "DO" })
	sealed.Name = "SealedDoor"
	sealed:SetAttribute("Sealed", true)
	local screens = kit.console(CFrame.new(85, 0, -86) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(120, 200, 255))
	for _, screen in screens do
		kit.worldText(screen, Enum.NormalId.Front, nil, "DURCHLAUF 0007", nil, Color3.fromRGB(10, 30, 50))
	end
	kit.serverRack(CFrame.new(72, 0, -88) * CFrame.Angles(0, math.rad(90), 0))
	kit.serverRack(CFrame.new(98, 0, -88) * CFrame.Angles(0, math.rad(-90), 0))
	kit.table_(CFrame.new(85, 0, -74), Vector3.new(7, 0.3, 3.2), Color3.fromRGB(70, 56, 44))
	-- the twist: a radio (painted like a player's own at runtime) and the Relay's recorder
	local twistRadio = block(props, "TwistRadio", Vector3.new(0.8, 1.8, 0.5), CFrame.new(83, 4.05, -74) * CFrame.Angles(0, math.rad(20), math.rad(-75)), Color3.fromRGB(40, 42, 44), Enum.Material.SmoothPlastic)
	twistRadio:SetAttribute("TwistRadio", true)
	local antennaRod = deco(props, "TwistRadioAntenna", Vector3.new(0.12, 1.6, 0.12), twistRadio.CFrame * CFrame.new(0.2, 1.5, 0), C.SteelDark, Enum.Material.Metal)
	antennaRod.Name = "TwistRadioAntenna"
	local relayRecorder = block(props, "RelayRecorder", Vector3.new(1.6, 0.7, 1.2), CFrame.new(87.5, 3.5, -74), Color3.fromRGB(40, 38, 36), Enum.Material.SmoothPlastic)
	kit.interactable(relayRecorder, "c3_relay_recorder", "INTERACT_LISTEN", "OBJECT_RELAY_RECORDER", { MaxDistance = 7 })
	local plaque = block(props, "TwistPlaque", Vector3.new(5, 1.2, 0.1), CFrame.new(85, 5, -89.4), Color3.fromRGB(180, 170, 140), Enum.Material.Metal)
	local plaqueText = kit.worldText(plaque, Enum.NormalId.Front, nil, "DURCHLAUF 0007", nil, Color3.fromRGB(30, 26, 20))
	plaqueText.Name = "TwistPlaqueText"
	plaque.CFrame = CFrame.lookAt(Vector3.new(85, 5.5, -89.4), Vector3.new(85, 5.5, -80))
	for _, x in { 74, 96 } do
		kit.emergencyLight(Vector3.new(x, 12, -61.5), "OPERATOR")
	end
	kit.lightGrid(70, 100, -90, -60, "OPERATOR", Color3.fromRGB(190, 220, 255))
	kit.checkpoint("C3_OPERATOR", CFrame.new(85, 0.5, -55))
	kit.patrol(Vector3.new(85, 0, -75), "OPERATOR")

	---------------------------------------------------------------------------
	-- Cemetery, path, forest
	---------------------------------------------------------------------------
	kit.previewGround(Vector3.new(0, -0.62, 80), Vector3.new(700, 1, 600), Color3.fromRGB(44, 52, 40))
	local hillPreview = block(outside, "EditPreviewHill", Vector3.new(130, 16, 110), CFrame.new(95, 23, -45), Color3.fromRGB(50, 58, 44), Enum.Material.Grass)
	hillPreview:SetAttribute("FZ_EditPreview", true)
	hillPreview.Transparency = 0.5
	hillPreview.CanCollide = false
	block(outside, "Path", Vector3.new(6, 0.6, 200), CFrame.new(0, -0.2, 155), Color3.fromRGB(96, 90, 80), Enum.Material.Pebble)
	-- cemetery wall with gate
	local fence = { h = 3, color = STONE_DARK, material = Enum.Material.Cobblestone, t = 1.2, doorH = 3 }
	kit.wallZ(130, -60, 60, { { 0, 6 } }, fence)
	kit.wallX(-60, 54, 130, nil, fence)
	kit.wallX(60, 54, 130, nil, fence)
	for _, x in { -3.6, 3.6 } do
		block(outside, "GatePillar", Vector3.new(1.6, 5, 1.6), CFrame.new(x, 2.5, 130), STONE, Enum.Material.Cobblestone)
		kit.bulb(Vector3.new(x, 5.8, 130), C.Candle, 20, 1.2, "CEMETERY", true)
	end
	-- graves
	for row = 0, 4 do
		for col = 0, 9 do
			local x = -52 + col * 11.5
			local z = 62 + row * 13
			if math.abs(x) > 7 then
				local tilt = kit.rng:NextNumber(-0.12, 0.12)
				local h = kit.rng:NextNumber(2.2, 4)
				local stoneCf = CFrame.new(x, h / 2, z) * CFrame.Angles(tilt, kit.rng:NextNumber(-0.1, 0.1), tilt * 0.5)
				if (row + col) % 5 == 0 then
					block(outside, "GraveCross", Vector3.new(0.5, h + 1.5, 0.5), stoneCf * CFrame.new(0, 0.75, 0), STONE_DARK, Enum.Material.Granite)
					block(outside, "GraveCrossBar", Vector3.new(2, 0.5, 0.5), stoneCf * CFrame.new(0, h / 2 + 0.3, 0), STONE_DARK, Enum.Material.Granite)
				else
					block(outside, "Gravestone", Vector3.new(2.6, h, 0.6), stoneCf, STONE:Lerp(STONE_DARK, kit.rng:NextNumber()), Enum.Material.Granite)
				end
				deco(outside, "GraveBed", Vector3.new(3, 0.3, 5), CFrame.new(x, 0.1, z + 3), Color3.fromRGB(56, 48, 38), Enum.Material.Ground)
			end
		end
	end
	-- the memorial for the six of 2009
	local memorial = block(outside, "Memorial", Vector3.new(6, 5, 1.2), CFrame.new(-30, 2.5, 120), Color3.fromRGB(150, 146, 140), Enum.Material.Marble)
	kit.worldText(memorial, Enum.NormalId.Back, "MEMORIAL_TEXT")
	memorial.CFrame = CFrame.lookAt(Vector3.new(-30, 2.5, 120), Vector3.new(-30, 2.5, 130))
	kit.interactable(memorial, "lore", "INTERACT_READ", "OBJECT_MEMORIAL", { MaxDistance = 8, LogId = "c3_memorial" })
	kit.candle(Vector3.new(-31.5, 0, 121.5), true)
	kit.candle(Vector3.new(-28.5, 0, 121.5), false)
	for _, p in { Vector3.new(-40, 0, 90), Vector3.new(40, 0, 75), Vector3.new(25, 0, 110) } do
		block(outside, "LanternPost", Vector3.new(0.4, 6, 0.4), CFrame.new(p + Vector3.new(0, 3, 0)), C.SteelDark, Enum.Material.Metal)
		kit.bulb(p + Vector3.new(0, 6.4, 0), C.Candle, 22, 1.3, "CEMETERY", true)
	end
	for _ = 1, 6 do
		kit.tree(outside, Vector3.new(kit.rng:NextNumber(-55, 55), 0, kit.rng:NextNumber(58, 125)), kit.rng:NextNumber(0.5, 0.8), true)
	end
	kit.patrol(Vector3.new(-30, 0, 90), "CEMETERY")
	kit.patrol(Vector3.new(30, 0, 100), "CEMETERY")
	kit.patrol(Vector3.new(0, 0, 160), "PATH")
	kit.forest(180, -340, 340, -260, 400, { { -70, -70, 175, 140 }, { -12, 130, 12, 420 }, { -40, 170, 40, 300 } }, 0.25)
	for _ = 1, 30 do
		local x, z = kit.rng:NextNumber(-200, 200), kit.rng:NextNumber(-150, 300)
		if not (x > -70 and x < 175 and z > -110 and z < 140) and math.abs(x) > 8 then
			kit.rock(Vector3.new(x, 0, z), kit.rng:NextNumber(1.5, 4))
		end
	end
	-- an old car at the end of the forest path (start)
	local car = block(outside, "Car", Vector3.new(6, 4.4, 12), CFrame.new(-7, 2.4, 205) * CFrame.Angles(0, math.rad(8), 0), Color3.fromRGB(80, 30, 28), Enum.Material.Metal)
	kit.interactable(car, "church_extract", "INTERACT_LEAVE", "OBJECT_CAR", { HoldDuration = 2, MaxDistance = 10 })
	kit.bulb(Vector3.new(-7, 2.5, 198.5), C.Warm, 26, 1.4, nil, true)

	---------------------------------------------------------------------------
	-- Survival ("Kapelle - Nachtwache"): generator shed, stations, breakers, keys
	---------------------------------------------------------------------------
	kit.slab("ShedFloor", -44, -22, -24, 6, 0, 1, Color3.fromRGB(70, 64, 56))
	block(structure, "ShedRoof", Vector3.new(22, 0.8, 30), CFrame.new(-34, 10, -8) * CFrame.Angles(0, 0, math.rad(-8)), ROOF, Enum.Material.CorrodedMetal)
	for _, p in { Vector3.new(-43, 0, -21), Vector3.new(-25, 0, -21), Vector3.new(-43, 0, 5), Vector3.new(-25, 0, 5) } do
		block(structure, "ShedPost", Vector3.new(0.6, 10, 0.6), CFrame.new(p + Vector3.new(0, 5, 0)), C.WoodDark, Enum.Material.Wood)
	end
	kit.generator(CFrame.new(-34, 0, -14) * CFrame.Angles(0, math.rad(90), 0), 1)
	kit.generator(CFrame.new(-34, 0, -1) * CFrame.Angles(0, math.rad(90), 0), 2)
	kit.bulb(Vector3.new(-34, 9, -8), C.Sodium, 24, 1.4, "CEMETERY", true)
	kit.station(CFrame.new(-14, 1.5, -46), "church_station_1")
	kit.station(CFrame.new(64, 1.5, -58), "church_station_2")
	kit.station(CFrame.new(76, 1.5, -64), "church_station_3")
	kit.panel(CFrame.new(-16.4, 5, 10) * CFrame.Angles(0, math.rad(90), 0), "breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { Sector = "NAVE" })
	kit.panel(CFrame.new(33.4, 5, -26) * CFrame.Angles(0, math.rad(-90), 0), "breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { Sector = "SACRISTY" })
	kit.panel(CFrame.new(139.4, 5, -16) * CFrame.Angles(0, math.rad(-90), 0), "breaker", "INTERACT_HOLD_BREAKER", "OBJECT_BREAKER", { Sector = "TAPES" })
	kit.panel(CFrame.new(28, 5, -10.6), "church_relay", "INTERACT_INSERT", "OBJECT_FUSE_PANEL", { HoldDuration = 3 }, C.Steel)
	kit.syncKey(CFrame.new(60.6, 4.5, -30) * CFrame.Angles(0, math.rad(90), 0), 1)
	kit.syncKey(CFrame.new(139.4, 4.5, -36) * CFrame.Angles(0, math.rad(-90), 0), 2)
	kit.checkpoint("CP_SV_CHURCH", CFrame.new(0, 0.5, 20))

	---------------------------------------------------------------------------
	-- Markers
	---------------------------------------------------------------------------
	kit.checkpoint("C3_START", CFrame.new(0, 0.5, 210))
	kit.spawnLocation(CFrame.new(0, 0.5, 270))
	for _, cf in {
		CFrame.new(-9, 2.2, 10), CFrame.new(9, 2.2, -16), CFrame.new(26, 3.45, -28.5), CFrame.new(50, 0.4, -18),
		CFrame.new(72, 3.45, -23), CFrame.new(100, 0.4, -30), CFrame.new(120, 0.4, -46), CFrame.new(134, 0.4, -12),
		CFrame.new(-20, 0.4, 100), CFrame.new(3, 0.4, 44),
	} do
		kit.itemSpot(cf)
	end
	for _, f in {
		{ CFrame.new(-14, 2.2, 22), "NAVE" }, { CFrame.new(30, 0.4, -12), "SACRISTY" },
		{ CFrame.new(66, 0.4, -4), "ARCHIVE" }, { CFrame.new(104, 0.4, -58), "ARCHIVE" },
		{ CFrame.new(136, 0.4, -48), "TAPES" }, { CFrame.new(-50, 0.4, 125), "CEMETERY" },
	} do
		kit.fuseSpot(f[1], f[2])
	end
	kit.speaker(Vector3.new(0, 18, -39), Vector3.new(0, 0, 1))
	kit.speaker(Vector3.new(85, 12.5, -0.8), Vector3.new(0, 0, -1))
	kit.menuCamera(1, Vector3.new(-14, 4, 178), Vector3.new(0, 22, 40), 6)
	kit.menuCamera(2, Vector3.new(0, 6, 34), Vector3.new(0, 6, -42), 5)
	kit.menuCamera(3, Vector3.new(-50, 5, 118), Vector3.new(0, 18, 50), 7)
	kit.menuCamera(4, Vector3.new(63, 8, -30), Vector3.new(108, 3, -28), 4)

	-- finishing pass: wood panelling in the nave, painted bunker walls, cemetery mist,
	-- moonlight falling through the stained glass
	local model = kit.root
	MapDress.Walls(model, { lower = Color3.fromRGB(70, 50, 36), rail = Color3.fromRGB(52, 36, 24), skirting = Color3.fromRGB(30, 24, 20), height = 5, material = Enum.Material.Wood })
	MapDress.Mist(model, Vector3.new(0, 0, 92), Vector3.new(120, 0, 76), Color3.fromRGB(176, 184, 200), 1.8)
	MapDress.Mist(model, Vector3.new(0, 0, 175), Vector3.new(60, 0, 80), Color3.fromRGB(176, 184, 200), 1.2)
	MapDress.Mist(model, Vector3.new(-120, 0, 40), Vector3.new(120, 0, 200), nil, 0.8)
	for _, pane in model:GetDescendants() do
		if pane:IsA("BasePart") and pane.Name == "StainedGlass" then
			local p = pane.CFrame.Position
			local inward = if p.X < 0 then 1 else -1
			MapDress.Shaft(pane, Vector3.new(p.X + inward * 12, 0, p.Z + 3), 6, Color3.fromRGB(170, 190, 230))
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "RoofPlane" then
				d.Material = Enum.Material.RoofShingles
			elseif d.Name == "Floor" then
				local p = d.CFrame.Position
				if p.X > 60 and p.X < 110 and p.Z > -60 and p.Z < 0 then
					d.Material = Enum.Material.Carpet -- archive
					d.Color = Color3.fromRGB(84, 40, 36)
				elseif p.X > 110 then
					d.Material = Enum.Material.Carpet -- tape room
					d.Color = Color3.fromRGB(60, 58, 70)
				elseif p.Z < -60 then
					d.Material = Enum.Material.CeramicTiles -- operator room
					d.Color = Color3.fromRGB(150, 156, 156)
				end
			end
		end
	end
	MapDress.Flicker(model, 0.2, 44)
	MapDress.Surfaces(model, "church", Textures)
	MapDress.Grime(model, 404, 0.45)
	return kit.finish()
end

function Map.BuildTerrain(model: Instance?)
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -5.1, 60), Vector3.new(900, 10, 900), Enum.Material.Grass)
	-- the hill over the bunker (the rooms have their own roofs at y 15): top layer plus
	-- flanks around the footprint x 34..140, z -90..0 (left open towards the sacristy)
	terrain:FillBlock(CFrame.new(98, 26, -46), Vector3.new(140, 20, 120), Enum.Material.Grass)
	terrain:FillBlock(CFrame.new(155, 14, -46), Vector3.new(30, 30, 120), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(98, 14, -100), Vector3.new(140, 30, 18), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(105, 8, 8), Vector3.new(90, 18, 14), Enum.Material.Grass)
	terrain:FillBlock(CFrame.new(50, 8, -50), Vector3.new(18, 18, 52), Enum.Material.Rock)
	terrain:FillWedge(CFrame.new(98, 23, 28) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(140, 14, 26), Enum.Material.Grass)
	local patches = Random.new(23)
	for _ = 1, 24 do
		local x, z = patches:NextNumber(-380, 380), patches:NextNumber(-300, 420)
		if not (x > -70 and x < 175 and z > -110 and z < 140) and math.abs(x) > 8 then
			terrain:FillBall(Vector3.new(x, -2.4, z), patches:NextNumber(10, 24), if patches:NextNumber() < 0.5 then Enum.Material.LeafyGrass else Enum.Material.Ground)
		end
	end
	MapKit.ApplyClouds("chapel")
	MapDress.TerrainLook({
		Grass = Color3.fromRGB(58, 68, 52),
		LeafyGrass = Color3.fromRGB(52, 62, 46),
		Ground = Color3.fromRGB(72, 64, 54),
		Mud = Color3.fromRGB(52, 46, 40),
		Rock = Color3.fromRGB(92, 92, 90),
	})
	MapKit.RemovePreview(model)
end

function Map.ApplyLighting()
	MapKit.ApplyLighting("chapel")
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
