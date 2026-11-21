-- Chapter 3 "The Protocol" in the chapel and the archive bunker beneath the hill.
-- The night of 2009 is rebuilt from tapes (listening + ordering, no codes), and the big
-- twist: the Relay is your own team from an earlier run.
--
--  1  Forest path -> chapel (zone) -> search the altar -> hidden passage to the archive
--  2  FORECAST (power): "the archive goes dark" (breaker in the corridor)
--  3  Tape puzzle: five recorders, each holds one fragment of 02:14 (random per run).
--     Listening takes the tape along; the master deck only accepts them in time order.
--     A wrong tape resets the deck - loudly. FORECAST (door) after two tapes: the archive
--     gate (winch).
--  4  The sealed operator room opens: a radio painted like YOUR radio, a plaque with your
--     names and "RUN 0007", the Relay's own recorder.
--  5  DECISION c3_recorder: take the recorder along or destroy it (chapter 4 reacts)
--  6  The Listener hunts. Ring the bell in the tower -> end.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
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
local PowerService = require(Services.PowerService)
local LoreService = require(Services.LoreService)
local DataService = require(Services.DataService)
local AchievementService = require(Services.AchievementService)
local HorrorEvents = require(script.Parent.Parent.Director.HorrorEvents)
local ChapterKit = require(script.Parent.ChapterKit)

local Chapter3 = {}
Chapter3.StartCheckpoint = "C3_START"

local k = ChapterKit.new("Chapter3", "ch3")
local TAPES = 5

local ORDER = { "arrival", "chapel", "archive", "tapes", "reveal", "recorder", "escape", "done" }
local state = {
	stage = "arrival",
	slotToFragment = {} :: { [number]: number },
	accepted = 0,
	gateForecastDone = false,
	recorderPlayed = false,
}

local HINTS = {
	OBJ_C3_CHAPEL = "HINT_C3_CHAPEL",
	OBJ_C3_ALTAR = "HINT_C3_ALTAR",
	OBJ_C3_ARCHIVE = "HINT_C3_ARCHIVE",
	OBJ_C3_TAPES = "HINT_C3_TAPES",
	OBJ_C3_OPERATOR = "HINT_C3_OPERATOR",
	OBJ_C3_BELL = "HINT_C3_BELL",
}

local function after(stage: string): boolean
	return (table.find(ORDER, state.stage) or 0) >= (table.find(ORDER, stage) or 0)
end

local function clearTapes()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("FZ_Tape", nil)
	end
end

local function deckLamp(on: boolean)
	local lamp = k.find("FZ_Interactable", function(i)
		return i:GetAttribute("InteractId") == "c3_deck"
	end)
	local parent = lamp and lamp.Parent
	if parent then
		for _, child in parent:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute("DeckLamp") then
				child.Color = if on then Color3.fromRGB(90, 220, 140) else Color3.fromRGB(200, 40, 30)
			end
		end
	end
end

-- The twist props: the radio takes the colour of a player's equipped radio skin, the plaque
-- lists the team's display names.
local function stageTwist()
	local names = {}
	local radioColor = Catalog.DefaultRadioColor
	for _, player in k.players() do
		table.insert(names, player.DisplayName)
		local profile = DataService.Get(player)
		local skin = profile and profile.Data.equipped and profile.Data.equipped.radioSkin
		local item = skin and Catalog.Items[skin]
		if item and item.color then
			radioColor = item.color
		end
	end
	local radio = k.find("FZ_Interactable", function(i)
		return i:GetAttribute("InteractId") == "c3_relay_recorder"
	end)
	local props = radio and radio.Parent
	if props then
		for _, child in props:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute("TwistRadio") then
				child.Color = radioColor
			end
			if child:IsA("BasePart") and child.Name == "TwistPlaque" then
				local label = child:FindFirstChild("TwistPlaqueText", true)
				if label and label:IsA("TextLabel") then
					label.Text = "DURCHLAUF 0007\n" .. table.concat(names, "  ·  ")
				end
			end
		end
	end
end

