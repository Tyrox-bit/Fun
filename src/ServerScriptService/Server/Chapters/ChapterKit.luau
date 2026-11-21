-- ChapterKit: shared helpers for story chapters 2-4 (chapter 1 predates it and keeps its
-- own copies). Everything here only uses the generic services - no chapter logic.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local SessionState = require(Shared.SessionState)

local Services = script.Parent.Parent.Services
local StoryService = require(Services.StoryService)
local DataService = require(Services.DataService)
local CreatureService = require(Services.CreatureService)
local DoorService = require(Services.DoorService)
local HealthService = require(Services.HealthService)
local AnalyticsTracker = require(Services.AnalyticsTracker)
local BadgeTracker = require(Services.BadgeTracker)
local AchievementService = require(Services.AchievementService)

local ChapterKit = {}

function ChapterKit.new(chapterName: string, chapterId: string)
	local k: any = { ctx = nil, active = false, token = 0 }
	local stepped: { [string]: boolean } = {}
	local completedBy: { [Player]: boolean } = {}

	function k.players(): { Player }
		return if k.ctx then k.ctx.playersInGame() else {}
	end

	function k.alive(): { Player }
		local list = {}
		for _, player in k.players() do
			if not player:GetAttribute("FZ_Downed") and not player:GetAttribute("FZ_Eliminated") then
				table.insert(list, player)
			end
		end
		return list
	end

	function k.reset()
		k.token += 1
		table.clear(stepped)
		table.clear(completedBy)
	end

	-- Runs fn after `seconds` only if the chapter run that scheduled it is still active.
	function k.after(seconds: number, fn: () -> ())
		local current = k.token
		task.delay(seconds, function()
			if k.active and k.token == current then
				fn()
			end
		end)
	end

	function k.step(name: string)
		if stepped[name] then
			return
		end
		stepped[name] = true
		for _, player in k.players() do
			AnalyticsTracker.ChapterStep(player, chapterName, name)
		end
	end

	function k.rewardAll(amount: number)
		for _, player in k.players() do
			DataService.Grant(player, amount)
		end
	end

	function k.sfx(name: string, position: Vector3, volume: number?)
		Net.Event("Sfx"):FireAllClients(name, position, volume)
	end

	function k.line(speaker: string?, text: string, params: { [string]: any }?, delay: number?, duration: number?, critical: boolean?)
		StoryService.Sequence("all", {
			{ delay = delay or 0.5, speaker = speaker, text = text, params = params, channel = if speaker then "radio" else "world", duration = duration or 5, critical = critical },
		})
	end
	function k.relay(text: string, params: { [string]: any }?, delay: number?, duration: number?)
		k.line("SPEAKER_RELAY", text, params, delay, duration or 4.5)
	end
	function k.unknown(text: string, params: { [string]: any }?, delay: number?, duration: number?)
		k.line("SPEAKER_UNKNOWN", text, params, delay, duration or 5)
	end
	function k.world(text: string, delay: number?, duration: number?)
		k.line(nil, text, nil, delay, duration or 3, true)
	end
	function k.sequence(lines: { any })
		StoryService.Sequence("all", lines)
	end

	function k.objective(key: string?, params: { [string]: any }?)
		StoryService.SetObjective(key, params)
	end

	function k.randomName(): string
		local team = k.players()
		local named = team[math.random(1, math.max(1, #team))]
		return if named then named.DisplayName else ""
	end

	-- First tagged BasePart that passes the filter (e.g. a door with an attribute).
	function k.find(tagName: string, filter: (instance: Instance) -> boolean): BasePart?
		for _, instance in CollectionService:GetTagged(tagName) do
			if instance:IsA("BasePart") and filter(instance) then
				return instance
			end
		end
		return nil
	end
	function k.findAll(tagName: string, filter: (instance: Instance) -> boolean): { BasePart }
		local list = {}
		for _, instance in CollectionService:GetTagged(tagName) do
			if instance:IsA("BasePart") and filter(instance) then
				table.insert(list, instance)
			end
		end
		return list
	end
	function k.door(attribute: string): BasePart?
		return k.find("FZ_Door", function(panel)
			return panel:GetAttribute(attribute) ~= nil
		end)
	end
	function k.interactable(id: string): BasePart?
		return k.find("FZ_Interactable", function(instance)
			return instance:GetAttribute("InteractId") == id
		end)
	end
	function k.unlock(panel: BasePart?, open: boolean?)
		if panel then
			DoorService.SetLocked(panel, false)
			if open then
				DoorService.Open(panel)
			end
		end
	end
	function k.lock(panel: BasePart?)
		if panel then
			DoorService.Close(panel)
			DoorService.SetLocked(panel, true)
		end
	end

	-- Shows / hides parts tagged FZ_FloodWater (visual only, never blocks movement).
	function k.setFlood(on: boolean)
		for _, water in CollectionService:GetTagged("FZ_FloodWater") do
			if water:IsA("BasePart") then
				water.Transparency = if on then 0.35 else 1
			end
		end
	end

	function k.rootOf(player: Player): BasePart?
		local character = player.Character
		return character and character:FindFirstChild("HumanoidRootPart") :: BasePart? or nil
	end

	-- How many standing players are within `radius` of `position` (and how many stand).
	function k.near(position: Vector3, radius: number): (number, number)
		local here, total = 0, 0
		for _, player in k.alive() do
			total += 1
			local root = k.rootOf(player)
			if root and (root.Position - position).Magnitude <= radius then
				here += 1
			end
		end
		return here, total
	end

	-- The creature gets a hint where a random standing player is (active hunting).
	function k.huntPulse()
		local targets = k.alive()
		local target = targets[math.random(1, math.max(1, #targets))]
		local root = target and k.rootOf(target)
		if root then
			CreatureService.Alert(root.Position)
		end
	end

	-- A team choice from an earlier chapter: the option most players in the session saved.
	function k.choice(decisionId: string): number?
		local votes: { [number]: number } = {}
		for _, player in k.players() do
			local profile = DataService.Get(player)
			local value = profile and profile.Data.storyChoices[decisionId]
			if type(value) == "number" then
				votes[value] = (votes[value] or 0) + 1
			end
		end
		local best, bestCount = nil, 0
		for option, count in votes do
			if count > bestCount or (count == bestCount and best and option < best) then
				best, bestCount = option, count
			end
		end
		return best
	end

	-- Chapter completion for everyone in the session (once per player per run).
	function k.complete(badgeKey: string?, extra: ((player: Player) -> ())?)
		for _, player in k.players() do
			if not completedBy[player] then
				completedBy[player] = true
				DataService.Grant(player, Config.Rewards.ChapterComplete)
				DataService.Mutate(player, function(data)
					if data.progress.completedChapters[chapterId] == nil then
						data.progress.completedChapters[chapterId] = os.time()
					end
				end)
				Net.Event("Notify"):FireClient(player, "CHAPTER_COMPLETE")
				if badgeKey then
					BadgeTracker.Award(player, badgeKey)
				end
				if not CreatureService.Spotted[player] then
					AchievementService.Award(player, "unseen")
				end
				if #k.players() >= 2 and next(HealthService.SessionStats.eliminated) == nil then
					AchievementService.Award(player, "nobody_left")
				end
				if extra then
					extra(player)
				end
				DataService.SaveNow(player)
			end
		end
	end

	-- 2 Hz trigger zones: { id, center, radius, when = () -> boolean, fn = (player) -> () }.
	-- A zone fires once per run (the first standing player that enters it).
	function k.zones(list: { any })
		local current = k.token
		local fired: { [string]: boolean } = {}
		task.spawn(function()
			while k.active and k.token == current do
				task.wait(0.5)
				for _, zone in list do
					if not fired[zone.id] and (not zone.when or zone.when()) then
						for _, player in k.alive() do
							local root = k.rootOf(player)
							if root and (root.Position - zone.center).Magnitude <= zone.radius then
								fired[zone.id] = true
								task.spawn(zone.fn, player)
								break
							end
						end
					end
				end
			end
		end)
	end

	-- Calls fn every `seconds` while the run is active and `when()` holds.
	function k.every(seconds: number, when: () -> boolean, fn: () -> ())
		local current = k.token
		task.spawn(function()
			while k.active and k.token == current do
				task.wait(seconds)
				if k.active and k.token == current and when() then
					fn()
				end
			end
		end)
	end

	function k.setState(key: string, value: any)
		SessionState.Set(key, value)
	end

	Players.PlayerRemoving:Connect(function(player)
		completedBy[player] = nil
	end)

	return k
end

return ChapterKit
