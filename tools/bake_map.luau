-- Runs the script map builder headlessly (Lune) and bakes the result into the place file,
-- so the map is visible in Roblox Studio without pressing Play.
-- Usage: lune run tools/bake_map.luau build/SilentRelay.rbxlx
-- Terrain is not bakeable here; MapService fills it at runtime (BuildTerrain).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath = process.args[1] or "build/SilentRelay.rbxlx"
local game = roblox.deserializePlace(fs.readFile(placePath))
local workspace = game:GetService("Workspace")

local old = workspace:FindFirstChild("FZ_Map")
if old then
	old:Destroy()
end

-- Minimal stand-ins for engine APIs the builder uses that Lune does not implement.
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

local env = setmetatable({
	game = fakeGame,
	workspace = workspace,
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

local source = fs.readFile("src/ServerScriptService/Server/Map/RelayStation07.luau")
local chunk = luau.load(source, { debugName = "RelayStation07", environment = env })
local Map = chunk()
Map.SkipTerrain = true
local model = Map.Build()
model.Name = "FZ_Map"

local parts, lights, tagged = 0, 0, 0
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("Light") then
		lights += 1
	end
	if #d:GetTags() > 0 then
		tagged += 1
	end
end
fs.writeFile(placePath, roblox.serializePlace(game, true))
print(string.format("baked FZ_Map into %s: %d parts, %d lights, %d tagged instances", placePath, parts, lights, tagged))
