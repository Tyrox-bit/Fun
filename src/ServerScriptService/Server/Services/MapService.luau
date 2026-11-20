-- MapService: exactly one map is loaded per server. Sources, in this order:
--   1. Workspace.FZ_Map (your own hand-built map for relay07, never destroyed)
--   2. ServerStorage.Maps.<model> (your own map models for any map id)
--   3. A script builder in ServerScriptService/Server/Map (relay07 today)
-- Switching maps only happens when no session is running.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Content = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Content"))

local MapService = {}

local current: { id: string, model: Instance?, owned: boolean }? = nil

function MapService.CurrentId(): string?
	return current and current.id
end

function MapService.IsAvailable(mapId: string): boolean
	local map = Content.Maps[mapId]
	if not map then
		return false
	end
	if mapId == "relay07" and workspace:FindFirstChild("FZ_Map") then
		return true
	end
	local maps = ServerStorage:FindFirstChild("Maps")
	if maps and map.model and maps:FindFirstChild(map.model) then
		return true
	end
	return map.builder ~= nil and script.Parent.Parent.Map:FindFirstChild(map.builder) ~= nil
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
	if current and current.model and not current.owned then
		current.model:Destroy()
		workspace.Terrain:Clear()
	end
	local model: Instance? = nil
	local owned = false
	if mapId == "relay07" and workspace:FindFirstChild("FZ_Map") then
		model = workspace:FindFirstChild("FZ_Map")
		owned = true
	else
		local maps = ServerStorage:FindFirstChild("Maps")
		local source = maps and map.model and maps:FindFirstChild(map.model)
		if source then
			model = source:Clone()
			;(model :: Instance).Parent = workspace
		else
			model = require(script.Parent.Parent.Map:FindFirstChild(map.builder) :: ModuleScript).Build()
		end
	end
	current = { id = mapId, model = model, owned = owned }
	return true
end

-- Loads the default map at boot so the menu has a live scene behind it.
function MapService.Start()
	MapService.Load("relay07")
end

return MapService
