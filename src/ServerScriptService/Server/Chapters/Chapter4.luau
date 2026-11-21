-- Chapter 4 "Frequency Zero" in the mine above the Echo-Array.
-- The station breaks into time layers: every Array pulse switches between today and the
-- night of 2009 (parts tagged FZ_Layer). All mechanics combine: break forecasts to keep a
-- way open, avoid the Listener, reach the core together - and decide how it ends.
--
--  1  Mine yard -> winding house lever opens the gate
--  2  Pulses start (today <-> 2009). The old passage north is buried today, open in 2009.
--     FORECAST (machine): the cage falls (brake lever). Kept -> the loop route jams.
--     FORECAST (water): the lower level floods (pump). Kept -> the pump room goes dark.
--  3  Transformer room. FORECAST (power): the transformer burns through (breaker).
--  4  Blast door. FORECAST (door): it seals for good (override). Kept -> it only opens in
--     the 2009 layer - wait for the next pulse.
--  5  The core: everyone together. DECISION c4_ending:
--       Answer (the loop closes on you) | Silence (it is just morning) |
--       Counter-frequency (secret: all six ghost logs + every forecast kind broken once)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Services = script.Parent.Parent.Services
local StoryService = require(Services.StoryService)
local InteractionService = require(Services.InteractionService)
local CreatureService = require(Services.CreatureService)
local DecisionService = require(Services.DecisionService)
local ForecastService = require(Services.ForecastService)
local DirectorService = require(Services.DirectorService)
local PowerService = require(Services.PowerService)
local LoreService = require(Services.LoreService)
local DataService = require(Services.DataService)
local AchievementService = require(Services.AchievementService)
local BadgeTracker = require(Services.BadgeTracker)
local HorrorEvents = require(script.Parent.Parent.Director.HorrorEvents)
local ChapterKit = require(script.Parent.ChapterKit)
local MapKit = require(script.Parent.Parent.Map.MapKit)

local Chapter4 = {}
Chapter4.StartCheckpoint = "C4_START"

local k = ChapterKit.new("Chapter4", "ch4")

local GHOST_LOGS = { "log_okafor", "log_venn", "log_ehle", "log_0006", "log_kessler", "log_marek" }
local FORECAST_KINDS = { "power", "machine", "water", "door" }
local LAYER_NOW, LAYER_2009 = 32, 18 -- seconds per layer

local ORDER = { "arrival", "inside", "transformer", "blast", "core", "ending", "done" }
local state = {
	stage = "arrival",
	layer = "now",
	blastSealed = false,
	cageForecast = false,
}

local HINTS = {
	OBJ_C4_GATE = "HINT_C4_GATE",
	OBJ_C4_TRANSFORMER = "HINT_C4_TRANSFORMER",
	OBJ_C4_BLAST = "HINT_C4_BLAST",
	OBJ_C4_BLAST_WAIT = "HINT_C4_BLAST_WAIT",
	OBJ_C4_GATHER = "HINT_C4_GATHER",
}

local function after(stage: string): boolean
	return (table.find(ORDER, state.stage) or 0) >= (table.find(ORDER, stage) or 0)
end

---------------------------------------------------------------------------
-- Time layers
---------------------------------------------------------------------------
local function setLayer(layer: string)
	state.layer = layer
	k.setState("TimeLayer", layer)
	for _, part in CollectionService:GetTagged("FZ_Layer") do
		if part:IsA("BasePart") then
			local visible = part:GetAttribute("Layer") == layer
			local base = part:GetAttribute("BaseTransparency")
			part.Transparency = if visible then (if type(base) == "number" then base else 0) else 1
			part.CanCollide = visible and part:GetAttribute("BaseCollide") ~= false
			part.CanQuery = visible
			for _, child in part:GetChildren() do
				if child:IsA("Light") then
					child.Enabled = visible
				end
			end
		end
	end
end

-- Nobody gets buried when today's rubble comes back: move them out of the rubble volume.
local function clearRubbleZone()
	for _, player in k.players() do
		local root = k.rootOf(player)
		if root and math.abs(root.Position.X) < 6 and root.Position.Z < -172 and root.Position.Z > -194 then
			local character = player.Character
			if character then
				character:PivotTo(CFrame.new(0, 3, -168))
			end
		end
	end
end

local function pulse()
	Net.Event("Sfx"):FireAllClients("array_pulse", nil, 0.9)
	if state.layer == "now" then
		setLayer("2009")
		if state.blastSealed then
			-- in 2009 the blast door stood open
			k.unlock(k.door("BlastDoor"), true)
			state.blastSealed = false
			k.relay("RADIO_C4_BLAST_2009", nil, 1)
			k.objective("OBJ_C4_GATHER")
			state.stage = "core"
		end
	else
		clearRubbleZone()
		setLayer("now")
	end