local function resetTwist()
	local radio = k.find("FZ_Interactable", function(i)
		return i:GetAttribute("InteractId") == "c3_relay_recorder"
	end)
	local props = radio and radio.Parent
	if props then
		for _, child in props:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute("TwistRadio") then
				child.Color = Color3.fromRGB(40, 42, 44)
			end
			if child:IsA("BasePart") and child.Name == "TwistPlaque" then
				local label = child:FindFirstChild("TwistPlaqueText", true)
				if label and label:IsA("TextLabel") then
					label.Text = "DURCHLAUF 0007"
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Stages
---------------------------------------------------------------------------
local function powerForecast()
	ForecastService.Start({
		id = "c3_archive_dark",
		kind = "power",
		text = "RADIO_C3_FORECAST_POWER",
		hud = "FORECAST_ARCHIVE_DARK",
		seconds = 30,
		breakWith = "c3_breaker",
		onKept = function()
			PowerService.Set("ARCHIVE", false)
			k.world("SFX_POWER_DOWN")
			local breaker = k.interactable("c3_breaker")
			if breaker then
				CreatureService.Alert(breaker.Position)
			end
		end,
		onBroken = function() end,
		keptLine = "RADIO_C1_FORECAST_KEPT",
		brokenLine = "RADIO_C3_FORECAST_POWER_BROKEN",
	})
end

local function gateForecast()
	state.gateForecastDone = true
	ForecastService.Start({
		id = "c3_archive_gate",
		kind = "door",
		text = "RADIO_C3_FORECAST_GATE",
		hud = "FORECAST_ARCHIVE_GATE",
		seconds = 35,
		breakWith = "c3_winch",
		onKept = function()
			local gate = k.door("ArchiveGate")
			k.lock(gate)
			k.world("SFX_GATE_DOWN")
			if gate then
				CreatureService.Alert(gate.Position)
			end
			k.after(40, function()
				if gate then
					DoorService.SetLocked(gate, false)
				end
			end)
		end,
		onBroken = function() end,
		keptLine = "RADIO_C3_FORECAST_GATE_KEPT",
		brokenLine = "RADIO_C3_FORECAST_GATE_BROKEN",
	})
end

local function startTapes()
	state.stage = "tapes"
	k.step("Tapes")
	k.objective("OBJ_C3_TAPES", { count = 0, total = TAPES })
	k.relay("RADIO_C3_TAPES", nil, 2)
	deckLamp(false)
end

local function reveal()
	state.stage = "reveal"
	k.step("Reveal")
	ForecastService.Cancel()
	clearTapes()
	deckLamp(true)
	stageTwist()
	k.unlock(k.door("Sealed"), true)
	k.rewardAll(Config.Rewards.Relay)
	k.ctx.setCheckpoint("C3_OPERATOR")
	k.sequence({
		{ delay = 1, text = "SFX_SEAL", channel = "world", duration = 3 },
		{ delay = 3, speaker = "SPEAKER_RELAY", text = "RADIO_C3_OPEN", channel = "radio", duration = 5 },
	})
	k.objective("OBJ_C3_OPERATOR")
end

local function askRecorder()
	DecisionService.Ask({
		id = "c3_recorder",
		prompt = "DECISION_C3_RECORDER",
		options = { "DECISION_TAKE_RECORDER", "DECISION_DESTROY_RECORDER" },
		seconds = 25,
		default = 1,
		onDecided = function(index)
			if not k.active then
				return
			end
			local recorder = k.interactable("c3_relay_recorder")
			if index == 1 then
				k.relay("RADIO_C3_TAKEN", nil, 1)
			else
				if recorder then
					k.sfx("creature_static_burst", recorder.Position)
				end
				k.relay("RADIO_C3_DESTROYED", nil, 2)
			end
			state.stage = "escape"
			CreatureService.SetDifficulty({ speed = 1.12, hearing = 1.3 })
			if recorder then
				CreatureService.Alert(recorder.Position)
			end
			k.after(5, function()
				k.unknown("RADIO_C3_ESCAPE", nil, 0)
				k.objective("OBJ_C3_BELL")
			end)
		end,
	}, k.players)
end

