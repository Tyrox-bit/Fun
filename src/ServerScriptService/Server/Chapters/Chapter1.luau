-- Chapter 1 "The Reception" on Relay Station 07.
-- The gameplay loop of the design: Explore -> Discover -> Understand -> Decide -> Act ->
-- Consequences -> new secrets. Built only from the generic systems:
--   DecisionService (team votes), ForecastService (predictions you can break),
--   DirectorService (scares + hints), PowerService (systems), StoryService (lines).
--
--  1  Gate: arrival transmission (per player) -> gatehouse fax "sent tomorrow, 02:14"
--  2  DECISION: the unknown voice asks you to answer. Answer or stay silent? (saved)
--  3  Control room: emergency power carries only 2 of 3 systems (levers, changeable):
--       cameras (see where it is) / hall lights (see better - and be seen) /
--       ventilation (fans mask your steps - but it can use the vents)
--  4  3 fuses in 3 random sectors. 1st fuse wakes the creature (earlier if you answered)
--  5  FORECAST 1 at the 2nd fuse: "lights in Sector A go out" - hold breaker A to break it
--  6  Relay B -> core doors open. FORECAST 2: "the generator in E fails" - restart it
--  7  Core -> the Relay says a player's name ("this time, not the left door")
--  8  Antenna -> ending line -> back to the menu, chapter saved as completed

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local SessionState = require(Shared.SessionState)

local Services = script.Parent.Parent.Services
local StoryService = require(Services.StoryService)
local InteractionService = require(Services.InteractionService)
local PowerService = require(Services.PowerService)
local CreatureService = require(Services.CreatureService)
local DataService = require(Services.DataService)
local NoiseService = require(Services.NoiseService)
local DecisionService = require(Services.DecisionService)
local ForecastService = require(Services.ForecastService)
local DirectorService = require(Services.DirectorService)
local DoorService = require(Services.DoorService)

local Chapter1 = {}
Chapter1.StartCheckpoint = "C1_START"

local TOTAL_FUSES = 3
local SYSTEMS = { "cameras", "halls", "vents" }

local active = false
local ctx = nil -- { setCheckpoint, finish, playersInGame }
local fuseFolder: Folder? = nil

local state = {
	stage = "arrival", -- arrival | decision | control | power | fuses | relay | core | antenna | done
	fuses = 0,
	answered = false,
	systems = {} :: { [string]: boolean },
	powerChosenOnce = false,
	completedBy = {} :: { [Player]: boolean },
}

