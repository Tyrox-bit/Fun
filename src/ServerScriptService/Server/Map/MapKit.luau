-- MapKit: shared building blocks for script-built maps (Staumauer 3, Kapelle, Mine).
-- Every gameplay object follows docs/MAP_CONTRACT.md (tags + attributes), so any piece
-- can later be replaced by a hand-built Studio model.
--
--   local kit = MapKit.new("FZ_Dam03", "Dam03", 303)
--   kit.room(...); kit.door(...); kit.checkpoint(...)
--   return kit.finish()
--
-- Positions are world positions; walls/rooms take an optional floor height `y`.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapKit = {}

type WallOptions = { y: number?, h: number?, doorH: number?, color: Color3?, material: Enum.Material?, t: number? }

MapKit.C = {
	Concrete = Color3.fromRGB(104, 104, 100),
	ConcreteDark = Color3.fromRGB(64, 66, 66),
	Floor = Color3.fromRGB(78, 74, 66),
	Steel = Color3.fromRGB(64, 84, 82),
	SteelDark = Color3.fromRGB(42, 48, 50),
	Wood = Color3.fromRGB(82, 62, 44),
	WoodDark = Color3.fromRGB(52, 38, 28),
	Plastic = Color3.fromRGB(190, 184, 170),
	Paper = Color3.fromRGB(226, 220, 204),
	Sodium = Color3.fromRGB(255, 170, 96),
	Fluorescent = Color3.fromRGB(214, 236, 230),
	Warm = Color3.fromRGB(255, 206, 150),
	Candle = Color3.fromRGB(255, 176, 92),
	Emergency = Color3.fromRGB(200, 40, 30),
	Screen = Color3.fromRGB(90, 220, 140),
	Asphalt = Color3.fromRGB(36, 38, 40),
	Pine = Color3.fromRGB(28, 44, 34),
	Bark = Color3.fromRGB(52, 40, 32),
	Rock = Color3.fromRGB(70, 66, 62),
	RockDark = Color3.fromRGB(46, 43, 40),
	Stone = Color3.fromRGB(124, 120, 112),
	Hazard = Color3.fromRGB(214, 170, 40),
}
local C = MapKit.C

-- Lighting presets. Every preset sets the full property list, so switching maps never
-- leaves a property of the previous map behind.
MapKit.Lighting = {
	storm = {
		ClockTime = 0.2, Brightness = 1.2, ExposureCompensation = 0.4,
		Ambient = Color3.fromRGB(36, 40, 48), OutdoorAmbient = Color3.fromRGB(70, 80, 96),
		ColorShift_Top = Color3.fromRGB(120, 140, 170), ColorShift_Bottom = Color3.fromRGB(18, 20, 26),
		EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 1, ShadowSoftness = 0.3,
		Atmosphere = { Density = 0.38, Offset = 0.02, Color = Color3.fromRGB(120, 132, 150), Decay = Color3.fromRGB(56, 64, 80), Glare = 0, Haze = 2.2 },
		Sky = { StarCount = 0, MoonAngularSize = 0, CelestialBodiesShown = false },
		Clouds = { Cover = 0.9, Density = 0.75, Color = Color3.fromRGB(46, 52, 62) },
	},
	chapel = {
		ClockTime = 23.2, Brightness = 1.4, ExposureCompensation = 0.35,
		Ambient = Color3.fromRGB(40, 40, 46), OutdoorAmbient = Color3.fromRGB(84, 90, 108),
		ColorShift_Top = Color3.fromRGB(170, 175, 200), ColorShift_Bottom = Color3.fromRGB(22, 22, 28),
		EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.8, ShadowSoftness = 0.25,
		Atmosphere = { Density = 0.42, Offset = 0.1, Color = Color3.fromRGB(150, 156, 170), Decay = Color3.fromRGB(80, 84, 100), Glare = 0.1, Haze = 2.6 },
		Sky = { StarCount = 1500, MoonAngularSize = 18, CelestialBodiesShown = true },
		Clouds = { Cover = 0.5, Density = 0.35, Color = Color3.fromRGB(80, 86, 100) },
	},
	mine = {
		ClockTime = 4.6, Brightness = 1.3, ExposureCompensation = 0.3,
		Ambient = Color3.fromRGB(34, 32, 30), OutdoorAmbient = Color3.fromRGB(80, 86, 104),
		ColorShift_Top = Color3.fromRGB(160, 150, 140), ColorShift_Bottom = Color3.fromRGB(22, 20, 18),
		EnvironmentDiffuseScale = 0.55, EnvironmentSpecularScale = 0.9, ShadowSoftness = 0.2,
		Atmosphere = { Density = 0.3, Offset = 0.05, Color = Color3.fromRGB(140, 140, 150), Decay = Color3.fromRGB(70, 72, 86), Glare = 0.1, Haze = 1.4 },
		Sky = { StarCount = 2500, MoonAngularSize = 10, CelestialBodiesShown = true },
		Clouds = { Cover = 0.4, Density = 0.3, Color = Color3.fromRGB(70, 76, 90) },
	},
	dawn = {
		ClockTime = 6.4, Brightness = 2, ExposureCompensation = 0.2,
		Ambient = Color3.fromRGB(70, 62, 60), OutdoorAmbient = Color3.fromRGB(150, 130, 120),
		ColorShift_Top = Color3.fromRGB(255, 200, 160), ColorShift_Bottom = Color3.fromRGB(40, 34, 40),
		EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 1, ShadowSoftness = 0.2,
		Atmosphere = { Density = 0.3, Offset = 0.1, Color = Color3.fromRGB(230, 190, 170), Decay = Color3.fromRGB(140, 110, 120), Glare = 0.6, Haze = 1.4 },
		Sky = { StarCount = 0, MoonAngularSize = 0, CelestialBodiesShown = true },
		Clouds = { Cover = 0.45, Density = 0.3, Color = Color3.fromRGB(230, 200, 190) },
	},
	day = {
		ClockTime = 13, Brightness = 2.6, ExposureCompensation = 0,
		Ambient = Color3.fromRGB(90, 90, 92), OutdoorAmbient = Color3.fromRGB(150, 150, 150),
		ColorShift_Top = Color3.fromRGB(255, 245, 230), ColorShift_Bottom = Color3.fromRGB(60, 60, 64),
		EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, ShadowSoftness = 0.15,
		Atmosphere = { Density = 0.25, Offset = 0.05, Color = Color3.fromRGB(200, 210, 230), Decay = Color3.fromRGB(110, 130, 160), Glare = 0.3, Haze = 0.8 },
		Sky = { StarCount = 0, MoonAngularSize = 0, CelestialBodiesShown = true },
		Clouds = { Cover = 0.35, Density = 0.25, Color = Color3.fromRGB(240, 240, 245) },
	},
}

