-- AnalyticsTracker: measures where players stop, without collecting anything personal.
-- Uses Roblox AnalyticsService (Creator Hub -> Analytics -> Funnels / Economy):
--   * Onboarding funnel (first session only): language -> menu -> in game -> first task
--   * Chapter 1 funnel (every run): gate -> fax -> decision -> power -> fuses -> relay -> core -> end
--   * Economy: every Signal Mark source and sink
-- All calls are wrapped: analytics must never break gameplay.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")

local AnalyticsTracker = {}

local runIds: { [Player]: string } = {}
local onboardingDone: { [Player]: { [number]: boolean } } = {}

AnalyticsTracker.Chapter1Steps = {
	"Gate", "Fax", "Decision", "Power", "FirstFuse", "AllFuses", "Relay", "Core", "Antenna",
}

function AnalyticsTracker.Onboarding(player: Player, step: number, name: string)
	onboardingDone[player] = onboardingDone[player] or {}
	if onboardingDone[player][step] then
		return
	end
	onboardingDone[player][step] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function AnalyticsTracker.NewRun(player: Player)
	runIds[player] = HttpService:GenerateGUID(false)
end

function AnalyticsTracker.ChapterStep(player: Player, funnel: string, stepName: string)
	local index = table.find(AnalyticsTracker.Chapter1Steps, stepName)
	if not index then
		return
	end
	local runId = runIds[player] or HttpService:GenerateGUID(false)
	runIds[player] = runId
	pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, runId, index, stepName)
	end)
end

function AnalyticsTracker.Economy(player: Player, amount: number, balance: number, source: boolean, reason: string)
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			if source then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			"SignalMarks",
			math.abs(amount),
			balance,
			if source then Enum.AnalyticsEconomyTransactionType.Gameplay.Name else Enum.AnalyticsEconomyTransactionType.Shop.Name,
			reason
		)
	end)
end

function AnalyticsTracker.Forget(player: Player)
	runIds[player] = nil
	onboardingDone[player] = nil
end

return AnalyticsTracker
