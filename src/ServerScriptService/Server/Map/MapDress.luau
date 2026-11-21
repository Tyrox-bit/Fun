-- MapDress: a visual finishing pass for script-built maps. Runs after a builder, adds no
-- gameplay. Only built-in materials/textures - no uploaded assets needed.
--   * two-tone walls with dado rail + skirting (institutional paint)
--   * fake volumetric light cones under outdoor lamps and flood lights (Beams)
--   * ground mist and steam (ParticleEmitters, built-in smoke texture)
--   * puddles (reflective, wet look in the storm)
--   * a few flickering fluorescent tubes (client side, see AtmosphereController)
--   * terrain look: grass blades, muted material colours
-- Clients scale or switch the effects off per graphics profile (tags FZ_LightCone, FZ_Mist).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapDress = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function folderIn(model: Instance, name: string): Folder
	local f = model:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = model
	end
	return f :: Folder
end

---------------------------------------------------------------------------
-- Walls: lower paint band, dado rail and skirting on both faces of every wall segment
---------------------------------------------------------------------------
export type WallStyle = { lower: Color3, rail: Color3, skirting: Color3, height: number?, minLength: number?, material: Enum.Material?, skip: { Enum.Material }? }

function MapDress.Walls(model: Instance, style: WallStyle, folderName: string?)
	local walls = model:FindFirstChild(folderName or "Walls")
	if not walls then
		return
	end
	local out = folderIn(model, "WallTrim")
	local band = style.height or 4.2
	for _, wall in walls:GetChildren() do
		if wall:IsA("BasePart") and wall.Name == "Wall" and not table.find(style.skip or {}, wall.Material) then
			local size = wall.Size
			local alongX = size.X >= size.Z
			local length = if alongX then size.X else size.Z
			local thickness = if alongX then size.Z else size.X
			if length >= (style.minLength or 2) and size.Y >= 6 then
				local bottom = wall.CFrame.Position.Y - size.Y / 2
				for _, side in { -1, 1 } do
					local offset = side * (thickness / 2 + 0.06)
					local function strip(name: string, height: number, y: number, depth: number, color: Color3, material: Enum.Material)
						local s = if alongX then Vector3.new(length, height, depth) else Vector3.new(depth, height, length)
						local center = wall.CFrame.Position
						local pos = if alongX then Vector3.new(center.X, bottom + y, center.Z + offset) else Vector3.new(center.X + offset, bottom + y, center.Z)
						part(out, name, s, CFrame.new(pos), color, material)
					end
					strip("PaintBand", band, band / 2, 0.08, style.lower, style.material or Enum.Material.Plaster)
					strip("DadoRail", 0.22, band + 0.05, 0.18, style.rail, Enum.Material.Wood)
					strip("Skirting", 0.5, 0.25, 0.2, style.skirting, Enum.Material.SmoothPlastic)
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Light cones: a soft, additive beam from a lamp along its light direction
---------------------------------------------------------------------------
local function cone(lamp: BasePart, direction: Vector3, length: number, spread: number, color: Color3, strength: number?)
	local a0 = Instance.new("Attachment")
	a0.Name = "ConeStart"
	a0.Parent = lamp
	local a1 = Instance.new("Attachment")
	a1.Name = "ConeEnd"
	a1.Parent = lamp
	-- attachments live in the lamp's space
	a1.Position = lamp.CFrame:PointToObjectSpace(lamp.CFrame.Position + direction.Unit * length)
	local beam = Instance.new("Beam")
	beam.Name = "LightCone"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 1.2
	beam.Width1 = math.clamp(spread, 4, 26)
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Texture = ""
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(color)
	local s = strength or 0.82
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, s),
		NumberSequenceKeypoint.new(0.6, math.min(1, s + 0.1)),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = lamp
	CollectionService:AddTag(beam, "FZ_LightCone")
	return beam
end

