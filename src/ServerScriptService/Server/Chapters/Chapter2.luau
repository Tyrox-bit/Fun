-- Chapter 2 "The Wrong Voice" on Staumauer 3 (storm night).
-- Forecasts become personal, broken forecasts change the dam, the Listener hunts actively,
-- and for the first time the two voices contradict each other.
--
--  1  Valley road -> crew building (zone) -> read the dam keeper's log
--  2  FORECAST (door, personal): "the canteen locks - with {name} inside" (override panel)
--  3  Powerhouse: restart both turbines. FORECAST (water): "the bottom outlet opens, the
--     gallery floods" (valve wheel). Kept -> gallery closed, the long way: the ramp outside.
--  4  Valve house on the crest: the Unknown pleads "Answer us!", the Relay says "Not yet."
--     DECISION c2_trust: trust the unknown voice (gate opens now, the Listener hears it) or
--     the Relay (close the spillway first, then the gate opens)
--  5  Antenna yard: hold the uplink together through the storm -> both voices answer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Services = script.Parent.Parent.Services
local StoryService = require(Services.StoryService)
local InteractionService = require(Services.InteractionService)
local CreatureService = require(Services.CreatureService)
local NoiseService = require(Services.NoiseService)
local DecisionService = require(Services.DecisionService)
local ForecastService = require(Services.ForecastService)
local DirectorService = require(Services.DirectorService)
local DoorService = require(Services.DoorService)
local LoreService = require(Services.LoreService)
local AchievementService = require(Services.AchievementService)
local HorrorEvents = require(script.Parent.Parent.Director.HorrorEvents)
local ChapterKit = require(script.Parent.ChapterKit)

local Chapter2 = {}
Chapter2.StartCheckpoint = "C2_START"

local k = ChapterKit.new("Chapter2", "ch2")
local UPLINK_SECONDS = 25
local UPLINK_RADIUS = 18

local ORDER = { "arrival", "crew", "forecast", "turbines", "crest", "decision", "spillway", "yard", "uplink", "done" }
local state = {
	stage = "arrival",
	turbines = {} :: { [any]: boolean },
	flooded = false,
	trustedUnknown = false,
	uplink = 0,
}

local HINTS = {
	OBJ_C2_CREW = "HINT_C2_CREW",
	OBJ_C2_LOG = "HINT_C2_LOG",
	OBJ_C2_TURBINES = "HINT_C2_TURBINES",
	OBJ_C2_CREST = "HINT_C2_CREST",
	OBJ_C2_CREST_RAMP = "HINT_C2_CREST_RAMP",
	OBJ_C2_SPILLWAY = "HINT_C2_SPILLWAY",
	OBJ_C2_UPLINK = "HINT_C2_UPLINK",
}

local function after(stage: string): boolean
	return (table.find(ORDER, state.stage) or 0) >= (table.find(ORDER, stage) or 0)
end

local function wake()
	if CreatureService.Count() == 0 then
		CreatureService.Spawn()
		k.relay("RADIO_C2_WAKE", nil, 1)
	end
end

---------------------------------------------------------------------------
-- Stages
---------------------------------------------------------------------------
local function startTurbines()
	state.stage = "turbines"
	k.step("Turbines")
	wake()
	k.objective("OBJ_C2_TURBINES", { count = 0, total = 2 })
	k.relay("RADIO_C2_TURBINES", nil, 3)
end

