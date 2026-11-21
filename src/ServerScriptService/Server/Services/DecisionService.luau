-- DecisionService: team decisions with consequences ("Entscheiden -> Konsequenzen").
--   * Every player in the session votes (big buttons, works with touch/gamepad/mouse).
--   * Majority wins; a tie goes to the option that got its first vote earliest;
--     nobody votes -> the default option. Solo: your vote decides immediately.
--   * The result is stored in the session (StoryService flag "Choice_<id>") AND in every
--     participant's save (data.storyChoices[id]) so later chapters and endings react.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local StoryService = require(script.Parent.StoryService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local DecisionService = {}

export type Decision = {
	id: string,
	prompt: string, -- localization key
	options: { string }, -- localization keys
	seconds: number,
	default: number,
	onDecided: (index: number) -> (),
}

type Running = {
	decision: Decision,
	votes: { [Player]: number },
	firstVoteAt: { [number]: number },
	ends: number,
	token: number,
	voters: () -> { Player },
}

local running: Running? = nil
local token = 0

local function payload(r: Running)
	local counts = {}
	for index in r.decision.options do
		counts[index] = 0
	end
	for _, index in r.votes do
		counts[index] += 1
	end
	return {
		id = r.decision.id,
		prompt = r.decision.prompt,
		options = r.decision.options,
		ends = r.ends,
		counts = counts,
		voters = #r.voters(),
	}
end

local function finish(r: Running)
	if running ~= r then
		return
	end
	running = nil
	Net.Event("Decision"):FireAllClients(nil)
	local counts = payload(r).counts
	local best, bestCount, bestTime = r.decision.default, 0, math.huge
	for index, count in counts do
		local first = r.firstVoteAt[index] or math.huge
		if count > bestCount or (count == bestCount and count > 0 and first < bestTime) then
			best, bestCount, bestTime = index, count, first
		end
	end
	StoryService.SetFlag("Choice_" .. r.decision.id, best)
	for _, player in r.voters() do
		DataService.Mutate(player, function(data)
			data.storyChoices[r.decision.id] = best
		end)
	end
	r.decision.onDecided(best)
end

function DecisionService.IsOpen(): boolean
	return running ~= nil
end

function DecisionService.Cancel()
	token += 1
	if running then
		running = nil
		Net.Event("Decision"):FireAllClients(nil)
	end
end

-- voters: function returning the players allowed to vote (players in the session)
function DecisionService.Ask(decision: Decision, voters: () -> { Player })
	DecisionService.Cancel()
	token += 1
	local r: Running = {
		decision = decision,
		votes = {},
		firstVoteAt = {},
		ends = workspace:GetServerTimeNow() + decision.seconds,
		token = token,
		voters = voters,
	}
	running = r
	Net.Event("Decision"):FireAllClients(payload(r))
	task.delay(decision.seconds, function()
		if running == r then
			finish(r)
		end
	end)
end

function DecisionService.Start()
	local limiter = RateLimiter.new(4, 1)
	Net.Event("DecisionVote").OnServerEvent:Connect(function(player: Player, id: any, index: any)
		local r = running
		if not r or not limiter:Allow(player) or id ~= r.decision.id or type(index) ~= "number" then
			return
		end
		if index % 1 ~= 0 or index < 1 or index > #r.decision.options then
			return
		end
		if not table.find(r.voters(), player) then
			return
		end
		r.votes[player] = index
		r.firstVoteAt[index] = r.firstVoteAt[index] or os.clock()
		local everyone = true
		for _, voter in r.voters() do
			if r.votes[voter] == nil then
				everyone = false
			end
		end
		if everyone then
			finish(r)
		else
			Net.Event("Decision"):FireAllClients(payload(r))
		end
	end)
end

return DecisionService
