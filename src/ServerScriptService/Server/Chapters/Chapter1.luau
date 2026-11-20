-- Chapter 1 "The Reception" - playable flow on Relay Station 07.
--
--  Gate: arrival transmission -> gatehouse fax (dated tomorrow, 02:14)
--  Control room terminal -> 3 fuses appear in 3 of 4 sectors (random each session)
--  1st fuse: the creature wakes up            2nd fuse: FORECAST "lights in A go out"
--     -> hold the breaker in Sector A in time = forecast broken (reward, new line)
--     -> otherwise Sector A goes dark and the creature comes to look
--  3 fuses -> Relay Sector B -> core doors unlock -> central core
--  Core activation -> the Relay says a player's name -> antenna outside = end of slice

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Services = script.Parent.Parent.Services
local StoryService = require(Services.StoryService)
local InteractionService = require(Services.InteractionService)
local PowerService = require(Services.PowerService)
local CreatureService = require(Services.CreatureService)
local DataService = require(Services.DataService)
local NoiseService = require(Services.NoiseService)

local Chapter1 = {}
Chapter1.StartCheckpoint = "C1_START"

local active = false

local TOTAL_FUSES = 3
local FORECAST_SECONDS = 30

local state = {
	stage = "arrival", -- arrival | control | fuses | relay | core | antenna | done
	fuses = 0,
	forecast = "none", -- none | armed | broken | kept
	completedBy = {} :: { [Player]: boolean },
}
local fuseFolder: Folder? = nil
local ctx = nil -- { setCheckpoint, finish, playersInGame }

