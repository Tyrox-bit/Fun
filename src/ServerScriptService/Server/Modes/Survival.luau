-- Endless survival "Night shift" (works on any map that provides the tagged objects).
--
--   Shift n:  random task (never the same twice in a row) + from shift 2 a random event
--             creatures get slowly faster and hear better; a second one joins at shift 6
--   Task done -> marks are BANKED, downed teammates get up, 25 s calm break:
--             extraction at the antenna is open (whole team must be there) or keep going
--   Team down -> run over, 50 % of the banked marks; extraction -> 100 % + 20 % bonus
-- No daily tasks, no timers that run while you are offline, no day/night simulation.

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
local HealthService = require(Services.HealthService)
local DoorService = require(Services.DoorService)
local LeaderboardService = require(Services.LeaderboardService)
local ForecastService = require(Services.ForecastService)
local DirectorService = require(Services.DirectorService)
local InventoryService = require(Services.InventoryService)

local Survival = {}
Survival.StartCheckpoint = "C1_CONTROL"

local SC = Config.Survival
local TASKS = { "fuses", "uplink", "generators", "stations" }
local EVENTS = { "blackout", "static", "hunt", "lockdown", "calm", "forecast" }
local EVENT_NAMES = { blackout = "SV_EVN_BLACKOUT", static = "SV_EVN_STATIC", hunt = "SV_EVN_HUNT", lockdown = "SV_EVN_LOCKDOWN", calm = "SV_EVN_CALM", forecast = "SV_EVN_FORECAST" }

-- Light, repeatable scares for survival (the director keeps the gaps).
local SURVIVAL_BEATS = {
	{ id = "sv_flicker", kind = "flicker", condition = function(_p, info) return info.area ~= nil end },
	{ id = "sv_footsteps", kind = "footsteps", condition = function(_p, info) return info.alone end },
	{ id = "sv_apparition", kind = "apparition", condition = function(_p, info) return info.area == "HALL" end },
}
local STATIONS = { "c1_terminal", "c1_breaker_a", "c1_core" }
local UPLINK_SECONDS = 40
local UPLINK_RADIUS = 17

local ctx = nil
local active = false
local token = 0 -- invalidates timers of an older run

type Run = {
	entry: any,
	shift: number,
	completed: number,
	phase: string, -- "intro" | "task" | "break" | "ended"
	task: string?,
	lastTask: string?,
	event: string?,
	lastEvent: string?,
	taskStarted: number,
	banked: number,
	participants: { [Player]: boolean },
	progress: { [string]: any },
	blackoutSector: string?,
	lockedDoors: { BasePart },
	fuses: Folder?,
	overloadAnnounced: boolean,
}
local run: Run? = nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function say(key: string, params: { [string]: any }?)
	StoryService.Say("all", { speaker = "SPEAKER_RELAY", text = key, params = params, channel = "radio", duration = 4 })
end