end

local function startPulses()
	local current = k.token
	task.spawn(function()
		while k.active and k.token == current and not after("ending") do
			task.wait(if state.layer == "now" then LAYER_NOW - 5 else LAYER_2009 - 5)
			if not (k.active and k.token == current) or after("ending") then
				return
			end
			if state.layer == "2009" then
				k.world("SFX_PULSE_WARN", 0, 4)
			end
			task.wait(5)
			if k.active and k.token == current and not after("ending") then
				pulse()
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Forecasts
---------------------------------------------------------------------------
local function waterForecast()
	ForecastService.Start({
		id = "c4_flood",
		kind = "water",
		text = "RADIO_C4_FORECAST_FLOOD",
		hud = "FORECAST_MINE_FLOOD",
		seconds = 35,
		breakWith = "c4_pump",
		onKept = function()
			k.setFlood(true)
			PowerService.Set("PUMP", false)
			k.world("SFX_FLOOD")
			local door = k.door("PumpDoor")
			if door then
				k.lock(door)
			end
		end,
		onBroken = function() end,
		keptLine = "RADIO_C4_FORECAST_FLOOD_KEPT",
		brokenLine = "RADIO_C4_FORECAST_FLOOD_BROKEN",
	})
end

local function cageForecast()
	state.cageForecast = true
	ForecastService.Start({
		id = "c4_cage",
		kind = "machine",
		text = "RADIO_C4_FORECAST_CAGE",
		hud = "FORECAST_CAGE",
		seconds = 30,
		breakWith = "c4_brake",
		onKept = function()
			local cage = k.find("FZ_Interactable", function(i)
				return i:GetAttribute("InteractId") == "c4_brake"
			end)
			local position = if cage then cage.Position else Vector3.new(-74, 3, -122)
			k.sfx("metal_crash", position, 1)
			k.world("SFX_CAGE_CRASH")
			k.lock(k.door("LoopDoor")) -- the crash jams the loop route
			if CreatureService.Count() == 0 then
				CreatureService.Spawn()
			end
			CreatureService.Alert(position)
			k.after(20, waterForecast)
		end,
		onBroken = function()
			k.after(20, waterForecast)
		end,
		keptLine = "RADIO_C4_FORECAST_CAGE_KEPT",
		brokenLine = "RADIO_C4_FORECAST_CAGE_BROKEN",
	})
end

local function blastForecast()
	state.stage = "blast"
	k.objective("OBJ_C4_BLAST")
	ForecastService.Start({
		id = "c4_blast",
		kind = "door",
		text = "RADIO_C4_FORECAST_DOOR",
		hud = "FORECAST_BLAST",
		seconds = 40,
		breakWith = "c4_override",
		onKept = function()
			state.blastSealed = true
			k.world("SFX_SEAL")
			k.objective("OBJ_C4_BLAST_WAIT")
		end,
		onBroken = function()
			k.unlock(k.door("BlastDoor"), true)
			state.stage = "core"
			k.objective("OBJ_C4_GATHER")
		end,
		keptLine = "RADIO_C4_FORECAST_DOOR_KEPT",
		brokenLine = "RADIO_C4_FORECAST_DOOR_BROKEN",
	})
end

local function powerForecast()
	ForecastService.Start({
		id = "c4_transformer",
		kind = "power",
		text = "RADIO_C4_FORECAST_POWER",
		hud = "FORECAST_TRANSFORMER",
		seconds = 30,
		breakWith = "c4_breaker",
		onKept = function()
			PowerService.Set("MINE", false)
			PowerService.Set("TRANSFORMER", false)
			k.world("SFX_POWER_DOWN")
			k.after(6, blastForecast)
		end,
		onBroken = function()
			k.after(6, blastForecast)
		end,
		keptLine = "RADIO_C1_FORECAST_KEPT",
		brokenLine = "RADIO_C4_FORECAST_POWER_BROKEN",
	})
end

---------------------------------------------------------------------------
-- Endings
---------------------------------------------------------------------------
-- The secret ending: one player of the team carries all six ghost logs and has broken
-- every kind of forecast at least once (across all chapters).
local function counterEligible(): boolean
	for _, player in k.players() do
		local profile = DataService.Get(player)
		local data = profile and profile.Data
		if data then
			local ok = true
			for _, id in GHOST_LOGS do
				if not data.secrets.logs[id] then
					ok = false
				end
			end
			for _, kind in FORECAST_KINDS do
				if not data.secrets.forecastsBroken["kind:" .. kind] then
					ok = false
				end
			end
			if ok then
				return true
			end
		end
	end
	return false
end

local function playEnding(kind: string)
	state.stage = "done"
	k.step("Ending_" .. kind)
	ForecastService.Cancel()
	CreatureService.SetAIEnabled(false)
	CreatureService.Despawn()
	k.objective(nil)
	k.setState("Ending", kind)
	local name = k.randomName()
	if kind == "answer" then
		PowerService.Set("ARRAY", true)
		k.sequence({
			{ delay = 1, speaker = "SPEAKER_RELAY", text = "RADIO_C4_ANSWER_1", channel = "radio", duration = 5, critical = true },
			{ delay = 5.5, text = "SFX_STATIC", channel = "sfx", duration = 2 },
			{ delay = 2.5, speaker = "SPEAKER_RELAY", text = "RADIO_C4_ANSWER_2", params = { name = name }, channel = "radio", duration = 6, critical = true },
			{ delay = 7, text = "SFX_FAX", channel = "world", duration = 3 },
		})
		k.after(18, function()
			for _, player in k.players() do
				StoryService.ShowDocument(player, { title = "FAX_TITLE", body = "FAX_BODY_NEXT", date = os.time() + 24 * 60 * 60 })
			end
		end)
	elseif kind == "silence" then
		PowerService.Set("ARRAY", false)
		MapKit.ApplyLighting("dawn")
		k.sequence({
			{ delay = 1.5, speaker = "SPEAKER_RELAY", text = "RADIO_C4_SILENCE_1", channel = "radio", duration = 4, critical = true },
			{ delay = 4.5, speaker = "SPEAKER_RELAY", text = "RADIO_C4_SILENCE_2", channel = "radio", duration = 5, critical = true },
			{ delay = 6, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C4_SILENCE_3", channel = "radio", duration = 5 },
			{ delay = 6, text = "SFX_RADIOS_QUIET", channel = "world", duration = 4 },
		})
		k.after(20, function()
			for _, player in k.players() do
				StoryService.ShowDocument(player, { title = "FAX_TITLE", body = "FAX_BODY_EMPTY" })
			end
		end)
	else
		PowerService.Set("ARRAY", true)
		MapKit.ApplyLighting("day")
		k.sequence({
			{ delay = 1.5, speaker = "SPEAKER_RELAY", text = "RADIO_C4_COUNTER_1", channel = "radio", duration = 6, critical = true },
			{ delay = 7, text = "SFX_STATIC", channel = "sfx", duration = 2 },
			{ delay = 2.5, speaker = "SPEAKER_JUNE", text = "RADIO_C4_COUNTER_2", channel = "radio", duration = 5, critical = true },
			{ delay = 6, speaker = "SPEAKER_JUNE", text = "RADIO_C4_COUNTER_3", channel = "radio", duration = 6, critical = true },
		})
	end
	k.after(26, function()
		k.complete("ch4_complete", function(player)
			AchievementService.Award(player, "ending_" .. kind)
			if kind == "counter" then
				BadgeTracker.Award(player, "ending_counter")
			end
		end)
	end)
	k.after(30, function()
		k.ctx.finish()
	end)
end

local function askEnding()
	state.stage = "ending"
	k.step("Core")
	local options = { "DECISION_END_ANSWER", "DECISION_END_SILENCE" }
	local secret = counterEligible()
	if secret then
		table.insert(options, "DECISION_END_COUNTER")
	end
	k.sequence({
		{ delay = 0.5, speaker = "SPEAKER_RELAY", text = "RADIO_C4_CORE", channel = "radio", duration = 5, critical = true },
		{ delay = 5.5, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C4_CORE_UNKNOWN", channel = "radio", duration = 5, critical = true },
		{ delay = 5.5, speaker = if secret then "SPEAKER_RELAY" else nil, text = if secret then "RADIO_C4_CORE_SECRET" else "SFX_STATIC", channel = if secret then "radio" else "sfx", duration = 5 },
	})
	k.after(16, function()
		DecisionService.Ask({
			id = "c4_ending",
			prompt = "DECISION_C4_ENDING",
			options = options,
			seconds = 40,
			default = 2,
			onDecided = function(index)
				if k.active then
					playEnding(if index == 1 then "answer" elseif index == 2 then "silence" else "counter")
				end
			end,
		}, k.players)
	end)
end

---------------------------------------------------------------------------
-- Scares
---------------------------------------------------------------------------
local function beats()
	return {
		{ id = "c4_footsteps", kind = "footsteps", condition = function(_p, info)
			return info.alone and after("inside")
		end },
		{ id = "c4_flicker", kind = "flicker", condition = function(_p, info)
			return info.area ~= nil and after("inside")
		end },
		{ id = "c4_crew_2009", kind = "apparition", weight = 20, cooldown = 90, condition = function(_p, info)
			return state.layer == "2009" and (info.area == "PASSAGE" or info.area == "JUNCTION")
		end },
		{ id = "c4_voices", kind = "voices", once = true, weight = 15, condition = function(_p, info)
			return state.layer == "2009"
		end },
		{ id = "c4_name", kind = "namecall", once = true, weight = 20, condition = function(_p, info)
			return info.alone and after("transformer")
		end, data = function(player)
			return { name = player.DisplayName, answered = true }
		end },
	}
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function reset()
	k.reset()
	state.stage = "arrival"
	state.blastSealed = false
	state.cageForecast = false
	setLayer("now")
	k.setState("TimeLayer", nil)
	k.setState("Ending", nil)
	k.setFlood(false)
	ForecastService.Cancel()
	DecisionService.Cancel()
	DirectorService.Stop()
	StoryService.ResetFlags()
	StoryService.SetObjective(nil)
	MapKit.ApplyLighting("mine")
end

function Chapter4.Begin()
	reset()
	k.active = true
	CreatureService.SetDifficulty({ speed = 1.08, hearing = 1.25 })
	DirectorService.Configure(HorrorEvents.With(beats()), HINTS, k.players)
	k.zones({
		{ id = "junction", center = Vector3.new(0, 0, -130), radius = 18, when = function()
			return state.stage == "inside" and not state.cageForecast
		end, fn = function()
			k.ctx.setCheckpoint("C4_JUNCTION")
			k.relay("RADIO_C4_JUNCTION", nil, 0.5)
			k.after(5, cageForecast)
		end },
		{ id = "transformer", center = Vector3.new(0, 0, -240), radius = 16, when = function()
			return state.stage == "inside"
		end, fn = function()
			state.stage = "transformer"
			k.step("Transformer")
			k.ctx.setCheckpoint("C4_TRANSFORMER")
			k.rewardAll(Config.Rewards.Relay)
			if ForecastService.IsActive() then
				ForecastService.Cancel()
			end
			k.after(3, powerForecast)
		end },
	})
	k.every(35, function()
		return after("inside") and not after("ending")
	end, k.huntPulse)
end

function Chapter4.Stop()
	k.active = false
	reset()
	CreatureService.SetDifficulty({})
end

function Chapter4.Init(context)
	k.ctx = context
	ForecastService.Breakable("c4_brake")
	ForecastService.Breakable("c4_pump")
	ForecastService.Breakable("c4_breaker")
	ForecastService.Breakable("c4_override")

	InteractionService.Register("c4_winch", function(_player, lever)
		if not k.active or state.stage ~= "arrival" then
			return
		end
		state.stage = "inside"
		k.step("Gate")
		k.sfx("relay_activate", (lever :: BasePart).Position)
		k.unlock(k.door("MineGate"), true)
		k.objective("OBJ_C4_TRANSFORMER")
		k.relay("RADIO_C4_INSIDE", nil, 2)
		startPulses()
		k.after(25, function()
			if CreatureService.Count() == 0 then
				CreatureService.Spawn()
				k.relay("RADIO_C4_WAKE", nil, 0)
			end
		end)
	end)

	InteractionService.Register("c4_core", function(player, console)
		if not k.active or state.stage ~= "core" then
			return
		end
		local here, total = k.near((console :: BasePart).Position, 24)
		if here < total then
			Net.Event("Notify"):FireClient(player, "C4_NEED_TEAM", { here = here, total = total })
			return
		end
		k.ctx.setCheckpoint("C4_CORE")
		askEnding()
	end)

	Players.PlayerRemoving:Connect(function() end)
end

function Chapter4.OnPlayerEntered(player: Player, firstTime: boolean)
	if not firstTime or not k.active or state.stage ~= "arrival" then
		return
	end
	k.step("Arrival")
	local lines = {
		{ delay = 2, speaker = "SPEAKER_RELAY", text = "RADIO_C4_001", channel = "radio", duration = 5 },
		{ delay = 5.5, speaker = "SPEAKER_RELAY", text = "RADIO_C4_002", channel = "radio", duration = 5 },
	}
	-- consequences of earlier choices
	if k.choice("c3_recorder") == 1 then
		table.insert(lines, { delay = 6, speaker = "SPEAKER_RELAY", text = "RADIO_C4_RECORDER", channel = "radio", duration = 6 })
	end
	if k.choice("c2_trust") == 1 then
		table.insert(lines, { delay = 6, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C4_UNKNOWN_TRUSTED", channel = "radio", duration = 5 })
	end
	StoryService.Sequence(player, lines)
	k.after(14, function()
		if state.stage == "arrival" and StoryService.GetObjective() == nil then
			k.objective("OBJ_C4_GATE")
		end
	end)
	k.after(16, function()
		if player.Parent then
			LoreService.Unlock(player, "rec_c4_arrival", true)
		end
	end)
end

return Chapter4
