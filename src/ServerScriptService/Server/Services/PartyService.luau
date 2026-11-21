-- PartyService: "private session". The host invites everyone in this server who is in the
-- menu; whoever accepts within 15 s travels together into a fresh reserved server of this
-- place (not joinable by strangers). Works without any extra places.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local DecisionService = require(script.Parent.DecisionService)

local PartyService = {}

local INVITE_SECONDS = 15
type Invite = { id: string, host: Player, invited: { Player }, accepted: { [Player]: boolean }, answered: { [Player]: boolean }, done: boolean }
local invites: { [string]: Invite } = {}

local function teleport(invite: Invite)
	if invite.done then
		return
	end
	invite.done = true
	invites[invite.id] = nil
	local travellers = { invite.host }
	for player in invite.accepted do
		if player.Parent then
			table.insert(travellers, player)
		end
	end
	for _, player in invite.invited do
		if player.Parent then
			Net.Event("Decision"):FireClient(player, nil)
		end
	end
	local ok, code = pcall(function()
		return (TeleportService:ReserveServer(game.PlaceId))
	end)
	if not ok then
		Net.Event("Notify"):FireClient(invite.host, "SESSION_ERROR")
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({ private = true, code = code })
	for _, player in travellers do
		Net.Event("Notify"):FireClient(player, "SESSION_TELEPORT")
	end
	local success, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, travellers, options)
	end)
	if not success then
		warn("[FZ-Party] Teleport failed: " .. tostring(err))
		for _, player in travellers do
			Net.Event("Notify"):FireClient(player, "SESSION_ERROR")
		end
	end
end

-- Returns "teleport" (alone, leaving now) or "invited".
function PartyService.CreatePrivate(host: Player): string
	local invite: Invite = { id = "party:" .. HttpService:GenerateGUID(false), host = host, invited = {}, accepted = {}, answered = {}, done = false }
	for _, player in Players:GetPlayers() do
		if player ~= host and not player:GetAttribute("FZ_InGame") then
			table.insert(invite.invited, player)
		end
	end
	if #invite.invited == 0 then
		task.spawn(teleport, invite)
		return "teleport"
	end
	invites[invite.id] = invite
	for _, player in invite.invited do
		Net.Event("Decision"):FireClient(player, {
			id = invite.id,
			prompt = "PARTY_INVITE",
			promptParams = { name = host.DisplayName },
			options = { "PARTY_ACCEPT", "PARTY_DECLINE" },
			ends = workspace:GetServerTimeNow() + INVITE_SECONDS,
			counts = { 0, 0 },
			voters = #invite.invited,
		})
	end
	task.delay(INVITE_SECONDS, function()
		teleport(invite)
	end)
	return "invited"
end

function PartyService.Start()
	DecisionService.RegisterExternal("party", function(player, id, index)
		local invite = invites[id]
		if not invite or invite.done or not table.find(invite.invited, player) then
			return
		end
		invite.answered[player] = true
		invite.accepted[player] = if index == 1 then true else nil
		Net.Event("Decision"):FireClient(player, nil)
		local all = true
		for _, invited in invite.invited do
			if invited.Parent and not invite.answered[invited] then
				all = false
			end
		end
		if all then
			teleport(invite)
		end
	end)
end

return PartyService