---------------------------------------------------------------------------
-- Scares
---------------------------------------------------------------------------
local function beats()
	return {
		{ id = "c3_footsteps", kind = "footsteps", condition = function(_p, info)
			return info.alone and after("chapel")
		end },
		{ id = "c3_flicker", kind = "flicker", condition = function(_p, info)
			return info.area ~= nil and after("archive")
		end },
		{ id = "c3_pews", kind = "apparition", once = true, weight = 20, condition = function(_p, info)
			return info.area == "NAVE" and after("chapel")
		end },
		{ id = "c3_cemetery", kind = "apparition", once = true, weight = 10, condition = function(_p, info)
			return info.area == "CEMETERY" and after("escape")
		end },
		{ id = "c3_name", kind = "namecall", once = true, weight = 20, condition = function(_p, info)
			return info.alone and after("tapes")
		end, data = function(player)
			return { name = player.DisplayName, answered = false }
		end },
		{ id = "c3_voices", kind = "voices", once = true, weight = 10, condition = function(_p, info)
			return info.area == "ARCHIVE" or info.area == "TAPES"
		end },
	}
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function reset()
	k.reset()
	state.stage = "arrival"
	state.accepted = 0
	state.gateForecastDone = false
	state.recorderPlayed = false
	-- random fragment per recorder slot
	local fragments = { 1, 2, 3, 4, 5 }
	for i = #fragments, 2, -1 do
		local j = math.random(1, i)
		fragments[i], fragments[j] = fragments[j], fragments[i]
	end
	for slot = 1, TAPES do
		state.slotToFragment[slot] = fragments[slot]
	end
	clearTapes()
	resetTwist()
	ForecastService.Cancel()
	DecisionService.Cancel()
	DirectorService.Stop()
	StoryService.ResetFlags()
	StoryService.SetObjective(nil)
	k.setState("Weather", nil)
end

function Chapter3.Begin()
	reset()
	k.active = true
	k.setState("Weather", "fog")
	DirectorService.Configure(HorrorEvents.With(beats()), HINTS, k.players)
	k.zones({
		{ id = "chapel", center = Vector3.new(0, 0, 10), radius = 26, when = function()
			return state.stage == "arrival"
		end, fn = function()
			state.stage = "chapel"
			k.step("Chapel")
			k.ctx.setCheckpoint("C3_CHAPEL")
			k.unknown("RADIO_C3_WHISPER", nil, 1)
			k.objective("OBJ_C3_ALTAR")
		end },
		{ id = "archive", center = Vector3.new(48, 0, -20), radius = 10, when = function()
			return state.stage == "archive"
		end, fn = function()
			k.ctx.setCheckpoint("C3_ARCHIVE")
			k.relay("RADIO_C3_ARCHIVE", nil, 0.5)
			k.after(6, powerForecast)
			k.after(8, startTapes)
		end },
		{ id = "operator", center = Vector3.new(85, 0, -75), radius = 12, when = function()
			return state.stage == "reveal"
		end, fn = function()
			state.stage = "recorder"
			k.objective("OBJ_C3_RECORDER")
			k.relay("RADIO_C3_OPERATOR", nil, 2)
		end },
	})
	k.every(30, function()
		return state.stage == "escape"
	end, k.huntPulse)
	-- the bell tolls once when the team arrives (the first sound of the chapter)
	k.after(4, function()
		local bell = k.interactable("c3_bell")
		if bell then
			k.sfx("bell_toll", bell.Position + Vector3.new(0, 34, 0), 1)
		end
	end)
end

function Chapter3.Stop()
	k.active = false
	reset()
	CreatureService.SetDifficulty({})
end