local function personalForecast()
	state.stage = "forecast"
	local name = k.randomName()
	ForecastService.Start({
		id = "c2_canteen",
		kind = "door",
		text = "RADIO_C2_FORECAST_DOOR",
		params = { name = name },
		hud = "FORECAST_CANTEEN",
		seconds = 30,
		breakWith = "c2_override",
		onKept = function()
			local doors = k.findAll("FZ_Door", function(panel)
				return panel:GetAttribute("Canteen") ~= nil
			end)
			for _, panel in doors do
				k.lock(panel)
			end
			k.world("SFX_DOORS_LOCK")
			wake()
			local canteen = k.find("FZ_CreaturePatrol", function(node)
				return node:GetAttribute("Area") == "CANTEEN"
			end)
			if canteen then
				CreatureService.Alert(canteen.Position)
			end
			k.after(25, function()
				for _, panel in doors do
					DoorService.SetLocked(panel, false)
				end
			end)
			k.after(4, startTurbines)
		end,
		onBroken = function()
			k.after(5, startTurbines)
		end,
		keptLine = "RADIO_C2_FORECAST_DOOR_KEPT",
		brokenLine = "RADIO_C2_FORECAST_DOOR_BROKEN",
	})
end

local function floodForecast()
	ForecastService.Start({
		id = "c2_flood",
		kind = "water",
		text = "RADIO_C2_FORECAST_FLOOD",
		hud = "FORECAST_FLOOD",
		seconds = 35,
		breakWith = "c2_valve",
		onKept = function()
			state.flooded = true
			k.setFlood(true)
			for _, panel in k.findAll("FZ_Door", function(p)
				return p:GetAttribute("Gallery") ~= nil
			end) do
				k.lock(panel)
			end
			local portal = k.door("Gallery")
			if portal then
				k.sfx("water_rush_loop", portal.Position, 1)
			end
			k.world("SFX_FLOOD")
		end,
		onBroken = function() end,
		keptLine = "RADIO_C2_FORECAST_FLOOD_KEPT",
		brokenLine = "RADIO_C2_FORECAST_FLOOD_BROKEN",
	})
end

local function startYard()
	state.stage = "yard"
	k.unlock(k.door("YardGate"), true)
	k.objective("OBJ_C2_UPLINK")
end