-- Every SpotLight on a lamp whose name is in `names` gets a cone in its light direction.
function MapDress.LightCones(model: Instance, names: { string }, maxLength: number?)
	for _, lamp in model:GetDescendants() do
		if lamp:IsA("BasePart") and table.find(names, lamp.Name) then
			local light = lamp:FindFirstChildWhichIsA("SpotLight")
			if light then
				local cf = lamp.CFrame
				local direction = if light.Face == Enum.NormalId.Bottom then -cf.UpVector
					elseif light.Face == Enum.NormalId.Front then cf.LookVector
					elseif light.Face == Enum.NormalId.Top then cf.UpVector
					else -cf.UpVector
				local length = math.min(maxLength or 34, light.Range * 0.8)
				if direction.Y < -0.5 then
					length = math.min(length, cf.Position.Y + 0.5) -- down to the ground
				end
				local spread = length * math.tan(math.rad(math.min(light.Angle, 100) / 2)) * 1.4
				cone(lamp, direction, length, spread, light.Color, if direction.Y < -0.5 then 0.8 else 0.86)
			end
		end
	end
end

-- Moonlight through a window: a long pale shaft from outside down into the room.
function MapDress.Shaft(lamp: BasePart, to: Vector3, width: number, color: Color3)
	local direction = to - lamp.CFrame.Position
	cone(lamp, direction, direction.Magnitude, width, color, 0.9)
end

---------------------------------------------------------------------------
-- Mist, steam, puddles
---------------------------------------------------------------------------
-- Low drifting ground mist over an area (one emitter part per call).
function MapDress.Mist(model: Instance, center: Vector3, size: Vector3, color: Color3?, density: number?)
	local holder = part(folderIn(model, "Atmosphere"), "MistArea", Vector3.new(size.X, 1, size.Z), CFrame.new(center + Vector3.new(0, 0.6, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Mist"
	emitter.Texture = SMOKE
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(170, 180, 195))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 18) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.88),
		NumberSequenceKeypoint.new(0.7, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(14, 22)
	emitter.Rate = (density or 1) * math.clamp(size.X * size.Z / 900, 0.5, 6)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 10)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-6, 6)
	emitter.LightInfluence = 0.8
	emitter.LightEmission = 0
	emitter.Acceleration = Vector3.new(0.3, 0, 0.15)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter:SetAttribute("BaseRate", emitter.Rate)
	emitter.Parent = holder
	CollectionService:AddTag(emitter, "FZ_Mist")
	return holder
end

-- A thin column of steam (pipes, shafts, the Array).
function MapDress.Steam(model: Instance, position: Vector3, direction: Vector3?, color: Color3?)
	local holder = part(folderIn(model, "Atmosphere"), "SteamSource", Vector3.new(0.6, 0.6, 0.6), CFrame.lookAt(position, position + (direction or Vector3.yAxis)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Steam"
	emitter.Texture = SMOKE
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(210, 214, 220))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 5) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(2.5, 4)
	emitter.Rate = 6
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.LightInfluence = 0.9
	emitter:SetAttribute("BaseRate", emitter.Rate)
	emitter.Parent = holder
	CollectionService:AddTag(emitter, "FZ_Mist")
	return holder
end

-- Flat reflective puddles at the given rectangles { { x, z, sizeX, sizeZ, y? } }.
function MapDress.Puddles(model: Instance, list: { { number } })
	local out = folderIn(model, "Puddles")
	for i, p in list do
		local puddle = part(out, "Puddle", Vector3.new(p[3], 0.04, p[4]), CFrame.new(p[1], (p[5] or 0) + 0.06, p[2]) * CFrame.Angles(0, (i * 1.7) % 3, 0), Color3.fromRGB(26, 30, 34), Enum.Material.Glass)
		puddle.Transparency = 0.25
		puddle.Reflectance = 0.35
	end
end

-- A share of decorative fluorescent fixtures flickers now and then (client side).
function MapDress.Flicker(model: Instance, share: number, seed: number)
	local rng = Random.new(seed)
	for _, fixture in model:GetDescendants() do
		if fixture:IsA("BasePart") and string.sub(fixture.Name, 1, 8) == "Fixture_" and rng:NextNumber() < share then
			CollectionService:AddTag(fixture, "FZ_Flicker")
		end
	end