function Chapter3.Init(context)
	k.ctx = context
	ForecastService.Breakable("c3_breaker")
	ForecastService.Breakable("c3_winch")

	InteractionService.Register("c3_altar", function(_player, altar)
		if not k.active or state.stage ~= "chapel" then
			return
		end
		state.stage = "archive"
		k.step("Altar")
		k.sfx("door_open", (altar :: BasePart).Position)
		k.unlock(k.door("Hidden"), true)
		k.world("SFX_PASSAGE")
		k.objective("OBJ_C3_ARCHIVE")
		k.after(20, function()
			if CreatureService.Count() == 0 then
				CreatureService.Spawn()
				k.relay("RADIO_C3_WAKE", nil, 0)
			end
		end)
	end)

	InteractionService.Register("c3_tape", function(player, recorder)
		if not k.active or state.stage ~= "tapes" then
			return
		end
		local slot = tonumber(recorder:GetAttribute("TapeSlot"))
		local fragment = slot and state.slotToFragment[slot]
		if not fragment then
			return
		end
		k.sfx("tape_play", (recorder :: BasePart).Position)
		NoiseService.Emit((recorder :: BasePart).Position, 18, player)
		StoryService.Sequence("all", {
			{ delay = 1.2, speaker = "SPEAKER_TAPE", text = "TAPE_FRAGMENT_" .. fragment, channel = "radio", duration = 6, critical = true },
		})
		player:SetAttribute("FZ_Tape", fragment)
		Net.Event("Notify"):FireClient(player, "TAPE_TAKEN", { slot = slot })
	end)

	InteractionService.Register("c3_deck", function(player, deck)
		if not k.active or state.stage ~= "tapes" then
			return
		end
		local tape = player:GetAttribute("FZ_Tape")
		if type(tape) ~= "number" then
			Net.Event("Notify"):FireClient(player, "TAPE_NONE")
			return
		end
		player:SetAttribute("FZ_Tape", nil)
		if tape == state.accepted + 1 then
			state.accepted += 1
			k.sfx("relay_activate", (deck :: BasePart).Position)
			k.objective("OBJ_C3_TAPES", { count = state.accepted, total = TAPES })
			if state.accepted == 2 and not state.gateForecastDone and not ForecastService.IsActive() then
				k.after(4, gateForecast)
			end
			if state.accepted >= TAPES then
				reveal()
			end
		else
			-- wrong order: the deck chews the tape, everyone (and everything) hears it
			state.accepted = 0
			k.sfx("creature_static_burst", (deck :: BasePart).Position, 1)
			NoiseService.Emit((deck :: BasePart).Position, 70, nil)
			CreatureService.Alert((deck :: BasePart).Position)
			k.relay("RADIO_C3_TAPE_WRONG", nil, 0.5)
			k.objective("OBJ_C3_TAPES", { count = 0, total = TAPES })
		end
	end)

	InteractionService.Register("c3_relay_recorder", function(_player, recorder)
		if not k.active or state.stage ~= "recorder" or state.recorderPlayed then
			return
		end
		state.recorderPlayed = true
		k.step("Recorder")
		k.objective(nil)
		k.sfx("tape_play", (recorder :: BasePart).Position)
		LoreService.UnlockAll(k.players(), "rec_c3_run0007")
		k.sequence({
			{ delay = 1.5, speaker = "SPEAKER_RELAY", text = "RADIO_C3_REC_1", channel = "radio", duration = 5, critical = true },
			{ delay = 5.5, speaker = "SPEAKER_RELAY", text = "RADIO_C3_REC_2", channel = "radio", duration = 5, critical = true },
			{ delay = 5.5, speaker = "SPEAKER_RELAY", text = "RADIO_C3_REC_3", channel = "radio", duration = 6, critical = true },
			{ delay = 6.5, speaker = "SPEAKER_RELAY", text = "RADIO_C3_REC_4", channel = "radio", duration = 5, critical = true },
		})
		for _, player in k.players() do
			AchievementService.Award(player, "run_0007")
		end
		k.after(24, askRecorder)
	end)

	InteractionService.Register("c3_bell", function(_player, rope)
		if not k.active or state.stage ~= "escape" then
			return
		end
		state.stage = "done"
		k.step("Bell")
		ForecastService.Cancel()
		CreatureService.SetAIEnabled(false)
		k.objective(nil)
		for i = 0, 2 do
			task.delay(i * 2.5, function()
				k.sfx("bell_toll", (rope :: BasePart).Position + Vector3.new(0, 34, 0), 1)
			end)
		end
		k.sequence({
			{ delay = 2, text = "SFX_BELL", channel = "world", duration = 4 },
			{ delay = 6, speaker = "SPEAKER_RELAY", text = "RADIO_C3_END_RELAY", channel = "radio", duration = 5 },
			{ delay = 5.5, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C3_END_UNKNOWN", channel = "radio", duration = 5, critical = true },
		})
		k.after(18, function()
			k.complete("ch3_complete")
		end)
		k.after(21, function()
			k.ctx.finish()
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("FZ_Tape", nil)
	end)
end

function Chapter3.OnPlayerEntered(player: Player, firstTime: boolean)
	if not firstTime or not k.active or state.stage ~= "arrival" then
		return
	end
	k.step("Arrival")
	StoryService.Sequence(player, {
		{ delay = 2, speaker = "SPEAKER_RELAY", text = "RADIO_C3_001", channel = "radio", duration = 5 },
		{ delay = 5.5, speaker = "SPEAKER_RELAY", text = "RADIO_C3_002", channel = "radio", duration = 4.5 },
	})
	k.after(12, function()
		if state.stage == "arrival" and StoryService.GetObjective() == nil then
			k.objective("OBJ_C3_CHAPEL")
		end
	end)
end

return Chapter3