local ARRIVAL = {
	{ delay = 1.5, text = "SFX_STATIC", channel = "sfx", duration = 2 },
	{ delay = 1.0, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C1_001", channel = "radio", duration = 5.5 },
	{ delay = 5.8, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C1_002", channel = "radio", duration = 4 },
	{ delay = 5.0, text = "SFX_FAX", channel = "world", duration = 3 },
}

local function rewardAll(amount: number)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("FZ_InGame") then
			DataService.Grant(player, amount)
		end
	end
end

local function sfxAt(name: string, position: Vector3)
	Net.Event("Sfx"):FireAllClients(name, position)
end

local function centerOf(tagName: string, attribute: string, value: string): Vector3?
	for _, instance in CollectionService:GetTagged(tagName) do
		if instance:IsA("BasePart") and instance:GetAttribute(attribute) == value then
			return instance.Position
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Fuses
---------------------------------------------------------------------------
local function spawnFuses()
	if fuseFolder then
		fuseFolder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "FZ_Fuses"
	folder.Parent = workspace
	fuseFolder = folder

	-- Pick one random spot in 3 of the available sectors.
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

local function updateFuseObjective()
	StoryService.SetObjective("OBJECTIVE_FIND_FUSES", { count = state.fuses, total = TOTAL_FUSES })
end

---------------------------------------------------------------------------
-- Forecast (prediction you can break)
---------------------------------------------------------------------------
local function startForecast()
	state.forecast = "armed"
	StoryService.Sequence("all", {
		{ delay = 1, speaker = "SPEAKER_RELAY", text = "RADIO_C1_FORECAST", channel = "radio", duration = 5 },
	})
	task.delay(FORECAST_SECONDS + 1, function()
		if state.forecast ~= "armed" then
			return
		end
		state.forecast = "kept"
		PowerService.Set("A", false)
		local center = centerOf("FZ_CreaturePatrol", "Area", "A")
		if center then
			sfxAt("power_down", center)
			NoiseService.Emit(center, 400, nil)
			CreatureService.Alert(center)
		end
		StoryService.Say("all", { text = "SFX_POWER_DOWN", channel = "world", duration = 3, critical = true })
		StoryService.Sequence("all", {
			{ delay = 2.5, speaker = "SPEAKER_RELAY", text = "RADIO_C1_FORECAST_KEPT", channel = "radio", duration = 3 },
		})
	end)
end

---------------------------------------------------------------------------
-- Flow
---------------------------------------------------------------------------
local function reset()
	state.stage = "arrival"
	state.fuses = 0
	state.forecast = "none"
	table.clear(state.completedBy)
	if fuseFolder then
		fuseFolder:Destroy()
		fuseFolder = nil
	end
	StoryService.ResetFlags()
	StoryService.SetObjective(nil)
end

function Chapter1.Begin()
	reset()
	active = true
end

function Chapter1.Stop()
	active = false
	reset()
end

-- Registers interaction handlers once. Every handler ignores input unless chapter 1 is
-- the running session (the same objects are used by the survival mode).
function Chapter1.Init(context)
	ctx = context

	InteractionService.Register("c1_fax", function(player)
		if not active then
			return
		end
		StoryService.ShowDocument(player, { title = "FAX_TITLE", body = "FAX_BODY", date = os.time() + 24 * 60 * 60 })
		if StoryService.GetFlag("C1_FaxRead") then
			return
		end
		StoryService.SetFlag("C1_FaxRead", true)
		StoryService.Sequence("all", {
			{ delay = 3, speaker = "SPEAKER_RELAY", text = "RADIO_C1_003", channel = "radio", duration = 3.5 },
		})
		task.delay(6, function()
			if state.stage == "arrival" then
				state.stage = "control"
				StoryService.SetObjective("OBJECTIVE_REACH_CONTROL")
			end
		end)
	end)

	InteractionService.Register("c1_terminal", function()
		if not active then
			return
		end
		if state.stage ~= "control" and state.stage ~= "arrival" then
			return
		end
		state.stage = "fuses"
		ctx.setCheckpoint("C1_CONTROL")
		StoryService.Say("all", { speaker = "SPEAKER_RELAY", text = "RADIO_C1_TERMINAL", channel = "radio", duration = 5 })
		spawnFuses()
		updateFuseObjective()
	end)

	InteractionService.Register("c1_fuse", function(player, fuse)
		if not active then
			return
		end
		if state.stage ~= "fuses" or not fuse.Parent then
			return
		end
		sfxAt("fuse_pickup", (fuse :: BasePart).Position)
		fuse:Destroy()
		state.fuses += 1
		rewardAll(Config.Rewards.Fuse)
		NoiseService.Emit((player.Character :: Model):GetPivot().Position, Config.Noise.Interact, player)
		if state.fuses >= Config.Creature.ActivateAfterFuses and not CreatureService.Get() then
			CreatureService.Spawn()
			StoryService.Sequence("all", {
				{ delay = 1.5, speaker = "SPEAKER_RELAY", text = "RADIO_C1_WAKE", channel = "radio", duration = 4 },
			})
		end
		if state.fuses == 2 and state.forecast == "none" then
			startForecast()
		end
		if state.fuses >= TOTAL_FUSES then
			state.stage = "relay"
			StoryService.SetObjective("OBJECTIVE_RELAY_B")
		else
			updateFuseObjective()
		end
	end)

	InteractionService.Register("c1_breaker_a", function()
		if not active then
			return
		end
		if state.forecast ~= "armed" then
			return
		end
		state.forecast = "broken"
		rewardAll(Config.Rewards.ForecastBroken)
		StoryService.SetFlag("C1_ForecastBroken", true)
		StoryService.Say("all", { speaker = "SPEAKER_RELAY", text = "RADIO_C1_FORECAST_BROKEN", channel = "radio", duration = 4 })
	end)

	InteractionService.Register("c1_relay_b", function(_player, panel)
		if not active then
			return
		end
		if state.stage ~= "relay" then
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
	end)

	InteractionService.Register("c1_core", function(_player, console)
		if not active then
			return
		end
		if state.stage ~= "core" then
			return
		end
		state.stage = "antenna"
		PowerService.Set("CORE", true)
		sfxAt("relay_activate", (console :: BasePart).Position)
		CreatureService.Alert((console :: BasePart).Position)
		local team = {}
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("FZ_InGame") then
				table.insert(team, p)
			end
		end
		local named = team[math.random(1, math.max(1, #team))]
		StoryService.Sequence("all", {
			{ delay = 2, text = "SFX_STATIC", channel = "sfx", duration = 2 },
			{ delay = 1.5, speaker = "SPEAKER_RELAY", text = "RADIO_C1_CORE", params = { name = if named then named.DisplayName else "" }, channel = "radio", duration = 4.5 },
		})
		task.delay(7, function()
			StoryService.SetObjective("OBJECTIVE_ANTENNA")
		end)
	end)

	InteractionService.Register("c1_antenna", function()
		if not active then
			return
		end
		if state.stage ~= "antenna" and state.stage ~= "done" then
			return
		end
		if state.stage == "antenna" then
			state.stage = "done"
			StoryService.Sequence("all", {
				{ delay = 1, speaker = "SPEAKER_UNKNOWN", text = "RADIO_C1_ANTENNA", channel = "radio", duration = 6 },
			})
			CreatureService.SetAIEnabled(false)
			-- Everyone returns to the menu after the ending line; the chapter stays replayable.
			task.delay(14, function()
				if active and state.stage == "done" then
					ctx.finish()
				end
			end)
		end
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("FZ_InGame") and not state.completedBy[p] then
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
				if StoryService.GetObjective() == nil then
					StoryService.SetObjective("OBJECTIVE_CHECK_GATEHOUSE")
				end
			end)
		end
	end
end

return Chapter1