end

---------------------------------------------------------------------------
-- Surfaces: photo-scanned texture variants for specific parts (part.MaterialVariant).
-- A variant only applies when its base material matches the part (else it is skipped), and
-- falls back to the base material while its images are not uploaded yet.
---------------------------------------------------------------------------
local BY_NAME = {
	Trunk = "Bark", Branch = "Bark",
	Timber = "Timber", TimberCap = "Timber", PortalBeam = "Timber", PortalPost = "Timber", Sleeper = "Timber", ShedPost = "Timber", Rafter = "Timber",
	Container = "Container", ContainerRib = "Container",
	ShedRoof = "Corrugated",
	Generator = "Machine", Drum = "Machine", TurbineHousing = "Machine", Pump = "Machine", Transformer = "Machine", WindingDrum = "Machine", Fin = "Machine",
	NaveFloor = "ChapelFloor", ApseFloor = "ChapelFloor", TowerFloor = "ChapelFloor", AltarStep = "ChapelFloor",
	Bench = "DarkWood", BenchLeg = "DarkWood", PewBack = "DarkWood", Cross = "DarkWood", CrossBar = "DarkWood", BellYoke = "DarkWood",
	Rubble = "Rubble", CollapseRubble = "Rubble", SpoilHeap = "Rubble",
	DamFront = "DamConcrete", DamBack = "DamConcrete", DamCapW = "DamConcrete", DamCapE = "DamConcrete", DamFrontPortalTop = "DamConcrete",
	Buttress = "DamConcrete", RampSupport = "DamConcrete", YardPillar = "DamConcrete", LandingPost = "DamConcrete",
	Ceiling = "Ceiling", InclineWall = "CrackedWall", GalleryCeiling = "RoofConcrete", PortalCeiling = "RoofConcrete", InclineCeiling = "RoofConcrete",
	DoorFrame = "DoorMetal", DoorHeader = "DoorMetal",
}
-- per base material: which variant a floor / roof / door of that material gets
local FLOOR = { Concrete = "ConcreteFloor", WoodPlanks = "OldFloor", Ground = "MineFloor" }
local ROOF = { Concrete = "RoofConcrete" }
local DOOR = { Metal = "DoorMetal", Wood = "DarkWood" }

local function wallVariant(wall: BasePart, mapId: string): string?
	if wall.Material ~= Enum.Material.Concrete then
		return nil
	end
	local p = wall.CFrame.Position
	if mapId == "church" then
		return "CrackedWall" -- the bunker under the hill
	elseif mapId == "dam03" and p.Z < 0 then
		return "CrackedWall" -- the gallery inside the dam
	elseif mapId == "relay07" and math.abs(p.X) < 50 then
		return "CrackedWall" -- halls and corridors around the core
	end
	return nil
end

function MapDress.Surfaces(model: Instance, mapId: string, textures: any)
	local variants = textures.Variants
	local function base(name: string?): string?
		local spec = name and variants[name]
		return spec and spec.base
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local name = part.Name
			local material = part.Material.Name
			-- the mine: tunnel ceilings are raw rock, not concrete
			if mapId == "mine" and name == "Roof" and part.CFrame.Position.Z < 0 and part.Material == Enum.Material.Concrete then
				part.Material = Enum.Material.Rock
				material = "Rock"
			end
			local variant: string? = BY_NAME[name]
			if not variant then
				if name == "Wall" then
					variant = wallVariant(part, mapId)
				elseif name == "Floor" or string.sub(name, 1, 6) == "Floor_" or string.sub(name, -5) == "Floor" or name == "Ceiling" then
					variant = FLOOR[material]
				elseif name == "Roof" or string.sub(name, 1, 5) == "Roof_" or string.sub(name, -4) == "Roof" then
					variant = ROOF[material]
				elseif string.match(name, "^Door%d+$") then
					variant = DOOR[material]
				end
			elseif name == "Ceiling" and material ~= "Concrete" then
				variant = FLOOR[material]
			end
			if variant and base(variant) == material then
				part.MaterialVariant = "SR_" .. variant
			end
		end
	end