local function pick(list: { string }, avoid: string?): string
	local options = {}
	for _, value in list do
		if value ~= avoid then
			table.insert(options, value)
		end
	end
	return options[math.random(1, #options)]
end

local function interactablePosition(id: string): Vector3?
	for _, instance in CollectionService:GetTagged("FZ_Interactable") do
		if instance:GetAttribute("InteractId") == id and instance:IsA("BasePart") then
			return instance.Position
		end
	end
	return nil
end

local function aliveInGame(): { Player }
	local list = {}
	for _, player in ctx.playersInGame() do
		if not player:GetAttribute("FZ_Downed") then
			table.insert(list, player)
		end
	end
	return list
end

local function publish()
	local r = run
	SessionState.Set("SvShift", if r then r.shift else nil)
	SessionState.Set("SvEvent", if r and r.event and r.phase == "task" then EVENT_NAMES[r.event] else nil)
	SessionState.Set("SvPhase", if r then r.phase else nil)
end

local function objective(key: string, params: { [string]: any }?)
	StoryService.SetObjective(key, params)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function clearEvent(r: Run)
	ForecastService.Cancel()
	if r.blackoutSector then
		PowerService.Set(r.blackoutSector, true)
		r.blackoutSector = nil
	end
	for _, panel in r.lockedDoors do
		DoorService.SetLocked(panel, false)
	end
	table.clear(r.lockedDoors)
	SessionState.Set("SvStatic", nil)
	r.event = nil
end

local function startEvent(r: Run)
	if r.shift < SC.FirstEventShift then
		return
	end
	local event = pick(EVENTS, r.lastEvent)
	r.event = event
	r.lastEvent = event
	if event == "blackout" then
		local sector = pick({ "A", "C", "D", "E" }, nil)
		r.blackoutSector = sector
		PowerService.Set(sector, false)
		StoryService.Say("all", { text = "SFX_POWER_DOWN", channel = "world", duration = 3, critical = true })
	elseif event == "static" then
		SessionState.Set("SvStatic", true)
	elseif event == "forecast" then
		-- A prediction you can break: hold the right breaker before the deadline.
		local sector = pick({ "A", "C", "D", "E" }, nil)
		ForecastService.Start({
			id = "sv_blackout_" .. string.lower(sector),
			text = "SV_FORECAST_" .. sector,
			hud = "FORECAST_BLACKOUT_" .. sector,
			seconds = 35,
			breakWith = if sector == "A" then "c1_breaker_a" else "breaker",
			breakFilter = function(instance)
				return instance:GetAttribute("Sector") == sector
			end,
			onKept = function()
				if run == r and r.phase == "task" then
					r.blackoutSector = sector
					PowerService.Set(sector, false)
					StoryService.Say("all", { text = "SFX_POWER_DOWN", channel = "world", duration = 3, critical = true })
				end
			end,
			onBroken = function()
				r.banked += SC.ShiftReward -- breaking a forecast is worth an extra shift reward
			end,
			keptLine = "RADIO_C1_FORECAST_KEPT",
			brokenLine = "RADIO_C1_FORECAST_BROKEN",
		})
		return -- the forecast line replaces the event announcement
	elseif event == "lockdown" then
		local candidates = {}
		for _, panel in CollectionService:GetTagged("FZ_Door") do
			if panel:IsA("BasePart") and (panel:GetAttribute("PowerSector") or "") == "" then
				table.insert(candidates, panel)
			end
		end
		for _ = 1, math.min(2, #candidates) do
			local panel = table.remove(candidates, math.random(1, #candidates))
			DoorService.SetLocked(panel, true)
			table.insert(r.lockedDoors, panel)
		end
		local current = token
		task.delay(60, function()
			if token == current and run == r then
				for _, panel in r.lockedDoors do
					DoorService.SetLocked(panel, false)
				end
				table.clear(r.lockedDoors)
			end
		end)
	end
	say("SV_EV_" .. string.upper(event))
end

---------------------------------------------------------------------------
-- Tasks
---------------------------------------------------------------------------
local completeTask: (r: Run) -> ()

local function spawnFuses(r: Run)
	if r.fuses then
		r.fuses:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "FZ_SurvivalFuses"
	folder.Parent = workspace
	r.fuses = folder
	local spots = {}
	for _, spot in CollectionService:GetTagged("FZ_FuseSpot") do
		if spot:IsA("BasePart") then
			table.insert(spots, spot)
		end
	end
	for _ = 1, math.min(3, #spots) do
		local spot = table.remove(spots, math.random(1, #spots))
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
		fuse:SetAttribute("InteractId", "sv_fuse")
		fuse:SetAttribute("ActionKey", "INTERACT_PICKUP")
		fuse:SetAttribute("ObjectKey", "OBJECT_FUSE")
		fuse:SetAttribute("MaxDistance", 7)
		fuse.Parent = folder
		CollectionService:AddTag(fuse, "FZ_Interactable")
	end
end

local function beginTask(r: Run)
	local taskName = pick(TASKS, r.lastTask)
	r.task = taskName
	r.lastTask = taskName
	r.taskStarted = os.clock()
	r.overloadAnnounced = false
	r.progress = {}
	if taskName == "fuses" then
		r.progress.found = 0
		spawnFuses(r)
		objective("OBJECTIVE_FIND_FUSES", { count = 0, total = 3 })
	elseif taskName == "uplink" then
		r.progress.seconds = 0
		objective("SV_TASK_UPLINK", { percent = 0 })
	elseif taskName == "generators" then
		r.progress.done = {}
		objective("SV_TASK_GENERATORS", { count = 0, total = 2 })
	elseif taskName == "stations" then
		r.progress.done = {}
		objective("SV_TASK_STATIONS", { count = 0, total = #STATIONS })
	end
end

local function startShift(r: Run, shift: number)
	if not active or run ~= r then
		return
	end
	r.shift = shift
	r.phase = "task"
	local step = shift - 1
	CreatureService.SetDifficulty({
		speed = math.min(SC.MaxSpeedScale, 1 + 0.03 * step),
		hearing = math.min(SC.MaxHearingScale, 1 + 0.06 * step),
		ventChance = math.min(0.7, Config.Creature.VentChance + 0.04 * step),
	})
	CreatureService.SetAIEnabled(true)
	if CreatureService.Count() == 0 then
		CreatureService.Spawn()
	end
	if shift >= SC.SecondCreatureShift and CreatureService.Count() < 2 then
		CreatureService.Spawn(nil, true)
		say("SV_SECOND_CREATURE")
	end
	startEvent(r)
	if r.event == "static" then
		CreatureService.SetDifficulty({
			speed = math.min(SC.MaxSpeedScale, 1 + 0.03 * step),
			hearing = math.min(SC.MaxHearingScale, 1 + 0.06 * step) * 1.4,
			ventChance = math.min(0.7, Config.Creature.VentChance + 0.04 * step),
		})
	end
	beginTask(r)
	publish()
end

completeTask = function(r: Run)
	if r.phase ~= "task" then
		return
	end
	r.completed += 1
	r.banked += SC.ShiftReward + SC.ShiftRewardGrowth * r.shift
	r.phase = "break"
	r.task = nil
	clearEvent(r)
	if r.fuses then
		r.fuses:Destroy()
		r.fuses = nil
	end
	CreatureService.SetAIEnabled(false)
	for _, player in ctx.playersInGame() do
		if player:GetAttribute("FZ_Downed") then
			HealthService.Revive(player, 50)
		end
	end
	say("SV_SHIFT_DONE", { shift = r.shift })
	InventoryService.SpawnWorldItems(Config.Inventory.SurvivalItemsPerBreak)
	objective("SV_BREAK", { seconds = SC.BreakSeconds })
	SessionState.Set("SvBreakEnds", workspace:GetServerTimeNow() + SC.BreakSeconds)
	publish()
	local current = token
	task.delay(SC.BreakSeconds, function()
		if token == current and run == r and r.phase == "break" then
			startShift(r, r.shift + 1)
		end
	end)
end

---------------------------------------------------------------------------
-- Run end
---------------------------------------------------------------------------
local function endRun(r: Run, extracted: boolean)
	if r.phase == "ended" then
		return
	end
	r.phase = "ended"
	publish()
	clearEvent(r)
	CreatureService.SetAIEnabled(false)
	local factor = if extracted then 1 + SC.ExtractBonus else SC.WipeKeep
	local marks = math.floor(r.banked * factor)
	local survivalId = r.entry.id
	for player in r.participants do
		if player.Parent then
			local newBest = false
			DataService.Mutate(player, function(data)
				local stats = data.modes.survival[survivalId] or { best = 0, runs = 0 }
				stats.runs += 1
				if r.completed > stats.best then
					stats.best = r.completed
					newBest = true
				end
				data.modes.survival[survivalId] = stats
			end)
			if marks > 0 then
				DataService.Grant(player, marks)
			end
			DataService.SaveNow(player)
			task.spawn(LeaderboardService.Submit, survivalId, player.UserId, r.completed)
			StoryService.ShowDocument(player, {
				title = "SV_RESULT_TITLE",
				body = if extracted then "SV_RESULT_EXTRACTED" else "SV_RESULT_LOST",
				params = { shifts = r.completed, marks = marks },
			})
			if newBest then
				Net.Event("Notify"):FireClient(player, "SV_NEW_BEST")
			end
		end
	end
	HealthService.HealAll()
	local current = token
	task.delay(15, function() -- time to read the shift report
		if token == current and run == r then
			ctx.finish()
		end
	end)
end

---------------------------------------------------------------------------
-- Mode interface
---------------------------------------------------------------------------
function Survival.Begin(entry)
	token += 1
	active = true
	run = {
		entry = entry,
		shift = 0,
		completed = 0,
		phase = "intro",
		task = nil,
		lastTask = nil,
		event = nil,
		lastEvent = nil,
		taskStarted = 0,
		banked = 0,
		participants = {},
		progress = {},
		blackoutSector = nil,
		lockedDoors = {},
		fuses = nil,
		overloadAnnounced = false,
	}
	local r = run :: Run
	PowerService.Set("B", true) -- the core is reachable in survival
	PowerService.Set("HALLS", true)
	SessionState.Set("Cameras", true)
	DirectorService.Configure(SURVIVAL_BEATS, {}, ctx.playersInGame)
	HealthService.TeamWipeHandler = function()
		if run == r and active then
			endRun(r, false)
		end
	end
	StoryService.ResetFlags()
	objective("SV_INTRO")
	publish()
	local current = token
	task.delay(10, function()
		if token == current then
			say("SV_START")
			startShift(r, 1)
		end
	end)

	-- 1 Hz director: uplink progress, overload, hunt event
	task.spawn(function()
		local nextHunt = 0
		while token == current and active do
			task.wait(1)
			local rr = run
			if not rr or rr ~= r or rr.phase ~= "task" then
				continue
			end
			local now = os.clock()
			if rr.task == "uplink" then
				local center = interactablePosition("c1_core")
				if center then
					local inside = false
					for _, player in aliveInGame() do
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and (root.Position - center).Magnitude <= UPLINK_RADIUS then
							inside = true
						end
					end
					if inside then
						rr.progress.seconds += 1
						if rr.progress.seconds % 6 == 0 then
							NoiseService.Emit(center, 80, nil) -- the uplink is loud
						end
						objective("SV_TASK_UPLINK", { percent = math.floor(rr.progress.seconds / UPLINK_SECONDS * 100) })
						if rr.progress.seconds >= UPLINK_SECONDS then
							completeTask(rr)
							continue
						end
					end
				end
			end
			if now - rr.taskStarted > SC.TaskSoftLimit then
				if not rr.overloadAnnounced then
					rr.overloadAnnounced = true
					say("SV_OVERLOAD")
				end
				if now >= nextHunt then
					nextHunt = now + 20
					local targets = aliveInGame()
					local target = targets[math.random(1, math.max(1, #targets))]
					local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						CreatureService.Alert(root.Position)
					end
				end
			elseif rr.event == "hunt" and now >= nextHunt then
				nextHunt = now + 15
				local targets = aliveInGame()
				local target = targets[math.random(1, math.max(1, #targets))]
				local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					CreatureService.Alert(root.Position)
				end
			end
		end
	end)
end

function Survival.Stop()
	token += 1
	active = false
	local r = run
	if r then
		clearEvent(r)
		if r.fuses then
			r.fuses:Destroy()
		end
	end
	run = nil
	HealthService.TeamWipeHandler = nil
	DirectorService.Stop()
	ForecastService.Cancel()
	SessionState.Set("Cameras", nil)
	SessionState.Set("CctvArea", nil)
	SessionState.Set("SvShift", nil)
	SessionState.Set("SvEvent", nil)
	SessionState.Set("SvPhase", nil)
	SessionState.Set("SvStatic", nil)
	SessionState.Set("SvBreakEnds", nil)
end

function Survival.OnPlayerEntered(player: Player, _firstTime: boolean)
	local r = run
	if r and active then
		r.participants[player] = true
	end
end

function Survival.Init(context)
	ctx = context
	ForecastService.Breakable("c1_breaker_a")
	ForecastService.Breakable("breaker")

	InteractionService.Register("sv_fuse", function(_player, fuse)
		local r = run
		if not active or not r or r.task ~= "fuses" or not fuse.Parent then
			return
		end
		Net.Event("Sfx"):FireAllClients("fuse_pickup", (fuse :: BasePart).Position)
		fuse:Destroy()
		r.progress.found += 1
		if r.progress.found >= 3 then
			objective("OBJECTIVE_RELAY_B")
		else
			objective("OBJECTIVE_FIND_FUSES", { count = r.progress.found, total = 3 })
		end
	end)

	InteractionService.Register("c1_relay_b", function(_player, panel)
		local r = run
		if not active or not r or r.task ~= "fuses" or (r.progress.found or 0) < 3 then
			return
		end
		Net.Event("Sfx"):FireAllClients("relay_activate", (panel :: BasePart).Position)
		completeTask(r)
	end)

	InteractionService.Register("generator", function(_player, generator)
		local r = run
		if not active or not r or r.task ~= "generators" then
			return
		end
		local id = generator:GetAttribute("GeneratorId") or generator
		if r.progress.done[id] then
			return
		end
		r.progress.done[id] = true
		Net.Event("Sfx"):FireAllClients("relay_activate", (generator :: BasePart).Position)
		NoiseService.Emit((generator :: BasePart).Position, 40, nil)
		local count = 0
		for _ in r.progress.done do
			count += 1
		end
		objective("SV_TASK_GENERATORS", { count = count, total = 2 })
		if count >= 2 then
			completeTask(r)
		end
	end)

	for _, stationId in STATIONS do
		InteractionService.Register(stationId, function(_player, station)
			local r = run
			if not active or not r or r.task ~= "stations" or r.progress.done[stationId] then
				return
			end
			r.progress.done[stationId] = true
			Net.Event("Sfx"):FireAllClients("radio_channel_beep", (station :: BasePart).Position)
			local count = 0
			for _ in r.progress.done do
				count += 1
			end
			objective("SV_TASK_STATIONS", { count = count, total = #STATIONS })
			if count >= #STATIONS then
				completeTask(r)
			end
		end)
	end

	-- Voluntary extraction during a break: the whole (standing) team must be there.
	InteractionService.Register("c1_antenna", function(player, cabinet)
		local r = run
		if not active or not r or r.phase ~= "break" then
			return
		end
		local center = (cabinet :: BasePart).Position
		for _, other in aliveInGame() do
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or (root.Position - center).Magnitude > SC.ExtractRadius then
				Net.Event("Notify"):FireClient(player, "SV_EXTRACT_NEED_TEAM")
				return
			end
		end
		endRun(r, true)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if run then
			run.participants[player] = nil
		end
	end)
end

return Survival
