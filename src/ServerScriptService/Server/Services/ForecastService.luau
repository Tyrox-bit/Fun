-- ForecastService: the core mechanic "the radio tells you the future - you decide whether
-- it comes true". A forecast has a deadline, a way to break it (an interaction id that
-- must be used in time) and two outcomes. Used by story chapters and survival.
--
-- Replicated for the HUD: SessionState "Forecast" (text key) and "ForecastEnds" (server time).
-- Broken forecasts are remembered per player (secrets / endings), see DataService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local SessionState = require(Shared.SessionState)

local StoryService = require(script.Parent.StoryService)
local InteractionService = require(script.Parent.InteractionService)
local DataService = require(script.Parent.DataService)

local ForecastService = {}

export type Forecast = {
	id: string, -- permanent id (saved when broken)
	text: string, -- Relay line announcing it
	hud: string, -- short HUD label
	seconds: number,
	breakWith: string, -- InteractId that breaks it
	breakFilter: ((instance: Instance) -> boolean)?, -- e.g. only the breaker of sector C
	onKept: () -> (),
	onBroken: (player: Player) -> (),
	keptLine: string?,
	brokenLine: string?,
}

local active: Forecast? = nil
local token = 0

function ForecastService.IsActive(): boolean
	return active ~= nil
end

function ForecastService.Cancel()
	token += 1
	active = nil
	SessionState.Set("Forecast", nil)
	SessionState.Set("ForecastEnds", nil)
end

function ForecastService.Start(forecast: Forecast)
	ForecastService.Cancel()
	active = forecast
	local current = token
	StoryService.Say("all", { speaker = "SPEAKER_RELAY", text = forecast.text, channel = "radio", duration = 5, critical = true })
	SessionState.Set("Forecast", forecast.hud)
	SessionState.Set("ForecastEnds", workspace:GetServerTimeNow() + forecast.seconds)
	task.delay(forecast.seconds, function()
		if token ~= current or active ~= forecast then
			return
		end
		ForecastService.Cancel()
		forecast.onKept()
		if forecast.keptLine then
			StoryService.Sequence("all", { { delay = 2, speaker = "SPEAKER_RELAY", text = forecast.keptLine, channel = "radio", duration = 3.5 } })
		end
	end)
end

-- Interactions are routed here by InteractionService (see Start).
local function tryBreak(player: Player, instance: Instance, interactId: string)
	local forecast = active
	if not forecast or forecast.breakWith ~= interactId then
		return
	end
	if forecast.breakFilter and not forecast.breakFilter(instance) then
		return
	end
	ForecastService.Cancel()
	forecast.onBroken(player)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("FZ_InGame") then
			DataService.Grant(p, Config.Rewards.ForecastBroken)
			DataService.Mutate(p, function(data)
				data.secrets.forecastsBroken[forecast.id] = true
			end)
		end
	end
	if forecast.brokenLine then
		StoryService.Say("all", { speaker = "SPEAKER_RELAY", text = forecast.brokenLine, channel = "radio", duration = 4 })
	end
end

local registered: { [string]: boolean } = {}
-- Make an interaction id able to break forecasts. Safe to call many times.
function ForecastService.Breakable(interactId: string)
	if registered[interactId] then
		return
	end
	registered[interactId] = true
	InteractionService.Register(interactId, function(player, instance)
		tryBreak(player, instance, interactId)
	end)
end

return ForecastService