function MapKit.ApplyLighting(name: string)
	local preset = MapKit.Lighting[name]
	if not preset then
		return
	end
	for key, value in preset do
		if type(value) ~= "table" then
			(Lighting :: any)[key] = value
		end
	end
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	for key, value in preset.Atmosphere do
		(atmosphere :: any)[key] = value
	end
	atmosphere.Parent = Lighting
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	for key, value in preset.Sky do
		(sky :: any)[key] = value
	end
	sky.Parent = Lighting
end

-- Clouds live under Terrain (set together with the terrain at load time).
function MapKit.ApplyClouds(name: string)
	local preset = MapKit.Lighting[name]
	if not preset or not preset.Clouds then
		return
	end
	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	for key, value in preset.Clouds do
		(clouds :: any)[key] = value
	end
	clouds.Parent = terrain
end

-- Removes the edit-mode stand-in ground once real terrain exists.
function MapKit.RemovePreview(model: Instance?)
	if not model then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("FZ_EditPreview") then
			part:Destroy()
		end
	end
end

function MapKit.new(modelName: string, builderName: string, seed: number)
	local kit: any = {}
	local root = Instance.new("Model")
	root.Name = modelName
	root:SetAttribute("FZ_Builder", builderName)
	kit.root = root
	kit.rng = Random.new(seed)
	kit.C = C
	kit.H = 14
	kit.DOOR_H = 10
	kit.T = 1
	local rng = kit.rng

	local folders: { [string]: Folder } = {}
	function kit.folder(name: string): Folder
		if not folders[name] then
			local f = Instance.new("Folder")
			f.Name = name
			f.Parent = root
			folders[name] = f
		end
		return folders[name]
	end

	function kit.block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
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
	local block = kit.block

	function kit.deco(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
		local p = block(parent, name, size, cframe, color, material)
		p.CanCollide = false
		p.CanQuery = false
		return p
	end

	function kit.tag(instance: Instance, tagName: string, attributes: { [string]: any }?)
		for key, value in attributes or {} do
			instance:SetAttribute(key, value)
		end
		CollectionService:AddTag(instance, tagName)
	end
	local tag = kit.tag

	function kit.marker(name: string, cf: CFrame): Part
		local p = block(kit.folder("Markers"), name, Vector3.new(1, 1, 1), cf, C.Concrete)
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		return p
	end

	function kit.worldText(target: BasePart, face: Enum.NormalId, key: string?, staticText: string?, params: { [string]: string }?, color: Color3?, font: Enum.Font?)
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
		label.FontFace = Font.fromEnum(font or Enum.Font.RobotoMono)
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

	-----------------------------------------------------------------------
	-- Structure: walls with door gaps, slabs, rooms, ramps, railings
	-----------------------------------------------------------------------
	local function segments(a: number, b: number, gaps: { { number } }?): { { any } }
		local list = {}
		local cursor = a
		local sorted = table.clone(gaps or {})
		table.sort(sorted, function(x, y)
			return x[1] < y[1]
		end)
		for _, gap in sorted do
			local g0, g1 = gap[1] - gap[2] / 2, gap[1] + gap[2] / 2
			if g0 > cursor then
				table.insert(list, { cursor, g0, false })
			end
			table.insert(list, { g0, g1, true })
			cursor = g1
		end
		if cursor < b then
			table.insert(list, { cursor, b, false })
		end
		return list
	end

	-- Wall along X at constant z (gaps = { { centerX, width } }).
	function kit.wallZ(z: number, x0: number, x1: number, gaps: { { number } }?, o: WallOptions?)
		o = o or {}
		local y, h, dh, t = o.y or 0, o.h or kit.H, o.doorH or kit.DOOR_H, o.t or kit.T
		local walls = kit.folder("Walls")
		for _, s in segments(x0, x1, gaps) do
			local width, mid = s[2] - s[1], (s[1] + s[2]) / 2
			if s[3] then
				if h > dh then
					block(walls, "Lintel", Vector3.new(width, h - dh, t), CFrame.new(mid, y + dh + (h - dh) / 2, z), o.color or C.Concrete, o.material or Enum.Material.Concrete)
				end
			else
				block(walls, "Wall", Vector3.new(width, h, t), CFrame.new(mid, y + h / 2, z), o.color or C.Concrete, o.material or Enum.Material.Concrete)
			end
		end
	end

	-- Wall along Z at constant x (gaps = { { centerZ, width } }).
	function kit.wallX(x: number, z0: number, z1: number, gaps: { { number } }?, o: WallOptions?)
		o = o or {}
		local y, h, dh, t = o.y or 0, o.h or kit.H, o.doorH or kit.DOOR_H, o.t or kit.T
		local walls = kit.folder("Walls")
		for _, s in segments(z0, z1, gaps) do
			local depth, mid = s[2] - s[1], (s[1] + s[2]) / 2
			if s[3] then
				if h > dh then
					block(walls, "Lintel", Vector3.new(t, h - dh, depth), CFrame.new(x, y + dh + (h - dh) / 2, mid), o.color or C.Concrete, o.material or Enum.Material.Concrete)
				end
			else
				block(walls, "Wall", Vector3.new(t, h, depth), CFrame.new(x, y + h / 2, mid), o.color or C.Concrete, o.material or Enum.Material.Concrete)
			end
		end
	end

	function kit.slab(name: string, x0: number, z0: number, x1: number, z1: number, y: number, thickness: number, color: Color3, material: Enum.Material?): Part
		return block(kit.folder("Structure"), name, Vector3.new(x1 - x0, thickness, z1 - z0), CFrame.new((x0 + x1) / 2, y - thickness / 2, (z0 + z1) / 2), color, material or Enum.Material.Concrete)
	end

	-- A closed room: floor, roof and four walls. gaps = { n = {...}, s = {...}, w = {...}, e = {...} }
	-- (n = wall at z0, s = wall at z1, w = wall at x0, e = wall at x1)
	function kit.room(x0: number, z0: number, x1: number, z1: number, o: { y: number?, h: number?, gaps: any?, floor: Color3?, floorMaterial: Enum.Material?, wall: Color3?, wallMaterial: Enum.Material?, roof: Color3?, noRoof: boolean?, noFloor: boolean?, doorH: number? }?)
		o = o or {}
		local y, h = o.y or 0, o.h or kit.H
		local gaps = o.gaps or {}
		if not o.noFloor then
			kit.slab("Floor", x0, z0, x1, z1, y, 1, o.floor or C.Floor, o.floorMaterial or Enum.Material.Concrete)
		end
		if not o.noRoof then
			kit.slab("Roof", x0 - 0.5, z0 - 0.5, x1 + 0.5, z1 + 0.5, y + h + 1.2, 1.2, o.roof or C.ConcreteDark, Enum.Material.Concrete)
		end
		local wo = { y = y, h = h, color = o.wall, material = o.wallMaterial, doorH = o.doorH }
		kit.wallZ(z0, x0, x1, gaps.n, wo)
		kit.wallZ(z1, x0, x1, gaps.s, wo)
		kit.wallX(x0, z0, z1, gaps.w, wo)
		kit.wallX(x1, z0, z1, gaps.e, wo)
	end

	-- Sloped walkway from bottom centre `a` to top centre `b` (top surface walkable).
	function kit.ramp(a: Vector3, b: Vector3, width: number, color: Color3?, material: Enum.Material?): Part
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.5, 0)
		return block(kit.folder("Structure"), "Ramp", Vector3.new(width, 1, length), cf, color or C.Concrete, material or Enum.Material.Concrete)
	end

	function kit.railing(a: Vector3, b: Vector3, color: Color3?)
		local f = kit.folder("Railings")
		local length = (b - a).Magnitude
		local count = math.max(1, math.floor(length / 4))
		for i = 0, count do
			local p = a:Lerp(b, i / count)
			block(f, "Post", Vector3.new(0.25, 3.6, 0.25), CFrame.new(p + Vector3.new(0, 1.8, 0)), color or C.SteelDark, Enum.Material.Metal)
		end
		block(f, "Rail", Vector3.new(0.3, 0.3, length), CFrame.lookAt((a + b) / 2 + Vector3.new(0, 3.6, 0), b + Vector3.new(0, 3.6, 0)), color or C.SteelDark, Enum.Material.Metal)
		local mid = block(f, "Rail", Vector3.new(0.18, 0.18, length), CFrame.lookAt((a + b) / 2 + Vector3.new(0, 1.9, 0), b + Vector3.new(0, 1.9, 0)), color or C.SteelDark, Enum.Material.Metal)
		mid.CanCollide = false
		-- invisible barrier so nobody falls off by accident (players and the creature)
		local guard = block(f, "Guard", Vector3.new(0.4, 6, length), CFrame.lookAt((a + b) / 2 + Vector3.new(0, 3, 0), b + Vector3.new(0, 3, 0)), C.Concrete)
		guard.Transparency = 1
	end

	-----------------------------------------------------------------------
	-- Doors (same contract as Relay 07: FZ_Door + FZ_Interactable "door")
	-----------------------------------------------------------------------
	local doorCount = 0
	function kit.door(center: Vector3, alongX: boolean, width: number, locked: boolean?, sector: string?, o: { doorH: number?, color: Color3?, material: Enum.Material?, prefix: string? }?)
		o = o or {}
		doorCount += 1
		local doors = kit.folder("Doors")
		local dh = o.doorH or kit.DOOR_H
		local y = center.Y
		local size = if alongX then Vector3.new(width, dh, 0.6) else Vector3.new(0.6, dh, width)
		local closed = CFrame.new(center.X, y + dh / 2, center.Z)
		local slide = if alongX then Vector3.new(width - 0.4, 0, 0) else Vector3.new(0, 0, width - 0.4)
		local panel = block(doors, "Door" .. doorCount, size, closed, o.color or C.Steel, o.material or Enum.Material.Metal)
		local along = if alongX then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
		for _, sideSign in { -1, 1 } do
			local postPos = Vector3.new(center.X, y + dh / 2, center.Z) + along * sideSign * (width / 2 + 0.35)
			block(doors, "DoorFrame", if alongX then Vector3.new(0.7, dh, 1.6) else Vector3.new(1.6, dh, 0.7), CFrame.new(postPos), C.SteelDark, Enum.Material.Metal)
		end
		block(doors, "DoorHeader", if alongX then Vector3.new(width + 1.4, 0.9, 1.6) else Vector3.new(1.6, 0.9, width + 1.4), CFrame.new(center.X, y + dh + 0.45, center.Z), C.SteelDark, Enum.Material.Metal)
		local stripe = block(panel, "Stripe", if alongX then Vector3.new(width, 0.4, 0.7) else Vector3.new(0.7, 0.4, width), closed * CFrame.new(0, 1.5 - dh / 2 + 5, 0), if locked then C.Emergency else C.Plastic, Enum.Material.Neon)
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
			DoorId = (o.prefix or "M") .. doorCount,
			Open = false,
			Locked = locked == true,
			PowerSector = sector or "",
			ClosedCFrame = closed,
			OpenCFrame = closed + slide,
		})
		tag(panel, "FZ_Interactable", { InteractId = "door", ActionKey = "INTERACT_OPEN", ObjectKey = "OBJECT_DOOR", MaxDistance = 9 })
		return panel
	end

	-----------------------------------------------------------------------
	-- Lights
	-----------------------------------------------------------------------
	local perSector: { [string]: number } = {}
	function kit.ceilingLight(position: Vector3, sector: string, color: Color3?, shadows: boolean?, forceKey: boolean?, height: number?)
		perSector[sector] = (perSector[sector] or 0) + 1
		local key = forceKey or perSector[sector] <= 2
		local h = height or (position.Y + kit.H)
		local lights = kit.folder("Lights")
		local housing = block(lights, "LampHousing", Vector3.new(6.6, 0.45, 1.6), CFrame.new(position.X, h - 0.25, position.Z), C.SteelDark, Enum.Material.Metal)
		housing.CanCollide = false
		local fixture = block(lights, "Fixture_" .. sector, Vector3.new(6, 0.15, 1.1), CFrame.new(position.X, h - 0.52, position.Z), color or C.Fluorescent, Enum.Material.Neon)
		fixture.CanCollide = false
		fixture.CastShadow = false
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 28
		light.Angle = 140
		light.Brightness = 1.9
		light.Color = color or C.Fluorescent
		light.Shadows = shadows == true
		light.Parent = fixture
		tag(fixture, "FZ_SectorLight", { Sector = sector, OnColor = color or C.Fluorescent })
		CollectionService:AddTag(fixture, if key then "FZ_KeyLight" else "FZ_DecorLight")
		return fixture
	end

	function kit.lightGrid(x0: number, x1: number, z0: number, z1: number, sector: string, color: Color3?, y: number?, h: number?)
		local nx = math.max(1, math.floor((x1 - x0) / 16))
		local nz = math.max(1, math.floor((z1 - z0) / 14))
		for ix = 1, nx do
			for iz = 1, nz do
				local x = x0 + (x1 - x0) * (ix - 0.5) / nx
				local z = z0 + (z1 - z0) * (iz - 0.5) / nz
				kit.ceilingLight(Vector3.new(x, y or 0, z), sector, color, ix == 1 and iz == 1, nil, if h then (y or 0) + h else nil)
			end
		end
	end

	-- Caged bulb / lantern: a small point light, optionally switched with a sector.
	function kit.bulb(position: Vector3, color: Color3?, range: number?, brightness: number?, sector: string?, key: boolean?)
		local lights = kit.folder("Lights")
		local bulb = block(lights, "Bulb", Vector3.new(0.6, 0.8, 0.6), CFrame.new(position), color or C.Warm, Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
		bulb.CanCollide = false
		bulb.CastShadow = false
		local cage = block(lights, "Cage", Vector3.new(0.9, 1.1, 0.9), CFrame.new(position), C.SteelDark, Enum.Material.DiamondPlate)
		cage.Transparency = 0.6
		cage.CanCollide = false
		local light = Instance.new("PointLight")
		light.Range = range or 18
		light.Brightness = brightness or 1.2
		light.Color = color or C.Warm
		light.Shadows = key == true
		light.Parent = bulb
		if sector then
			tag(bulb, "FZ_SectorLight", { Sector = sector, OnColor = color or C.Warm })
		end
		CollectionService:AddTag(bulb, if key ~= false then "FZ_KeyLight" else "FZ_DecorLight")
		return bulb
	end

	function kit.emergencyLight(position: Vector3, sector: string)
		local lamp = block(kit.folder("Lights"), "Emergency", Vector3.new(0.8, 0.5, 0.8), CFrame.new(position), C.Emergency, Enum.Material.Neon)
		lamp.CanCollide = false
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Brightness = 0.7
		light.Color = C.Emergency
		light.Parent = lamp
		CollectionService:AddTag(lamp, "FZ_KeyLight")
		lamp:SetAttribute("Sector", sector)
		return lamp
	end

	function kit.floodLight(position: Vector3, target: Vector3, color: Color3?, range: number?)
		local lights = kit.folder("Lights")
		local head = block(lights, "FloodLight", Vector3.new(1.6, 1.2, 0.8), CFrame.lookAt(position, target), color or C.Fluorescent, Enum.Material.Neon)
		head.CanCollide = false
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = range or 50
		light.Angle = 70
		light.Brightness = 2.4
		light.Color = color or C.Fluorescent
		light.Shadows = true
		light.Parent = head
		CollectionService:AddTag(head, "FZ_KeyLight")
		return head
	end

	-----------------------------------------------------------------------
	-- Props
	-----------------------------------------------------------------------
	local function props()
		return kit.folder("Props")
	end

	function kit.desk(cf: CFrame)
		block(props(), "Desk", Vector3.new(6, 0.3, 3), cf * CFrame.new(0, 3, 0), C.Wood, Enum.Material.Wood)
		for _, x in { -2.7, 2.7 } do
			block(props(), "DeskLeg", Vector3.new(0.4, 3, 2.6), cf * CFrame.new(x, 1.5, 0), C.SteelDark, Enum.Material.Metal)
		end
	end

	function kit.table_(cf: CFrame, size: Vector3?, color: Color3?)
		local s = size or Vector3.new(8, 0.3, 3.5)
		block(props(), "Table", s, cf * CFrame.new(0, 3, 0), color or C.Wood, Enum.Material.Wood)
		for _, x in { -s.X / 2 + 0.4, s.X / 2 - 0.4 } do
			for _, z in { -s.Z / 2 + 0.4, s.Z / 2 - 0.4 } do
				block(props(), "TableLeg", Vector3.new(0.3, 3, 0.3), cf * CFrame.new(x, 1.5, z), C.SteelDark, Enum.Material.Metal)
			end
		end
	end

	function kit.bench(cf: CFrame, length: number?, color: Color3?)
		local l = length or 7
		block(props(), "Bench", Vector3.new(l, 0.4, 1.4), cf * CFrame.new(0, 1.8, 0), color or C.Wood, Enum.Material.Wood)
		for _, x in { -l / 2 + 0.5, l / 2 - 0.5 } do
			block(props(), "BenchLeg", Vector3.new(0.3, 1.6, 1.2), cf * CFrame.new(x, 0.8, 0), color or C.WoodDark, Enum.Material.Wood)
		end
	end

	function kit.chair(cf: CFrame)
		block(props(), "ChairSeat", Vector3.new(1.8, 0.3, 1.8), cf * CFrame.new(0, 1.8, 0), C.SteelDark, Enum.Material.Fabric)
		block(props(), "ChairBack", Vector3.new(1.8, 2, 0.25), cf * CFrame.new(0, 2.9, 0.8), C.SteelDark, Enum.Material.Fabric)
		block(props(), "ChairLeg", Vector3.new(0.25, 1.7, 0.25), cf * CFrame.new(0, 0.85, 0), C.Steel, Enum.Material.Metal)
	end

	function kit.crate(cf: CFrame, size: number?)
		local s = size or 2.4
		block(props(), "Crate", Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), Color3.fromRGB(120, 96, 66), Enum.Material.WoodPlanks)
	end

	function kit.barrel(cf: CFrame, color: Color3?)
		local b = block(props(), "Barrel", Vector3.new(4, 2.6, 2.6), cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color or Color3.fromRGB(150, 60, 34), Enum.Material.CorrodedMetal)
		b.Shape = Enum.PartType.Cylinder
		return b
	end

	function kit.shelf(cf: CFrame)
		block(props(), "Shelf", Vector3.new(8, 9, 2), cf * CFrame.new(0, 4.5, 0), C.Wood, Enum.Material.Wood)
		for row = 1, 4 do
			block(props(), "Files", Vector3.new(7.2, 1.4, 1.6), cf * CFrame.new(0, row * 2 - 0.3, -0.1), C.Paper:Lerp(C.Wood, rng:NextNumber(0.2, 0.6)), Enum.Material.Cardboard)
		end
	end

	function kit.bunk(cf: CFrame)
		for _, y in { 1.6, 5.2 } do
			block(props(), "Bed", Vector3.new(4, 0.8, 8), cf * CFrame.new(0, y, 0), C.Plastic:Lerp(C.Steel, 0.5), Enum.Material.Fabric)
		end
		for _, x in { -1.9, 1.9 } do
			for _, z in { -3.8, 3.8 } do
				block(props(), "BunkPost", Vector3.new(0.3, 6.4, 0.3), cf * CFrame.new(x, 3.2, z), C.SteelDark, Enum.Material.Metal)
			end
		end
	end

	function kit.locker(cf: CFrame)
		block(props(), "Locker", Vector3.new(2, 7, 2), cf * CFrame.new(0, 3.5, 0), C.Steel:Lerp(C.Plastic, 0.2), Enum.Material.Metal)
	end

	function kit.cabinet(cf: CFrame)
		block(props(), "Cabinet", Vector3.new(3, 7, 2), cf * CFrame.new(0, 3.5, 0), C.Steel, Enum.Material.Metal)
	end

	function kit.console(cf: CFrame, screenColor: Color3?): { BasePart }
		block(props(), "Console", Vector3.new(7, 3.4, 2.4), cf * CFrame.new(0, 1.7, 0), C.SteelDark, Enum.Material.Metal)
		block(props(), "ConsoleTop", Vector3.new(7.2, 0.3, 2.8), cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(math.rad(-12), 0, 0), C.Steel, Enum.Material.Metal)
		for i = -3, 3 do
			local led = block(props(), "Led", Vector3.new(0.18, 0.18, 0.05), cf * CFrame.new(i * 0.6, 2.6, -1.22), if i % 3 == 0 then C.Emergency else C.Screen, Enum.Material.Neon)
			led.CanCollide = false
		end
		local screens = {}
		for i = -1, 1 do
			local monitor = block(props(), "Monitor", Vector3.new(2, 1.7, 1.6), cf * CFrame.new(i * 2.25, 4.7, 0.5), Color3.fromRGB(58, 56, 52), Enum.Material.SmoothPlastic)
			local glass = block(props(), "Screen", Vector3.new(1.6, 1.2, 0.05), monitor.CFrame * CFrame.new(0, 0.05, -0.82), screenColor or C.Screen, Enum.Material.Neon)
			glass.Transparency = 0.2
			glass.CanCollide = false
			local glow = Instance.new("SurfaceLight")
			glow.Face = Enum.NormalId.Front
			glow.Range = 7
			glow.Brightness = 0.6
			glow.Angle = 90
			glow.Color = screenColor or C.Screen
			glow.Parent = glass
			table.insert(screens, glass)
		end
		return screens
	end

	function kit.serverRack(cf: CFrame)
		local rack = block(props(), "ServerRack", Vector3.new(3, 9, 3), cf * CFrame.new(0, 4.5, 0), Color3.fromRGB(28, 30, 32), Enum.Material.Metal)
		for row = 0, 7 do
			for k = 0, 2 do
				local led = block(props(), "RackLed", Vector3.new(0.14, 0.14, 0.05), rack.CFrame * CFrame.new(-1 + k * 0.25, -3.6 + row * 1.05, -1.55), if (row + k) % 4 == 0 then Color3.fromRGB(255, 170, 60) else C.Screen, Enum.Material.Neon)
				led.CanCollide = false
			end
		end
		return rack
	end

	function kit.deskLamp(cf: CFrame)
		block(props(), "LampBase", Vector3.new(0.6, 0.15, 0.6), cf, C.SteelDark, Enum.Material.Metal)
		local head = block(props(), "LampHead", Vector3.new(0.7, 0.35, 0.5), cf * CFrame.new(-0.3, 1.25, 0), Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
		head.CanCollide = false
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 12
		light.Angle = 100
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(255, 205, 140)
		light.Parent = head
		CollectionService:AddTag(head, "FZ_DecorLight")
	end

	function kit.candle(position: Vector3, key: boolean?)
		local wax = block(props(), "Candle", Vector3.new(0.3, 0.9, 0.3), CFrame.new(position + Vector3.new(0, 0.45, 0)), Color3.fromRGB(230, 224, 200), Enum.Material.SmoothPlastic)
		wax.CanCollide = false
		local flame = block(props(), "Flame", Vector3.new(0.18, 0.3, 0.18), CFrame.new(position + Vector3.new(0, 1.05, 0)), C.Candle, Enum.Material.Neon)
		flame.Shape = Enum.PartType.Ball
		flame.CanCollide = false
		flame.CastShadow = false
		local light = Instance.new("PointLight")
		light.Range = 9
		light.Brightness = 0.9
		light.Color = C.Candle
		light.Parent = flame
		CollectionService:AddTag(flame, if key then "FZ_KeyLight" else "FZ_DecorLight")
		return flame
	end

	function kit.papers(cf: CFrame)
		for i = 1, 3 do
			local sheet = block(props(), "Paper", Vector3.new(0.9, 0.02, 1.2), cf * CFrame.new(i * 0.35, 0.01 * i, 0) * CFrame.Angles(0, math.rad(i * 17), 0), C.Paper, Enum.Material.SmoothPlastic)
			sheet.CanCollide = false
		end
	end

	function kit.generator(cf: CFrame, id: number)
		local body = block(props(), "Generator", Vector3.new(8, 6, 5), cf * CFrame.new(0, 3, 0), C.Steel:Lerp(C.Emergency, 0.15), Enum.Material.Metal)
		local drum = block(props(), "Drum", Vector3.new(7, 4, 4), cf * CFrame.new(0, 7.5, 0), C.SteelDark, Enum.Material.Metal)
		drum.Shape = Enum.PartType.Cylinder
		body:SetAttribute("SoundLoop", "generator_loop")
		CollectionService:AddTag(body, "FZ_AmbientSource")
		kit.interactable(body, "generator", "INTERACT_RESTART", "OBJECT_GENERATOR", { HoldDuration = 3, MaxDistance = 9, GeneratorId = id })
		return body
	end

	function kit.pipeRun(from: Vector3, to: Vector3, radius: number?, color: Color3?)
		local length = (to - from).Magnitude
		local pipe = block(props(), "Pipe", Vector3.new(length, (radius or 0.6) * 2, (radius or 0.6) * 2), CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0), color or C.SteelDark, Enum.Material.Metal)
		pipe.Shape = Enum.PartType.Cylinder
		pipe.CanCollide = false
		return pipe
	end

	function kit.sign(position: Vector3, facing: Vector3, key: string?, text: string?, size: Vector3?)
		local plate = block(props(), "Sign", size or Vector3.new(8, 2.4, 0.2), CFrame.lookAt(position, position + facing), C.Plastic, Enum.Material.SmoothPlastic)
		plate.CanCollide = false
		kit.worldText(plate, Enum.NormalId.Front, key, text)
		return plate
	end

	function kit.vent(position: Vector3, facing: Vector3, group: string)
		local grate = block(props(), "Vent", Vector3.new(3, 2, 0.3), CFrame.lookAt(position, position + facing), C.SteelDark, Enum.Material.DiamondPlate)
		grate.CanCollide = false
		tag(grate, "FZ_Vent", { VentGroup = group })
	end

	function kit.patrol(position: Vector3, area: string)
		tag(kit.marker("PatrolNode", CFrame.new(position.X, position.Y + 3, position.Z)), "FZ_CreaturePatrol", { Area = area })
	end

	function kit.fuseSpot(cf: CFrame, sector: string)
		tag(kit.marker("FuseSpot", cf), "FZ_FuseSpot", { Sector = sector })
	end

	function kit.checkpoint(id: string, cf: CFrame)
		local p = kit.marker("CP_" .. id, cf)
		p.Size = Vector3.new(4, 1, 4)
		tag(p, "FZ_Checkpoint", { CheckpointId = id })
	end

	function kit.itemSpot(cf: CFrame)
		CollectionService:AddTag(kit.marker("ItemSpot", cf), "FZ_ItemSpot")
	end

	function kit.creatureSpawn(cf: CFrame)
		CollectionService:AddTag(kit.marker("CreatureSpawn", cf), "FZ_CreatureSpawn")
	end

	function kit.menuCamera(index: number, from: Vector3, to: Vector3, drift: number?)
		local cam = kit.marker("MenuCamera" .. index, CFrame.lookAt(from, to))
		cam:SetAttribute("Shot", index)
		cam:SetAttribute("Drift", drift or 6)
		CollectionService:AddTag(cam, "FZ_MenuCamera")
	end

	function kit.interactable(part: BasePart, id: string, action: string, object: string, extra: { [string]: any }?)
		local attributes = { InteractId = id, ActionKey = action, ObjectKey = object }
		for key, value in extra or {} do
			attributes[key] = value
		end
		tag(part, "FZ_Interactable", attributes)
		return part
	end

	-- Wall-mounted panel (breaker, override, valve ...) that is used by holding it.
	function kit.panel(cf: CFrame, id: string, action: string, object: string, extra: { [string]: any }?, color: Color3?)
		local box = block(props(), "Panel_" .. id, Vector3.new(3, 4, 0.8), cf, color or C.Steel:Lerp(C.Emergency, 0.25), Enum.Material.Metal)
		local lamp = block(props(), "PanelLamp", Vector3.new(0.4, 0.4, 0.1), cf * CFrame.new(1.1, 1.6, -0.45), C.Emergency, Enum.Material.Neon)
		lamp.CanCollide = false
		local attributes = { MaxDistance = 8 }
		for key, value in extra or {} do
			attributes[key] = value
		end
		kit.interactable(box, id, action, object, attributes)
		return box
	end

	-- Hand wheel (valves, winches): a ring on a post.
	function kit.wheel(cf: CFrame, id: string, action: string, object: string, extra: { [string]: any }?)
		local post = block(props(), "WheelPost", Vector3.new(0.8, 3.6, 0.8), cf * CFrame.new(0, 1.8, 0), C.SteelDark, Enum.Material.Metal)
		local ring = block(props(), "Wheel", Vector3.new(0.3, 3, 3), cf * CFrame.new(0, 3.8, 0) * CFrame.Angles(0, math.rad(90), 0), C.Emergency:Lerp(C.SteelDark, 0.3), Enum.Material.Metal)
		ring.Shape = Enum.PartType.Cylinder
		local attributes = { MaxDistance = 8, HoldDuration = 3 }
		for key, value in extra or {} do
			attributes[key] = value
		end
		kit.interactable(post, id, action, object, attributes)
		return post
	end

	-- One of the two keys of a security lock (survival task "keys"): yellow/black housing,
	-- a key with a lamp. Index 1 and 2 belong together.
	function kit.syncKey(cf: CFrame, index: number)
		local box = block(props(), "SyncKey" .. index, Vector3.new(2.4, 3, 0.8), cf, C.Hazard, Enum.Material.Metal)
		for i = 0, 3 do
			local stripe = block(props(), "SyncStripe", Vector3.new(0.35, 3.1, 0.05), box.CFrame * CFrame.new(-0.9 + i * 0.6, 0, -0.42) * CFrame.Angles(0, 0, math.rad(30)), C.SteelDark, Enum.Material.SmoothPlastic)
			stripe.CanCollide = false
		end
		local lamp = block(props(), "SyncLamp", Vector3.new(0.5, 0.5, 0.2), box.CFrame * CFrame.new(0, 1.9, -0.3), C.Emergency, Enum.Material.Neon)
		lamp.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Range = 6
		glow.Brightness = 0.8
		glow.Color = C.Emergency
		glow.Parent = lamp
		kit.interactable(box, "sync_key", "INTERACT_TURN_KEY", "OBJECT_SYNC_KEY", { MaxDistance = 8, KeyIndex = index })
		return box
	end

	-- Small box used as a survival station / relay target.
	function kit.station(cf: CFrame, id: string, object: string?)
		local box = block(props(), "Station_" .. id, Vector3.new(2, 3, 2), cf, C.Steel, Enum.Material.Metal)
		local screen = block(props(), "StationScreen", Vector3.new(1.4, 0.9, 0.05), box.CFrame * CFrame.new(0, 0.7, -1.03), C.Screen, Enum.Material.Neon)
		screen.CanCollide = false
		kit.interactable(box, id, "INTERACT_ACTIVATE", object or "OBJECT_STATION", { MaxDistance = 8 })
		return box
	end

	function kit.firstAid(cf: CFrame)
		local cabinet = block(props(), "FirstAid", Vector3.new(2.6, 3.2, 0.9), cf, Color3.fromRGB(226, 224, 216), Enum.Material.SmoothPlastic)
		for _, size in { Vector3.new(0.4, 1.4, 0.05), Vector3.new(1.4, 0.4, 0.05) } do
			local cross = block(props(), "Cross", size, cabinet.CFrame * CFrame.new(0, 0.2, -0.47), Color3.fromRGB(190, 40, 34), Enum.Material.Neon)
			cross.CanCollide = false
		end
		kit.interactable(cabinet, "medcabinet", "INTERACT_TAKE_MEDKIT", "OBJECT_MEDCABINET", { MaxDistance = 7 })
		CollectionService:AddTag(cabinet, "FZ_MedCabinet")
		return cabinet
	end

	function kit.speaker(position: Vector3, facing: Vector3)
		local speaker = block(props(), "Speaker", Vector3.new(1.4, 1.4, 1.6), CFrame.lookAt(position, position + facing), C.SteelDark, Enum.Material.Metal)
		speaker.CanCollide = false
		CollectionService:AddTag(speaker, "FZ_Speaker")
	end

	-- Archive find: a tape recorder that unlocks a lore entry (LoreService "lore" handler).
	function kit.recorder(cf: CFrame, logId: string)
		local recorder = block(props(), "Recorder", Vector3.new(1.4, 0.6, 1), cf, Color3.fromRGB(48, 44, 40), Enum.Material.SmoothPlastic)
		local reel = block(props(), "Reel", Vector3.new(0.1, 0.5, 0.5), cf * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Plastic, Enum.Material.SmoothPlastic)
		reel.Shape = Enum.PartType.Cylinder
		reel.CanCollide = false
		local led = Instance.new("PointLight")
		led.Range = 3
		led.Brightness = 0.6
		led.Color = Color3.fromRGB(255, 120, 60)
		led.Parent = recorder
		kit.interactable(recorder, "lore", "INTERACT_LISTEN", "OBJECT_RECORDER", { MaxDistance = 7, LogId = logId })
		return recorder
	end

	-- Readable document lying somewhere (lore handler, opens the archive entry).
	function kit.document(cf: CFrame, logId: string, objectKey: string?)
		local sheet = block(props(), "Document", Vector3.new(1.1, 0.06, 1.4), cf, C.Paper, Enum.Material.SmoothPlastic)
		sheet.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Range = 3
		glow.Brightness = 0.35
		glow.Color = C.Warm
		glow.Parent = sheet
		kit.interactable(sheet, "lore", "INTERACT_READ", objectKey or "OBJECT_DOCUMENT", { MaxDistance = 7, LogId = logId })
		return sheet
	end

	-----------------------------------------------------------------------
	-- Outdoor
	-----------------------------------------------------------------------
	function kit.tree(parent: Instance, position: Vector3, scale: number, dead: boolean?)
		local height = 30 * scale
		local model = Instance.new("Model")
		model.Name = if dead then "DeadTree" else "Pine"
		model.Parent = parent
		local trunk = block(model, "Trunk", Vector3.new(height, 1.3 * scale, 1.3 * scale), CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), C.Bark, Enum.Material.Wood)
		trunk.Shape = Enum.PartType.Cylinder
		if dead then
			for i = 1, 4 do
				local y = height * (0.45 + i * 0.1)
				local branch = block(model, "Branch", Vector3.new(0.35 * scale, 0.35 * scale, 7 * scale * (1.1 - i * 0.15)), CFrame.new(position + Vector3.new(0, y, 0)) * CFrame.Angles(math.rad(-25), rng:NextNumber(0, 6.28), 0) * CFrame.new(0, 0, -3 * scale), C.Bark, Enum.Material.Wood)
				branch.CanCollide = false
			end
			return model
		end
		local tint = rng:NextNumber(-0.12, 0.12)
		local needleColor = Color3.new(math.clamp(C.Pine.R + tint * 0.3, 0, 1), math.clamp(C.Pine.G + tint * 0.4, 0, 1), math.clamp(C.Pine.B + tint * 0.3, 0, 1))
		for i = 0, 5 do
			local t = i / 5
			local radius = (7.5 - t * 5.8) * scale
			local layer = block(model, "Needles", Vector3.new(1, 1, 1), CFrame.new(position + Vector3.new(0, height * (0.28 + t * 0.66), 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), needleColor, Enum.Material.Grass)
			layer.CanCollide = false
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Scale = Vector3.new(radius * 2, 4.2 * scale, radius * 2)
			mesh.Parent = layer
		end
		return model
	end

	-- Scatter trees in a ring, skipping excluded rectangles { {x0, z0, x1, z1} }.
	function kit.forest(count: number, x0: number, x1: number, z0: number, z1: number, exclude: { { number } }, deadShare: number?)
		local forest = kit.folder("Forest")
		local placed, tries = 0, 0
		while placed < count and tries < count * 20 do
			tries += 1
			local x = rng:NextNumber(x0, x1)
			local z = rng:NextNumber(z0, z1)
			local blocked = false
			for _, r in exclude do
				if x > r[1] and x < r[3] and z > r[2] and z < r[4] then
					blocked = true
					break
				end
			end
			if not blocked then
				kit.tree(forest, Vector3.new(x, 0, z), rng:NextNumber(0.8, 1.35), rng:NextNumber() < (deadShare or 0))
				placed += 1
			end
		end
	end

	function kit.rock(position: Vector3, size: number)
		return block(kit.folder("Rocks"), "Rock", Vector3.new(size * 1.4, size * 0.8, size), CFrame.new(position + Vector3.new(0, size * 0.25, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), C.Rock, Enum.Material.Slate)
	end

	function kit.spawnLocation(cf: CFrame)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "FZ_Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = cf
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = kit.folder("Markers")
		local decal = spawn:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
	end

	-- Flat stand-in ground for Studio's edit mode (removed when terrain is filled).
	function kit.previewGround(center: Vector3, size: Vector3, color: Color3?)
		local p = block(kit.folder("Outside"), "EditPreviewGround", size, CFrame.new(center), color or Color3.fromRGB(46, 58, 40), Enum.Material.Grass)
		p:SetAttribute("FZ_EditPreview", true)
		return p
	end

	function kit.finish(): Model
		root.Parent = workspace
		return root
	end

	return kit
end

return MapKit