local ARRIVAL = {
	{ delay = 1.5, text = "SFX_STATIC", channel = "sfx", duration = 2 },
	{ delay = 1.0, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C1_001", channel = "radio", duration = 5.5 },
	{ delay = 5.8, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C1_002", channel = "radio", duration = 4 },
	{ delay = 5.0, text = "SFX_FAX", channel = "world", duration = 3 },
}

local HINTS = {
	OBJECTIVE_CHECK_GATEHOUSE = "HINT_GATEHOUSE",
	OBJECTIVE_REACH_CONTROL = "HINT_CONTROL",
	OBJECTIVE_POWER = "HINT_POWER",
	OBJECTIVE_FIND_FUSES = "HINT_FUSES",
	OBJECTIVE_RELAY_B = "HINT_RELAY",
	OBJECTIVE_CORE = "HINT_CORE",
	OBJECTIVE_ANTENNA = "HINT_ANTENNA",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function rewardAll(amount: number)
	for _, player in ctx.playersInGame() do
		DataService.Grant(player, amount)
	end
end

local function sfxAt(name: string, position: Vector3)
	Net.Event("Sfx"):FireAllClients(name, position)
end

local function relay(text: string, params: { [string]: any }?, delay: number?)
	StoryService.Sequence("all", { { delay = delay or 0.5, speaker = "SPEAKER_RELAY", text = text, params = params, channel = "radio", duration = 4.5 } })
end

local function unknown(text: string, params: { [string]: any }?, delay: number?)
	StoryService.Sequence("all", { { delay = delay or 0.5, speaker = "SPEAKER_UNKNOWN", text = text, params = params, channel = "radio", duration = 5 } })
end

local function patrolCenter(area: string): Vector3?
	for _, node in CollectionService:GetTagged("FZ_CreaturePatrol") do
		if node:IsA("BasePart") and node:GetAttribute("Area") == area then
			return node.Position
		end
	end
	return nil
end

local function randomName(): string
	local team = ctx.playersInGame()
	local named = team[math.random(1, math.max(1, #team))]
	return if named then named.DisplayName else ""
end

local function wakeCreature()
	if CreatureService.Get() then
		return
	end
	CreatureService.Spawn()
	relay("RADIO_C1_WAKE", nil, 1.5)
end

---------------------------------------------------------------------------
-- Power distribution (decision in the world, can be changed any time)
---------------------------------------------------------------------------
local function applySystems()
	local s = state.systems
	SessionState.Set("Cameras", s.cameras == true)
	if not s.cameras then
		SessionState.Set("CctvArea", nil)
	end
	PowerService.Set("HALLS", s.halls == true)
	CreatureService.SetSightScale(if s.halls then 1.3 else 1)
	CreatureService.SetVentsEnabled(s.vents == true)
	NoiseService.SetFootstepScale(if s.vents then 0.6 else 1)
	for _, lamp in CollectionService:GetTagged("FZ_LeverLamp") do
		if lamp:IsA("BasePart") then
			local on = s[lamp:GetAttribute("LeverLamp")] == true
			lamp.Color = if on then Color3.fromRGB(90, 220, 140) else Color3.fromRGB(40, 40, 38)
		end
	end
end

local function systemsOn(): number
	local count = 0
	for _, name in SYSTEMS do
		if state.systems[name] then
			count += 1
		end
	end
	return count
end

local function spawnFuses()
	if fuseFolder then
		fuseFolder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "FZ_Fuses"
	folder.Parent = workspace
	fuseFolder = folder
	local bySector: { [string]: { BasePart } } = {}
	for _, spot in CollectionService:GetTagged("FZ_FuseSpot") do
		if spot:IsA("BasePart") then
			local sector = tostring(spot:GetAttribute("Sector"))
			bySector[sector] = bySector[sector] or {}
			table.insert(bySector[sector], spot)
		end
	end
	local sectors = {}
	for sector in bySector do
		table.insert(sectors, sector)
	end
	for i = #sectors, 2, -1 do
		local j = math.random(1, i)
		sectors[i], sectors[j] = sectors[j], sectors[i]
	end
	for i = 1, math.min(TOTAL_FUSES, #sectors) do
		local spots = bySector[sectors[i]]
		local spot = spots[math.random(1, #spots)]
		local fuse = Instance.new("Part")
		fuse.Name = "Fuse"
		fuse.Size = Vector3.new(0.5, 0.5, 1.4)
		fuse.Color = Color3.fromRGB(214, 170, 60)
		fuse.Material = Enum.Material.Metal
		fuse.Anchored = true
		fuse.CanCollide = false
		fuse.CFrame = spot.CFrame * CFrame.new(0, 0.1, 0)
		local glow = Instance.new("PointLight")
		glow.Range = 5
		glow.Brightness = 0.8
		glow.Color = Color3.fromRGB(255, 200, 90)
		glow.Parent = fuse
		fuse:SetAttribute("InteractId", "c1_fuse")
		fuse:SetAttribute("ActionKey", "INTERACT_PICKUP")
		fuse:SetAttribute("ObjectKey", "OBJECT_FUSE")
		fuse:SetAttribute("MaxDistance", 7)
		fuse.Parent = folder
		CollectionService:AddTag(fuse, "FZ_Interactable")
	end
end

local function startFuses()
	state.stage = "fuses"
	relay("RADIO_C1_TERMINAL", nil, 3)
	spawnFuses()
	StoryService.SetObjective("OBJECTIVE_FIND_FUSES", { count = 0, total = TOTAL_FUSES })
	if state.answered then
		-- Consequence of answering: the station knows you are here. It wakes up now.
		task.delay(8, function()
			if active then
				wakeCreature()
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Decision: answer the voice?
---------------------------------------------------------------------------
local function askAnswer()
	state.stage = "decision"
	unknown("RADIO_C1_ASK", nil, 2)
	task.delay(6, function()
		if not active then
			return
		end
		DecisionService.Ask({
			id = "c1_answer",
			prompt = "DECISION_C1_ANSWER",
			options = { "DECISION_ANSWER", "DECISION_SILENT" },
			seconds = 20,
			default = 2,
			onDecided = function(index)
				if not active then
					return
				end
				state.answered = index == 1
				if state.answered then
					unknown("RADIO_C1_ANSWERED", { name = randomName() }, 1)
					relay("RADIO_C1_RELAY_ANSWERED", nil, 7)
				else
					unknown("RADIO_C1_SILENT", nil, 1)
					relay("RADIO_C1_RELAY_SILENT", nil, 6)
				end
				task.delay(10, function()
					if active and state.stage == "decision" then
						state.stage = "control"
						StoryService.SetObjective("OBJECTIVE_REACH_CONTROL")
					end
				end)
			end,
		}, ctx.playersInGame)
	end)
end

---------------------------------------------------------------------------
-- Forecasts
---------------------------------------------------------------------------
local function forecastLightsA()
	ForecastService.Start({
		id = "c1_lights_a",
		text = "RADIO_C1_FORECAST",
		hud = "FORECAST_LIGHTS_A",
		seconds = 30,
		breakWith = "c1_breaker_a",
		onKept = function()
			PowerService.Set("A", false)
			local center = patrolCenter("A")
			if center then
				sfxAt("power_down", center)
				CreatureService.Alert(center)
			end
			StoryService.Say("all", { text = "SFX_POWER_DOWN", channel = "world", duration = 3, critical = true })
		end,
		onBroken = function() end,
		keptLine = "RADIO_C1_FORECAST_KEPT",
		brokenLine = "RADIO_C1_FORECAST_BROKEN",
	})
end

local function forecastGenerator()
	ForecastService.Start({
		id = "c1_generator_e",
		text = "RADIO_C1_FORECAST_GEN",
		hud = "FORECAST_GENERATOR_E",
		seconds = 40,
		breakWith = "generator",
		onKept = function()
			PowerService.Set("E", false)
			local center = patrolCenter("E")
			if center then
				sfxAt("power_down", center)
				CreatureService.Alert(center)
			end
			StoryService.Say("all", { text = "SFX_POWER_DOWN", channel = "world", duration = 3, critical = true })
		end,
		onBroken = function(player)
			sfxAt("relay_activate", (player.Character :: Model):GetPivot().Position)
		end,
		keptLine = "RADIO_C1_FORECAST_KEPT",
		brokenLine = "RADIO_C1_FORECAST_GEN_BROKEN",
	})
end

---------------------------------------------------------------------------
-- Scares (HorrorDirector beats) - the moments of the first ten minutes
---------------------------------------------------------------------------
local function inBuilding(position: Vector3): boolean
	return math.abs(position.X) < 100 and position.Z > -85 and position.Z < 70
end

local function screenNear(position: Vector3, radius: number): boolean
	for _, screen in CollectionService:GetTagged("FZ_CctvScreen") do
		if screen:IsA("BasePart") and (screen.Position - position).Magnitude < radius then
			return true
		end
	end
	return false
end

local function beats()
	local function after(stage: string): boolean
		local order = { "arrival", "decision", "control", "power", "fuses", "relay", "core", "antenna", "done" }
		return (table.find(order, state.stage) or 0) >= (table.find(order, stage) or 0)
	end
	return {
		{
			-- The monitor shows the team in a hallway 20 s in the future - and something
			-- behind the last person. Only ONE player sees the figure; the others see the
			-- same feed without it.
			id = "cctv_future",
			kind = "cctv",
			once = true,
			others = true,
			condition = function(_player, info)
				return state.systems.cameras == true and after("power") and screenNear(info.position, 12)
			end,
			data = function()
				return { withFigure = true, offset = 20 }
			end,
		},
		{
			id = "name_call",
			kind = "namecall",
			once = true,
			condition = function(_player, info)
				return info.alone and after("fuses") and inBuilding(info.position)
			end,
			data = function(player)
				return { name = player.DisplayName, answered = state.answered }
			end,
		},
		{
			-- A figure at the end of a hallway that is gone a moment later.
			id = "apparition_hall",
			kind = "apparition",
			once = true,
			condition = function(_player, info)
				return info.area == "HALL" and after("control")
			end,
		},
		{
			id = "apparition_late",
			kind = "apparition",
			once = true,
			condition = function(_player, info)
				return info.area ~= nil and info.area ~= "HALL" and after("relay")
			end,
		},
		{
			id = "footsteps",
			kind = "footsteps",
			condition = function(_player, info)
				return info.alone and inBuilding(info.position) and after("control")
			end,
		},
		{
			id = "flicker",
			kind = "flicker",
			condition = function(_player, info)
				return info.area ~= nil and info.area ~= "HALL" and after("control")
			end,
		},
		{
			-- A familiar room changes: a door behind you closes by itself.
			id = "door_slam",
			kind = "doorslam",
			once = true,
			condition = function(_player, info)
				return after("fuses") and inBuilding(info.position)
			end,
			data = function(player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					for _, panel in CollectionService:GetTagged("FZ_Door") do
						if panel:IsA("BasePart") and panel:GetAttribute("Open") and (panel.Position - root.Position).Magnitude < 25 then
							DoorService.Close(panel)
							break
						end
					end
				end
				return {}
			end,
		},
	}
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function reset()
	state.stage = "arrival"
	state.fuses = 0
	state.answered = false
	state.powerChosenOnce = false
	table.clear(state.systems)
	table.clear(state.completedBy)
	if fuseFolder then
		fuseFolder:Destroy()
		fuseFolder = nil
	end
	ForecastService.Cancel()
	DecisionService.Cancel()
	DirectorService.Stop()
	StoryService.ResetFlags()
	StoryService.SetObjective(nil)
	SessionState.Set("Cameras", nil)
	SessionState.Set("CctvArea", nil)
end

function Chapter1.Begin()
	reset()
	active = true
	applySystems()
	DirectorService.Configure(beats(), HINTS, ctx.playersInGame)
end

function Chapter1.Stop()
	active = false
	reset()
	NoiseService.SetFootstepScale(1)
	CreatureService.SetVentsEnabled(true)
	CreatureService.SetSightScale(1)
end

-- Registers interaction handlers once. Every handler ignores input unless chapter 1 is
-- the running session (the same objects are used by the survival mode).
function Chapter1.Init(context)
	ctx = context
	ForecastService.Breakable("c1_breaker_a")
	ForecastService.Breakable("generator")

	InteractionService.Register("c1_fax", function(player)
		if not active then
			return
		end
		StoryService.ShowDocument(player, { title = "FAX_TITLE", body = "FAX_BODY", date = os.time() + 24 * 60 * 60 })
		if StoryService.GetFlag("C1_FaxRead") then
			return
		end
		StoryService.SetFlag("C1_FaxRead", true)
		relay("RADIO_C1_003", nil, 3)
		askAnswer()
	end)

	InteractionService.Register("c1_calendar", function(player)
		if not active then
			return
		end
		StoryService.ShowDocument(player, { title = "CAL_TITLE", body = "CAL_BODY" })
		DataService.Mutate(player, function(data)
			data.secrets.logs.calendar_2009 = data.secrets.logs.calendar_2009 or os.time()
		end)
	end)

	InteractionService.Register("c1_terminal", function()
		if not active or (state.stage ~= "control" and state.stage ~= "arrival" and state.stage ~= "decision") then
			return
		end
		DecisionService.Cancel()
		state.stage = "power"
		ctx.setCheckpoint("C1_CONTROL")
		relay("RADIO_C1_POWER")
		StoryService.SetObjective("OBJECTIVE_POWER", { count = systemsOn(), total = 2 })
	end)

	InteractionService.Register("c1_power", function(player, lever)
		if not active or state.stage == "arrival" or state.stage == "decision" or state.stage == "control" then
			return
		end
		local system = lever:GetAttribute("System")
		if type(system) ~= "string" or not table.find(SYSTEMS, system) then
			return
		end
		if state.systems[system] then
			state.systems[system] = nil
		elseif systemsOn() < 2 then
			state.systems[system] = true
		else
			Net.Event("Notify"):FireClient(player, "SYS_FULL")
			Net.Event("Sfx"):FireAllClients("door_locked", (lever :: BasePart).Position)
			return
		end
		Net.Event("Sfx"):FireAllClients("relay_activate", (lever :: BasePart).Position)
		NoiseService.Emit((lever :: BasePart).Position, Config.Noise.Door, player)
		applySystems()
		if state.stage == "power" then
			StoryService.SetObjective("OBJECTIVE_POWER", { count = systemsOn(), total = 2 })
			if systemsOn() == 2 and not state.powerChosenOnce then
				state.powerChosenOnce = true
				-- The Relay reacts to WHAT you chose (consequence you can hear).
				local leftOut = "cameras"
				for _, name in SYSTEMS do
					if not state.systems[name] then
						leftOut = name
					end
				end
				relay("RADIO_C1_POWER_NO_" .. string.upper(leftOut), nil, 1)
				task.delay(6, function()
					if active and state.stage == "power" then
						startFuses()
					end
				end)
			end
		end
	end)

	InteractionService.Register("c1_fuse", function(player, fuse)
		if not active or state.stage ~= "fuses" or not fuse.Parent then
			return
		end
		sfxAt("fuse_pickup", (fuse :: BasePart).Position)
		fuse:Destroy()
		state.fuses += 1
		rewardAll(Config.Rewards.Fuse)
		NoiseService.Emit((player.Character :: Model):GetPivot().Position, Config.Noise.Interact, player)
		if state.fuses >= Config.Creature.ActivateAfterFuses then
			wakeCreature()
		end
		if state.fuses == 2 then
			forecastLightsA()
		end
		if state.fuses >= TOTAL_FUSES then
			state.stage = "relay"
			StoryService.SetObjective("OBJECTIVE_RELAY_B")
		else
			StoryService.SetObjective("OBJECTIVE_FIND_FUSES", { count = state.fuses, total = TOTAL_FUSES })
		end
	end)

	InteractionService.Register("c1_relay_b", function(_player, panel)
		if not active or state.stage ~= "relay" then
			return
		end
		state.stage = "core"
		PowerService.Set("B", true)
		sfxAt("relay_activate", (panel :: BasePart).Position)
		NoiseService.Emit((panel :: BasePart).Position, 60, nil)
		StoryService.Say("all", { text = "SFX_RELAY", channel = "world", duration = 3 })
		rewardAll(Config.Rewards.Relay)
		ctx.setCheckpoint("C1_CORE")
		StoryService.SetObjective("OBJECTIVE_CORE")
		task.delay(12, function()
			if active and state.stage == "core" and not ForecastService.IsActive() then
				forecastGenerator()
			end
		end)
	end)

	InteractionService.Register("c1_core", function(_player, console)
		if not active or state.stage ~= "core" then
			return
		end
		state.stage = "antenna"
		PowerService.Set("CORE", true)
		sfxAt("relay_activate", (console :: BasePart).Position)
		CreatureService.Alert((console :: BasePart).Position)
		StoryService.Sequence("all", {
			{ delay = 2, text = "SFX_STATIC", channel = "sfx", duration = 2 },
			{
				delay = 1.5,
				speaker = "SPEAKER_RELAY",
				text = if state.answered then "RADIO_C1_CORE_ANSWERED" else "RADIO_C1_CORE",
				params = { name = randomName() },
				channel = "radio",
				duration = 5,
			},
		})
		task.delay(8, function()
			if active then
				StoryService.SetObjective("OBJECTIVE_ANTENNA")
			end
		end)
	end)

	InteractionService.Register("c1_antenna", function()
		if not active or (state.stage ~= "antenna" and state.stage ~= "done") then
			return
		end
		if state.stage == "antenna" then
			state.stage = "done"
			ForecastService.Cancel()
			unknown(if state.answered then "RADIO_C1_ANTENNA_ANSWERED" else "RADIO_C1_ANTENNA", nil, 1)
			CreatureService.SetAIEnabled(false)
			task.delay(14, function()
				if active and state.stage == "done" then
					ctx.finish()
				end
			end)
		end
		for _, p in ctx.playersInGame() do
			if not state.completedBy[p] then
				state.completedBy[p] = true
				DataService.Grant(p, Config.Rewards.ChapterComplete)
				DataService.Mutate(p, function(data)
					if data.progress.completedChapters.ch1 == nil then
						data.progress.completedChapters.ch1 = os.time()
					end
				end)
				DataService.SaveNow(p)
				Net.Event("Notify"):FireClient(p, "CHAPTER_COMPLETE")
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		state.completedBy[player] = nil
	end)
end

function Chapter1.OnPlayerEntered(player: Player, firstTime: boolean)
	if not firstTime or not active then
		return
	end
	if state.stage == "arrival" then
		StoryService.Sequence(player, ARRIVAL)
		if StoryService.GetObjective() == nil then
			task.delay(14, function()
				if active and StoryService.GetObjective() == nil then
					StoryService.SetObjective("OBJECTIVE_CHECK_GATEHOUSE")
				end
			end)
		end
	end
end

return Chapter1
