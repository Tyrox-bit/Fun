-- EvidenceService: supernatural photographs.
-- Photos are physical objects (tag FZ_Interactable, InteractId "photo", attributes PhotoId +
-- Kind). When picked up, the server decides WHAT the photo shows from real session context:
--   past_self   : you, in the area where you actually were about five minutes ago
--   team_future : your team in front of a place you have not reached yet
--   mate_dark   : a teammate standing in a dark corridor (solo: you, with someone behind)
-- The client renders it live from avatar copies (ViewportFrame) - no screenshots, nothing
-- stored except the photo id and an area name. No personal data is evaluated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local SessionState = require(Shared.SessionState)

local InteractionService = require(script.Parent.InteractionService)
local DirectorService = require(script.Parent.DirectorService)
local DataService = require(script.Parent.DataService)
local LoreService = require(script.Parent.LoreService)

local EvidenceService = {}

local HISTORY_SECONDS = 600
local history: { [Player]: { { time: number, area: string } } } = {}

local FUTURE_AREA_BY_OBJECTIVE = {
	OBJECTIVE_CHECK_GATEHOUSE = "CONTROL",
	OBJECTIVE_REACH_CONTROL = "CONTROL",
	OBJECTIVE_POWER = "B",
	OBJECTIVE_FIND_FUSES = "B",
	OBJECTIVE_RELAY_B = "CORE",
	OBJECTIVE_CORE = "CORE",
	OBJECTIVE_ANTENNA = "ANTENNA",
}

local function areaAgo(player: Player, seconds: number): string?
	local list = history[player]
	if not list or #list == 0 then
		return nil
	end
	local target = os.clock() - seconds
	local best = list[1]
	for _, entry in list do
		if entry.time <= target then
			best = entry
		end
	end
	return best.area
end

local function randomPastDate(): string
	-- somewhere between 1979 (station built) and the night of 2009
	local year = math.random(1979, 2009)
	return string.format("%02d.%02d.%d", math.random(1, 28), math.random(1, 12), year)
end

function EvidenceService.Start()
	-- coarse movement history (area names only, every 5 s, 10 minutes)
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local root = player:GetAttribute("FZ_InGame") and player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local area = DirectorService.AreaOf(root.Position)
					if area then
						local list = history[player] or {}
						history[player] = list
						table.insert(list, { time = os.clock(), area = area })
						while list[1] and os.clock() - list[1].time > HISTORY_SECONDS do
							table.remove(list, 1)
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		history[player] = nil
	end)

	InteractionService.Register("photo", function(player, object)
		local id = object:GetAttribute("PhotoId")
		local kind = object:GetAttribute("Kind")
		if type(id) ~= "string" or type(kind) ~= "string" then
			return
		end
		local photo = { id = id, kind = kind, date = randomPastDate(), subjects = { player.UserId } }
		if kind == "past_self" then
			photo.area = areaAgo(player, 300) or areaAgo(player, 60) or "HALL"
		elseif kind == "team_future" then
			photo.area = FUTURE_AREA_BY_OBJECTIVE[SessionState.Get("Objective") or ""] or "CORE"
			for _, other in Players:GetPlayers() do
				if other ~= player and other:GetAttribute("FZ_InGame") then
					table.insert(photo.subjects, other.UserId)
				end
			end
		else -- mate_dark
			photo.area = "HALL"
			local others = {}
			for _, other in Players:GetPlayers() do
				if other ~= player and other:GetAttribute("FZ_InGame") then
					table.insert(others, other)
				end
			end
			if #others > 0 then
				photo.subjects = { others[math.random(1, #others)].UserId }
			else
				photo.figureBehind = true -- solo: you, and something behind you
			end
		end
		Net.Event("Photo"):FireClient(player, photo)
		-- Archive: only id + area are stored (re-rendered with avatars when viewed)
		if LoreService.Unlock(player, id) then
			DataService.Mutate(player, function(data)
				data.secrets.photos[id] = { area = photo.area, date = photo.date, kind = kind }
			end)
		end
	end)
end

return EvidenceService
