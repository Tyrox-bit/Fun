-- MapService: exactly one map is loaded per server. Sources, in this order:
--   1. Workspace.FZ_Map (your own hand-built map for relay07, or the baked builder map)
--   2. ServerStorage.Maps.<model> (your own map models, or the baked builder maps)
--   3. A script builder in ServerScriptService/Server/Map
-- Switching maps only happens when no session is running.
--
-- Tags: CollectionService also finds tagged instances in ServerStorage. So that fuse spots,
-- checkpoints or doors of a stored map never leak into the running one, stored maps keep
-- their tags in an attribute ("FZ_Tags") and get them back when they are loaded. A map you
-- leave is parked outside the DataModel (Parent = nil), which removes it from every query.
--
-- Builder maps (attribute FZ_Builder) get their terrain and lighting from the builder
-- module at load time, because terrain cannot be stored by the tools that bake the maps.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))

local MapService = {}

local current: { id: string, model: Instance?, owned: boolean }? = nil
local parked: { [string]: Instance } = {}
local mapFolder = script.Parent.Parent.Map

function MapService.CurrentId(): string?
	return current and current.id
end

-- Moves live tags into the FZ_Tags attribute (stored maps) ...
local function stashTags(root: Instance)
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

-- ... and back (when a stored map is placed in the world).
local function restoreTags(root: Instance)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, instance in list do
		local stored = instance:GetAttribute("FZ_Tags")
		if type(stored) == "string" and stored ~= "" then
			for _, name in string.split(stored, ",") do
				CollectionService:AddTag(instance, name)
			end
			instance:SetAttribute("FZ_Tags", nil)
		end
	end
end

local function storedModel(map): Instance?
	local maps = ServerStorage:FindFirstChild("Maps")
	return maps and map.model and maps:FindFirstChild(map.model) or nil
end

local function builderOf(model: Instance?, map): ModuleScript?
	local name = (model and model:GetAttribute("FZ_Builder")) or map.builder
	local module = type(name) == "string" and mapFolder:FindFirstChild(name)
	return if module and module:IsA("ModuleScript") then module else nil
end

function MapService.IsAvailable(mapId: string): boolean
	local map = Content.Maps[mapId]
	if not map then
		return false
	end
	if parked[mapId] or (mapId == "relay07" and workspace:FindFirstChild("FZ_Map")) or storedModel(map) then
		return true
	end
	return builderOf(nil, map) ~= nil
end

-- Terrain + lighting of a builder map that was placed from storage (or un-parked).
local function dressUp(model: Instance, map)
	local module = builderOf(model, map)
	if not module then
		return
	end
	local ok, err = pcall(function()
		local builder = require(module) :: any
		if builder.BuildTerrain then
			builder.BuildTerrain(model)
		end
		if builder.ApplyLighting then
			builder.ApplyLighting()
		end
	end)
	if not ok then
		warn("[FZ-Map] terrain/lighting failed: " .. tostring(err))
	end
end

function MapService.Load(mapId: string): boolean
	if current and current.id == mapId then
		return true
	end
	local map = Content.Maps[mapId]
	if not map or not MapService.IsAvailable(mapId) then
		warn("[FZ-Map] Map not available: " .. tostring(mapId))
		return false
	end
	if current and current.model then
		if current.owned then
			parked[current.id] = current.model
			current.model.Parent = nil
		else
			current.model:Destroy()
		end
	end
	workspace.Terrain:Clear()

	local model: Instance? = nil
	local owned = false
	if parked[mapId] then
		model = parked[mapId]
		parked[mapId] = nil
		;(model :: Instance).Parent = workspace
		owned = true
		dressUp(model :: Instance, map)
	elseif mapId == "relay07" and workspace:FindFirstChild("FZ_Map") then
		model = workspace:FindFirstChild("FZ_Map")
		owned = true
		dressUp(model :: Instance, map)
	elseif storedModel(map) then
		local copy = (storedModel(map) :: Instance):Clone()
		restoreTags(copy)
		copy.Parent = workspace
		model = copy
		owned = true -- keep the copy (parked) instead of cloning again next time
		dressUp(copy, map)
	else
		model = (require(builderOf(nil, map) :: ModuleScript) :: any).Build()
	end
	current = { id = mapId, model = model, owned = owned }
	return true
end

-- Loads the default map at boot so the menu has a live scene behind it.
function MapService.Start()
	local maps = ServerStorage:FindFirstChild("Maps")
	if maps then
		stashTags(maps)
	end
	MapService.Load("relay07")
end

return MapService