local function askTrust()
	state.stage = "decision"
	k.step("Decision")
	LoreService.UnlockAll(k.players(), "rec_c2_plea")
	k.sequence({
		{ delay = 1, text = "SFX_STATIC", channel = "sfx", duration = 2 },
		{ delay = 1.5, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C2_PLEA", channel = "radio", duration = 5, critical = true },
		{ delay = 5, speaker = "SPEAKER_RELAY", text = "RADIO_C2_NOT_YET", channel = "radio", duration = 4, critical = true },
		{ delay = 4.5, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C2_PLEA_2", channel = "radio", duration = 5 },
	})
	k.after(16, function()
		DecisionService.Ask({
			id = "c2_trust",
			prompt = "DECISION_C2_TRUST",
			options = { "DECISION_TRUST_UNKNOWN", "DECISION_TRUST_RELAY" },
			seconds = 25,
			default = 2,
			onDecided = function(index)
				if not k.active then
					return
				end
				state.trustedUnknown = index == 1
				if state.trustedUnknown then
					k.unknown("RADIO_C2_TRUST_UNKNOWN", nil, 1)
					k.relay("RADIO_C2_RELAY_HURT", nil, 7)
					-- the answer is loud: the Listener heard where you are
					local valve = k.interactable("c2_spillway")
					if valve then
						CreatureService.Alert(valve.Position)
					end
					startYard()
				else
					state.stage = "spillway"
					k.relay("RADIO_C2_TRUST_RELAY", nil, 1)
					k.unknown("RADIO_C2_UNKNOWN_HURT", nil, 6)
					k.objective("OBJ_C2_SPILLWAY")
				end
			end,
		}, k.players)
	end)
end

local function finishChapter()
	state.stage = "done"
	k.step("Uplink")
	ForecastService.Cancel()
	CreatureService.SetAIEnabled(false)
	k.objective(nil)
	k.sequence({
		{ delay = 1, text = "SFX_THUNDER", channel = "world", duration = 3 },
		{ delay = 2, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C2_END_UNKNOWN", channel = "radio", duration = 5 },
		{ delay = 5.5, speaker = "SPEAKER_RELAY", text = if state.trustedUnknown then "RADIO_C2_END_RELAY_UNKNOWN" else "RADIO_C2_END_RELAY", channel = "radio", duration = 5 },
		{ delay = 6, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C2_END_NAMES", params = { name = k.randomName() }, channel = "radio", duration = 5, critical = true },
	})
	k.after(19, function()
		k.complete("ch2_complete", function(player)
			AchievementService.Award(player, "storm_chaser")
		end)
	end)
	k.after(22, function()
		k.ctx.finish()
	end)
end

---------------------------------------------------------------------------
-- Scares
---------------------------------------------------------------------------
local function beats()
	return {
		{ id = "c2_footsteps", kind = "footsteps", condition = function(_p, info)
			return info.alone and after("crew")
		end },
		{ id = "c2_flicker", kind = "flicker", condition = function(_p, info)
			return info.area ~= nil and after("crew")
		end },
		{ id = "c2_gallery_figure", kind = "apparition", once = true, weight = 20, condition = function(_p, info)
			return info.area == "GALLERY" or info.area == "INCLINE"
		end },
		{ id = "c2_crest_figure", kind = "apparition", once = true, weight = 15, condition = function(_p, info)
			return (info.area == "CREST" or info.area == "RAMP") and after("turbines")
		end },
		{ id = "c2_name", kind = "namecall", once = true, weight = 20, condition = function(_p, info)
			return info.alone and after("turbines")
		end, data = function(player)
			return { name = player.DisplayName, answered = false }
		end },
		{ id = "c2_door", kind = "doorslam", once = true, condition = function(_p, info)
			return info.area == "CANTEEN" or info.area == "DORM" or info.area == "OFFICE"
		end, data = function(player)
			local root = k.rootOf(player)
			if root then
				local panel = k.find("FZ_Door", function(p)
					return p:GetAttribute("Open") == true and (p.Position - root.Position).Magnitude < 25
				end)
				if panel then
					DoorService.Close(panel)
				end
			end
			return {}
		end },
	}
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function reset()
	k.reset()
	state.stage = "arrival"
	table.clear(state.turbines)
	state.flooded = false
	state.trustedUnknown = false
	state.uplink = 0
	k.setFlood(false)
	ForecastService.Cancel()
	DecisionService.Cancel()
	DirectorService.Stop()
	StoryService.ResetFlags()
	StoryService.SetObjective(nil)
	k.setState("Weather", nil)
end

function Chapter2.Begin()
	reset()
	k.active = true
	k.setState("Weather", "storm")
	CreatureService.SetDifficulty({ speed = 1.05, hearing = 1.2 })
	DirectorService.Configure(HorrorEvents.With(beats()), HINTS, k.players)

	k.zones({
		{ id = "crew", center = Vector3.new(-80, 0, 70), radius = 42, when = function()
			return state.stage == "arrival"
		end, fn = function()
			state.stage = "crew"
			k.step("Crew")
			k.ctx.setCheckpoint("C2_VALLEY")
			k.relay("RADIO_C2_CREW", nil, 1)
			k.objective("OBJ_C2_LOG")
		end },
		{ id = "crest", center = Vector3.new(132, 44, -10), radius = 16, when = function()
			return state.stage == "crest"
		end, fn = function()
			k.ctx.setCheckpoint("C2_CREST")
			askTrust()
		end },
	})
	-- the Listener hunts actively once the turbines run
	k.every(40, function()
		return after("turbines") and state.stage ~= "done"
	end, k.huntPulse)
	-- storm: thunder now and then (sound + caption only for people who want captions)
	k.every(23, function()
		return state.stage ~= "done"
	end, function()
		Net.Event("Sfx"):FireAllClients(if math.random() < 0.5 then "thunder_1" else "thunder_2", nil, 0.9)
	end)
end

function Chapter2.Stop()
	k.active = false
	reset()
	CreatureService.SetDifficulty({})
end

function Chapter2.Init(context)
	k.ctx = context
	ForecastService.Breakable("c2_override")
	ForecastService.Breakable("c2_valve")

	-- the dam keeper's log starts the personal forecast
	InteractionService.Register("lore", function(_player, object)
		if k.active and state.stage == "crew" and object:GetAttribute("LogId") == "c2_keeper_log" then
			k.step("Log")
			k.objective(nil)
			k.relay("RADIO_C2_LOG", nil, 4)
			k.after(9, personalForecast)
		end
	end)

	InteractionService.Register("generator", function(_player, generator)
		if not k.active or state.stage ~= "turbines" then
			return
		end
		local id = generator:GetAttribute("GeneratorId") or generator
		if state.turbines[id] then
			return
		end
		state.turbines[id] = true
		k.sfx("relay_activate", (generator :: BasePart).Position)
		NoiseService.Emit((generator :: BasePart).Position, 50, nil)
		local count = 0
		for _ in state.turbines do
			count += 1
		end
		k.rewardAll(Config.Rewards.Fuse)
		k.objective("OBJ_C2_TURBINES", { count = count, total = 2 })
		if count == 1 then
			k.after(3, floodForecast)
		elseif count >= 2 then
			state.stage = "crest"
			k.step("Power")
			k.ctx.setCheckpoint("C2_POWER")
			k.rewardAll(Config.Rewards.Relay)
			k.relay(if state.flooded then "RADIO_C2_CREST_RAMP" else "RADIO_C2_CREST", nil, 2)
			k.objective(if state.flooded then "OBJ_C2_CREST_RAMP" else "OBJ_C2_CREST")
		end
	end)

	InteractionService.Register("c2_spillway", function(_player, wheel)
		if not k.active or state.stage ~= "spillway" then
			return
		end
		k.sfx("relay_activate", (wheel :: BasePart).Position)
		k.relay("RADIO_C2_SPILLWAY_DONE", nil, 1)
		startYard()
	end)

	InteractionService.Register("c2_uplink", function(_player, cabinet)
		if not k.active or state.stage ~= "yard" then
			return
		end
		state.stage = "uplink"
		state.uplink = 0
		k.sfx("relay_activate", (cabinet :: BasePart).Position)
		k.relay("RADIO_C2_UPLINK", nil, 1)
		k.objective("OBJ_C2_UPLINK_HOLD", { percent = 0 })
		local center = (cabinet :: BasePart).Position
		k.every(1, function()
			return state.stage == "uplink"
		end, function()
			local here = k.near(center, UPLINK_RADIUS)
			if here == 0 then
				return
			end
			state.uplink += 1
			if state.uplink % 6 == 0 then
				NoiseService.Emit(center, 90, nil)
				CreatureService.Alert(center)
			end
			k.objective("OBJ_C2_UPLINK_HOLD", { percent = math.floor(state.uplink / UPLINK_SECONDS * 100) })
			if state.uplink >= UPLINK_SECONDS then
				finishChapter()
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function() end)
end

function Chapter2.OnPlayerEntered(player: Player, firstTime: boolean)
	if not firstTime or not k.active or state.stage ~= "arrival" then
		return
	end
	k.step("Arrival")
	StoryService.Sequence(player, {
		{ delay = 1.5, text = "SFX_STORM", channel = "world", duration = 3 },
		{ delay = 1.5, speaker = "SPEAKER_RELAY", text = "RADIO_C2_001", channel = "radio", duration = 5 },
		{ delay = 5.5, speaker = "SPEAKER_RELAY", text = "RADIO_C2_002", channel = "radio", duration = 5 },
	})
	k.after(12, function()
		if player.Parent then
			LoreService.Unlock(player, "rec_c2_arrival", true)
		end
	end)
	k.after(13, function()
		if state.stage == "arrival" and StoryService.GetObjective() == nil then
			k.objective("OBJ_C2_CREW")
		end
	end)
end

return Chapter2
