-- PlaceService: server-side teleports between places of this experience.
-- Only used when Content.Places has real place ids. Teams travel together into a
-- reserved server; the destination reads the (validated) selection from TeleportData.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared.Content)
local Net = require(Shared.Net)

local PlaceService = {}

function PlaceService.PlaceFor(mapId: string): number
	return Content.Places[mapId] or 0
end

function PlaceService.CanTeleport(mapId: string): boolean
	local placeId = PlaceService.PlaceFor(mapId)
	return placeId > 0 and placeId ~= game.PlaceId
end

-- Teleports players to a fresh reserved server of the map's place. Returns success.
function PlaceService.Teleport(players: { Player }, mapId: string, data: { mode: string, contentId: string }): boolean
	local placeId = PlaceService.PlaceFor(mapId)
	if placeId <= 0 then
		return false
	end
	local ok, accessCode = pcall(function()
		return (TeleportService:ReserveServer(placeId))
	end)
	if not ok or type(accessCode) ~= "string" then
		warn("[FZ-Place] ReserveServer failed: " .. tostring(accessCode))
		return false
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({ mode = data.mode, contentId = data.contentId })
	for attempt = 1, 3 do
		local success, err = pcall(function()
			TeleportService:TeleportAsync(placeId, players, options)
		end)
		if success then
			return true
		end
		warn(string.format("[FZ-Place] Teleport attempt %d failed: %s", attempt, tostring(err)))
		task.wait(attempt * 2)
	end
	return false
end

-- Selection a player arrived with (validated against the registry, never trusted blindly).
function PlaceService.ArrivalSelection(player: Player): (string?, string?)
	local ok, joinData = pcall(player.GetJoinData, player)
	local data = ok and type(joinData) == "table" and joinData.TeleportData
	if type(data) ~= "table" or type(data.mode) ~= "string" or type(data.contentId) ~= "string" then
		return nil, nil
	end
	if not Content.Entry(data.mode, data.contentId) then
		return nil, nil
	end
	return data.mode, data.contentId
end

function PlaceService.Start()
	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		warn(string.format("[FZ-Place] Teleport of %s failed (%s): %s", player.Name, tostring(result), tostring(message)))
		Net.Event("Notify"):FireClient(player, "SESSION_ERROR")
	end)
end

return PlaceService
