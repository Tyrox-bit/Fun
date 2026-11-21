-- ReferralService: small one-time reward when a NEW player joins through a friend's invite.
--   * The invite carries LaunchData "ref:<inviterUserId>" (ExperienceInviteOptions);
--     the server reads it from Player:GetJoinData() - nothing the client claims is trusted
--   * Only for genuinely new players (first session), account at least 7 days old,
--     never your own id, once per invited account, at most 10 rewards per inviter
--   * Reward only after a real condition: reaching the control room in chapter 1 or
--     15 minutes of play. Pressing "invite" alone never rewards anything.
--   * If the inviter is offline the reward waits in a DataStore and is paid on their
--     next join.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Community = require(Shared.Community)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)

local ReferralService = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("FZ_Referrals_v1")
end)

local pending: { [Player]: { inviter: number, since: number } } = {}

local function payInviter(inviterId: number)
	local inviter = Players:GetPlayerByUserId(inviterId)
	if inviter and DataService.Get(inviter) then
		local paid = false
		DataService.Mutate(inviter, function(data)
			if (data.referral.rewardedInvites or 0) < Community.ReferralMaxPerPlayer then
				data.referral.rewardedInvites = (data.referral.rewardedInvites or 0) + 1
				paid = true
			end
		end)
		if paid then
			DataService.Grant(inviter, Community.ReferralMarks)
			Net.Event("Notify"):FireClient(inviter, "REFERRAL_REWARD")
		end
		return
	end
	if store then
		pcall(function()
			store:UpdateAsync(tostring(inviterId), function(old)
				local entry = if type(old) == "table" then old else { pending = 0 }
				entry.pending = (entry.pending or 0) + 1
				return entry
			end)
		end)
	end
end

-- Called when the invited player fulfils the condition.
function ReferralService.Complete(player: Player)
	local entry = pending[player]
	if not entry then
		return
	end
	pending[player] = nil
	local profile = DataService.Get(player)
	if not profile or profile.Data.referral.rewarded then
		return
	end
	DataService.Mutate(player, function(data)
		data.referral.rewarded = os.time()
	end)
	DataService.Grant(player, Community.ReferralMarks)
	Net.Event("Notify"):FireClient(player, "REFERRAL_REWARD")
	payInviter(entry.inviter)
end

function ReferralService.Start()
	DataService.ProfileLoaded:Connect(function(player, profile)
		-- 1) rewards waiting for this player as an inviter
		if store and profile.Persistent then
			local count = 0
			pcall(function()
				store:UpdateAsync(tostring(player.UserId), function(old)
					if type(old) ~= "table" or (old.pending or 0) <= 0 then
						return nil
					end
					count = old.pending
					old.pending = 0
					return old
				end)
			end)
			for _ = 1, count do
				payInviter(player.UserId)
			end
		end
		-- 2) did this NEW player arrive through an invite?
		local ok, joinData = pcall(player.GetJoinData, player)
		local launch = ok and type(joinData) == "table" and joinData.LaunchData
		local inviter = type(launch) == "string" and tonumber(string.match(launch, "^ref:(%d+)$"))
		if not inviter or inviter == player.UserId then
			return
		end
		if profile.Data.stats.sessions > 1 or profile.Data.referral.by or player.AccountAge < Community.ReferralMinAccountAgeDays then
			return
		end
		DataService.Mutate(player, function(data)
			data.referral.by = inviter
		end)
		pending[player] = { inviter = inviter, since = os.clock() }
	end)

	-- time-based condition (15 minutes)
	task.spawn(function()
		while true do
			task.wait(30)
			for player, entry in pending do
				if os.clock() - entry.since > 15 * 60 then
					ReferralService.Complete(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return ReferralService