end

---------------------------------------------------------------------------
-- Grime: water stains, rust streaks, mould, soot, cracks, tally marks on walls.
-- Decals (tag FZ_Grime, attribute Kind) get their image from TextureService / the bake.
---------------------------------------------------------------------------
local GRIME = {
	-- kind, weight, width, height, vertical anchor (0 = bottom, 1 = top of the wall)
	{ "water_stain", 5, 8, 7, 1 },
	{ "rust_streak", 3, 3, 6, 0.85 },
	{ "mould", 3, 6, 5, 0 },
	{ "soot", 2, 5, 6, 0.7 },
	{ "cracks", 3, 6, 6, 0.5 },
	{ "tally", 1, 3.2, 2.6, 0.38 },
}

function MapDress.Grime(model: Instance, seed: number, chance: number?, folderName: string?)
	local walls = model:FindFirstChild(folderName or "Walls")
	if not walls then
		return
	end
	local rng = Random.new(seed)
	local out = folderIn(model, "Grime")
	local total = 0
	for _, entry in GRIME do
		total += entry[2]
	end
	local tallies = 0
	for _, wall in walls:GetChildren() do
		if wall:IsA("BasePart") and wall.Name == "Wall" and wall.Size.Y >= 6 and rng:NextNumber() < (chance or 0.4) then
			local size = wall.Size
			local alongX = size.X >= size.Z
			local length = if alongX then size.X else size.Z
			local thickness = if alongX then size.Z else size.X
			if length >= 7 then
				local pickAt = rng:NextNumber() * total
				local kind = GRIME[1]
				for _, entry in GRIME do
					pickAt -= entry[2]
					if pickAt <= 0 then
						kind = entry
						break
					end
				end
				if kind[1] == "tally" then
					tallies += 1
				end
				if kind[1] ~= "tally" or tallies <= 3 then
					local w = math.min(kind[3], length - 1)
					local h = math.min(kind[4], size.Y - 0.5)
					local center = wall.CFrame.Position
					local bottom = center.Y - size.Y / 2
					local y = bottom + h / 2 + (size.Y - h) * kind[5]
					local along = rng:NextNumber(-(length - w) / 2, (length - w) / 2)
					local side = if rng:NextNumber() < 0.5 then -1 else 1
					local normal = if alongX then Vector3.new(0, 0, side) else Vector3.new(side, 0, 0)
					local tangent = if alongX then Vector3.new(along, 0, 0) else Vector3.new(0, 0, along)
					local pos = Vector3.new(center.X, y, center.Z) + tangent + normal * (thickness / 2 + 0.14)
					local holder = part(out, "Grime_" .. kind[1], Vector3.new(w, h, 0.05), CFrame.lookAt(pos, pos + normal), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
					holder.Transparency = 1
					local decal = Instance.new("Decal")
					decal.Face = Enum.NormalId.Front
					decal.Texture = ""
					decal.Transparency = 0.1
					decal:SetAttribute("Kind", kind[1])
					decal.Parent = holder
					CollectionService:AddTag(decal, "FZ_Grime")
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Terrain + lighting quality (runtime only: terrain cannot be baked)
---------------------------------------------------------------------------
function MapDress.TerrainLook(colors: { [string]: Color3 }?)
	local terrain = workspace.Terrain
	pcall(function()
		(terrain :: any).Decoration = true -- animated grass blades on Grass
	end)
	local palette = colors or {
		Grass = Color3.fromRGB(64, 78, 52),
		LeafyGrass = Color3.fromRGB(58, 70, 46),
		Ground = Color3.fromRGB(78, 68, 56),
		Mud = Color3.fromRGB(58, 50, 42),
		Rock = Color3.fromRGB(96, 94, 90),
	}
	for name, color in palette do
		pcall(function()
			terrain:SetMaterialColor((Enum.Material :: any)[name], color)
		end)
	end
end

function MapDress.LightingQuality()
	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Realistic
	end)
	pcall(function()
		(Lighting :: any).PrioritizeLightingQuality = true
	end)
end

return MapDress
