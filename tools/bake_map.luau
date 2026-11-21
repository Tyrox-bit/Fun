-- Runs the script map builders headlessly (Lune) and bakes the results into the place file:
--   RelayStation07 -> Workspace.FZ_Map         (visible in Studio without pressing Play)
--   Dam03, Chapel, Mine -> ServerStorage.Maps.<Model> (tags stored in the FZ_Tags attribute,
--                          MapService restores them when the map is loaded)
-- Usage: lune run tools/bake_map.luau build/SilentRelay.rbxlx
-- Terrain is not bakeable here; MapService fills it at runtime (BuildTerrain).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath = process.args[1] or "build/SilentRelay.rbxlx"
local game = roblox.deserializePlace(fs.readFile(placePath))
local workspace = game:GetService("Workspace")
local serverStorage = game:GetService("ServerStorage")
local MAP_DIR = "src/ServerScriptService/Server/Map/"

-- Minimal stand-ins for engine APIs the builders use that Lune does not implement.
local collection = {
	AddTag = function(_, instance, tagName)
		instance:AddTag(tagName)
	end,
}
local fakeGame = {
	GetService = function(_, name)
		if name == "CollectionService" then
			return collection
		end
		return game:GetService(name)
	end,
}

local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed)
	return setmetatable({ state = (seed or 1) % 2147483647 }, RandomShim)
end
function RandomShim:NextNumber(min, max)
	self.state = (self.state * 48271) % 2147483647
	local t = self.state / 2147483647
	min = min or 0
	max = max or 1
	return min + (max - min) * t
end
function RandomShim:NextInteger(min, max)
	return math.floor(self:NextNumber(min, max + 1))
end

-- Preload sources (fs calls must not happen inside module code).
local sources = {}
for _, name in fs.readDir(MAP_DIR) do
	if string.sub(name, -5) == ".luau" then
		sources[string.sub(name, 1, -6)] = fs.readFile(MAP_DIR .. name)
	end
end

local env
local loaded = {}
local siblings = setmetatable({}, {
	__index = function(_, name)
		return { __module = name }
	end,
})
local function requireMap(target)
	local name = type(target) == "table" and target.__module
	assert(name and sources[name], "unknown map module " .. tostring(name))
	if loaded[name] == nil then
		local chunk = luau.load(sources[name], { debugName = name, environment = env })
		loaded[name] = chunk()
	end
	return loaded[name]
end

env = setmetatable({
	game = fakeGame,
	workspace = workspace,
	script = { Parent = siblings },
	require = requireMap,
	Random = RandomShim,
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	Font = roblox.Font,
	warn = function(...)
		print("[warn]", ...)
	end,
}, { __index = _G })

local function stats(model)
	local parts, lights, tagged = 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		elseif d:IsA("Light") then
			lights += 1
		end
		if #d:GetTags() > 0 or d:GetAttribute("FZ_Tags") then
			tagged += 1
		end
	end
	return string.format("%d parts, %d lights, %d tagged", parts, lights, tagged)
end

local function stashTags(root)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, instance in list do
		local tags = instance:GetTags()
		if #tags > 0 then
			instance:SetAttribute("FZ_Tags", table.concat(tags, ","))
			for _, name in tags do
				instance:RemoveTag(name)
			end
		end
	end
end

-- 1. Relay Station 07 -> Workspace.FZ_Map (its lighting stays in the Lighting service)
local old = workspace:FindFirstChild("FZ_Map")
if old then
	old:Destroy()
end
local relay = requireMap({ __module = "RelayStation07" })
relay.SkipTerrain = true
local relayModel = relay.Build()
relayModel.Name = "FZ_Map"
print("baked FZ_Map (RelayStation07): " .. stats(relayModel))

-- 2. Further maps -> ServerStorage.Maps (built, then moved out of the workspace).
--    Their lighting is applied at load time, so Lighting is restored to Relay 07 after.
local maps = serverStorage:FindFirstChild("Maps")
if not maps then
	maps = roblox.Instance.new("Folder")
	maps.Name = "Maps"
	maps.Parent = serverStorage
end
for _, entry in { { "Dam03", "Dam03" }, { "Chapel", "Church" }, { "Mine", "Mine" } } do
	local builderName, modelName = entry[1], entry[2]
	if sources[builderName] then
		local existing = maps:FindFirstChild(modelName)
		if existing then
			existing:Destroy()
		end
		local builder = requireMap({ __module = builderName })
		builder.SkipTerrain = true
		local model = builder.Build()
		model.Name = modelName
		stashTags(model)
		model.Parent = maps
		print(string.format("baked ServerStorage.Maps.%s (%s): %s", modelName, builderName, stats(model)))
	end
end
relay.ApplyLighting()

-- 3. Photo-scanned textures: MaterialVariants + base material overrides (MaterialService
--    "<Material>Name"), so the maps look real in edit mode too. Only materials whose image
--    ids are filled in Shared/Assets.luau. FZ_TEXTURE_TEST=1 uses placeholder ids (format test).
local function loadModule(path)
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end
local assets = loadModule("src/ReplicatedStorage/Shared/Assets.luau")
local textures = loadModule("src/ReplicatedStorage/Shared/Textures.luau")
local materialService = game:GetService("MaterialService")
local PROPERTY = { color = "ColorMap", normal = "NormalMap", roughness = "RoughnessMap", metalness = "MetalnessMap" }
local baked = 0
for material, spec in textures do
	local set = (assets.Textures or {})[material] or {}
	local test = process.env.FZ_TEXTURE_TEST == "1"
	if test or (type(set.color) == "string" and set.color ~= "") then
		local name = "SR_" .. material
		local old = materialService:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local variant = roblox.Instance.new("MaterialVariant")
		variant.Name = name
		variant.BaseMaterial = roblox.Enum.Material[material]
		variant.StudsPerTile = spec.studsPerTile
		variant.MaterialPattern = roblox.Enum.MaterialPattern[spec.pattern]
		for _, map in spec.maps do
			local id = if test then "rbxassetid://1" else set[map]
			if type(id) == "string" and id ~= "" then
				variant[PROPERTY[map]] = id
			end
		end
		variant.Parent = materialService
		materialService[material .. "Name"] = name
		baked += 1
	end
end
print(string.format("baked %d textured materials into MaterialService", baked))

fs.writeFile(placePath, roblox.serializePlace(game, true))
print("wrote " .. placePath)
