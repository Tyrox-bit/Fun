-- CreatureService: server-authoritative AI for "Der Lauscher".
--
-- Fair, learnable rules (see docs/GAME_DESIGN.md):
--   * It HEARS: walking (7 studs), sprinting (20), radio transmissions (28), doors (16).
--     Standing still is silent.
--   * It SEES within 42 studs in a 65 degree cone, only with line of sight.
--   * Light blinds it briefly (flashlight aimed at the head), then it backs off.
--   * Every attack has a wind-up (crackle + pose). Three hits put you down, never one.
--   * Vent travel is always announced by a rattle at the exit vent.
-- States: Dormant, Patrol, Listen, Investigate, Search, Chase, Attack, Blinded, Retreat, Vent
-- The current state is replicated as the model attribute "State" for visuals and audio.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local DoorService = require(script.Parent.DoorService)
local HealthService = require(script.Parent.HealthService)
local NoiseService = require(script.Parent.NoiseService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Rig = require(script.Parent.Parent.Creature.Rig)

local CreatureService = {}

local CC = Config.Creature
local TICK = 0.1

type Creature = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	state: string,
	stateTime: number,
	target: Vector3?,
	targetPlayer: Player?,
	lastSeen: number,
	lastSeenPosition: Vector3?,
	waypoints: { PathWaypoint },
	waypointIndex: number,
	pathTarget: Vector3?,
	nextRepath: number,
	nextAttack: number,
	blindReadyAt: number,
	visitedPatrol: { [Instance]: number },
	searchCenter: Vector3?,
	pendingNoise: { position: Vector3, radius: number }?,
	tracks: { [string]: AnimationTrack },
	lastFootprint: number,
}

local creatures: { Creature } = {}
local aiEnabled = true
local difficulty = { speed = 1, hearing = 1, ventChance = CC.VentChance }

local function alive(c: Creature): boolean
	return table.find(creatures, c) ~= nil and c.model.Parent ~= nil
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function soloScale(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("FZ_InGame") then
			count += 1
		end
	end
	return if count <= 1 then CC.SoloSpeedScale else 1
end

local function setState(c: Creature, state: string)
	if c.state == state then
		return
	end
	c.state = state
	c.stateTime = os.clock()
	c.model:SetAttribute("State", state)
	c.waypoints = {}
	c.pathTarget = nil
	-- Optional real animations for user-provided models
	for name, track in c.tracks do
		local wanted = (state == "Attack" and name == "Attack")
			or (state == "Listen" and name == "Listen")
			or ((state == "Chase") and name == "Run")
			or ((state == "Patrol" or state == "Investigate" or state == "Search" or state == "Retreat") and name == "Walk")
			or ((state == "Blinded" or state == "Dormant") and name == "Idle")
		if wanted and not track.IsPlaying then
			track:Play(0.2)
		elseif not wanted and track.IsPlaying then
			track:Stop(0.2)
		end
	end
	if state == "Chase" then
		Net.Event("Sfx"):FireAllClients("creature_alert", c.root)
	end
end

local function playersInGame(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("FZ_InGame") and not player:GetAttribute("FZ_Downed") and not player:GetAttribute("FZ_MonsterMode") then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				table.insert(list, player)
			end
		end
	end
	return list
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasLineOfSight(c: Creature, from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local filter = { c.model }
	for _, instance in ignore do
		table.insert(filter, instance)
	end
	rayParams.FilterDescendantsInstances = filter
	local result = workspace:Raycast(from, to - from, rayParams)
	return result == nil
end

local function eyePosition(c: Creature): Vector3
	local head = c.model:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.Position else c.root.Position + Vector3.new(0, 3, 0)
end

local function findVisiblePlayer(c: Creature): (Player?, number)
	local best, bestDistance = nil, math.huge
	local eye = eyePosition(c)
	local look = flat(c.root.CFrame.LookVector).Unit
	for _, player in playersInGame() do
		local character = player.Character :: Model
		local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
		local target = (head :: BasePart).Position
		local offset = target - eye
		local distance = offset.Magnitude
		if distance < CC.SightRange then
			local direction = flat(offset)
			local angle = if direction.Magnitude > 0 then math.deg(math.acos(math.clamp(look:Dot(direction.Unit), -1, 1))) else 0
			if (angle <= CC.SightAngle or distance < 9) and hasLineOfSight(c, eye, target, { character }) then
				if distance < bestDistance then
					best, bestDistance = player, distance
				end
			end
		end
	end
	return best, bestDistance
end

---------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------
local function computePath(c: Creature, target: Vector3)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 9,
		AgentCanJump = false,
		WaypointSpacing = 5,
	})
	local ok = pcall(function()
		path:ComputeAsync(c.root.Position, target)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		c.waypoints = path:GetWaypoints()
		c.waypointIndex = math.min(2, #c.waypoints)
	else
		c.waypoints = { PathWaypoint.new(target, Enum.PathWaypointAction.Walk) }
		c.waypointIndex = 1
	end
	c.pathTarget = target
end

-- Returns true when the target is reached.
local function moveTowards(c: Creature, target: Vector3, speed: number, repathInterval: number?): boolean
	c.humanoid.WalkSpeed = speed * soloScale() * difficulty.speed
	local now = os.clock()
	if not c.pathTarget or (c.pathTarget - target).Magnitude > 4 or (repathInterval and now >= c.nextRepath) then
		computePath(c, target)
		c.nextRepath = now + (repathInterval or 2)
	end
	if flat(c.root.Position - target).Magnitude < 3.5 then
		c.humanoid:Move(Vector3.zero)
		return true
	end
	local waypoint = c.waypoints[c.waypointIndex]
	if not waypoint then
		return true
	end
	if flat(c.root.Position - waypoint.Position).Magnitude < 3 then
		c.waypointIndex += 1
		waypoint = c.waypoints[c.waypointIndex]
		if not waypoint then
			return flat(c.root.Position - target).Magnitude < 6
		end
	end
	c.humanoid:MoveTo(waypoint.Position)
	-- Open unlocked doors right in front of it (makes noise, very readable)
	for _, panel in CollectionService:GetTagged("FZ_Door") do
		if panel:IsA("BasePart") and not panel:GetAttribute("Open") and not panel:GetAttribute("Locked") then
			if (panel.Position - c.root.Position).Magnitude < 8 then
				DoorService.Open(panel)
			end
		end
	end
	return false
end

local function stop(c: Creature)
	c.humanoid:MoveTo(c.root.Position)
	c.humanoid.WalkSpeed = 0
end

local function face(c: Creature, position: Vector3)
	local from = c.root.Position
	local to = Vector3.new(position.X, from.Y, position.Z)
	if (to - from).Magnitude > 0.1 then
		c.root.CFrame = CFrame.lookAt(from, to)
	end
end

local function pickPatrolNode(c: Creature, near: Vector3?, radius: number?): Vector3?
	local nodes = CollectionService:GetTagged("FZ_CreaturePatrol")
	local candidates = {}
	local now = os.clock()
	for _, node in nodes do
		if node:IsA("BasePart") then
			local distance = (node.Position - (near or c.root.Position)).Magnitude
			local fresh = now - (c.visitedPatrol[node] or -999) > 40
			if (not radius or distance <= radius) and distance > 6 and fresh then
				table.insert(candidates, node)
			end
		end
	end
	if #candidates == 0 then
		for _, node in nodes do
			if node:IsA("BasePart") then
				table.insert(candidates, node)
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	local chosen = candidates[math.random(1, #candidates)] :: BasePart
	c.visitedPatrol[chosen] = now
	return chosen.Position
end

---------------------------------------------------------------------------
-- Vents
---------------------------------------------------------------------------
local function nearestVent(position: Vector3, exclude: Instance?): BasePart?
	local best, bestDistance = nil, math.huge
	for _, vent in CollectionService:GetTagged("FZ_Vent") do
		if vent ~= exclude and vent:IsA("BasePart") then
			local d = (vent.Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = vent, d
			end
		end
	end
	return best
end

local function travelVent(c: Creature, destination: Vector3)
	local entry = nearestVent(c.root.Position)
	local exit = nearestVent(destination, entry)
	if not entry or not exit or (entry.Position - c.root.Position).Magnitude > 12 then
		return false
	end
	setState(c, "Vent")
	Net.Event("Sfx"):FireAllClients("vent_rattle", entry.Position)
	c.root.Anchored = true
	c.model:SetAttribute("Hidden", true)
	c.model:PivotTo(CFrame.new(entry.Position.X, -200, entry.Position.Z))
	task.wait(CC.VentTravelTime - CC.VentWarning)
	if not alive(c) then
		return true
	end
	Net.Event("Sfx"):FireAllClients("vent_rattle", exit.Position)
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and ((root :: BasePart).Position - exit.Position).Magnitude < 45 then
			Net.Event("Subtitle"):FireClient(player, { text = "SFX_VENT", channel = "world", duration = 3, critical = true })
		end
	end
	task.wait(CC.VentWarning)
	if not alive(c) then
		return true
	end
	local out = exit.CFrame * CFrame.new(0, 0, -4)
	c.model:PivotTo(CFrame.new(out.Position.X, exit.Position.Y + 5, out.Position.Z) * CFrame.Angles(0, select(2, out:ToOrientation()), 0))
	c.root.Anchored = false
	c.model:SetAttribute("Hidden", false)
	c.searchCenter = exit.Position
	setState(c, "Search")
	return true
end

---------------------------------------------------------------------------
-- State machine
---------------------------------------------------------------------------
local function startInvestigate(c: Creature, position: Vector3)
	c.target = position
	setState(c, "Listen")
	stop(c)
	face(c, position)
end

local function step(c: Creature)
	local now = os.clock()
	local elapsed = now - c.stateTime
	local state = c.state

	if state == "Dormant" or state == "Vent" then
		return
	end

	if state == "Blinded" then
		stop(c)
		if elapsed > CC.BlindDuration then
			setState(c, "Retreat")
			c.target = pickPatrolNode(c, nil, nil)
		end
		return
	end

	-- Perception (sight beats hearing)
	local seen, seenDistance = findVisiblePlayer(c)
	if seen and state ~= "Attack" then
		c.targetPlayer = seen
		c.lastSeen = now
		local root = (seen.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
		c.lastSeenPosition = root.Position
		if state ~= "Chase" and (seenDistance < 25 or state == "Investigate" or state == "Search") then
			setState(c, "Chase")
		elseif state == "Patrol" then
			startInvestigate(c, root.Position)
		end
	end
	local noise = c.pendingNoise
	c.pendingNoise = nil
	if noise and state ~= "Chase" and state ~= "Attack" and state ~= "Retreat" then
		if state == "Investigate" or state == "Search" then
			c.target = noise.position -- update the goal, keep moving
			if state == "Search" then
				setState(c, "Investigate")
			end
		elseif state ~= "Listen" then
			startInvestigate(c, noise.position)
		end
	end

	state = c.state
	elapsed = now - c.stateTime

	if state == "Patrol" then
		if not c.target then
			c.target = pickPatrolNode(c, nil, nil)
		end
		if c.target and moveTowards(c, c.target, CC.PatrolSpeed) then
			c.target = pickPatrolNode(c, nil, nil)
		end
	elseif state == "Listen" then
		stop(c)
		if elapsed > CC.ListenTime then
			setState(c, "Investigate")
		end
	elseif state == "Investigate" then
		if not c.target or moveTowards(c, c.target, CC.InvestigateSpeed) then
			c.searchCenter = c.target or c.root.Position
			setState(c, "Search")
		end
	elseif state == "Search" then
		if elapsed > CC.SearchTime then
			setState(c, "Patrol")
			c.target = nil
		else
			if not c.target or moveTowards(c, c.target, CC.PatrolSpeed + 1) then
				c.target = pickPatrolNode(c, c.searchCenter, 45) or c.searchCenter
			end
		end
	elseif state == "Chase" then
		local player = c.targetPlayer
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not player or not root or player:GetAttribute("FZ_Downed") or not player:GetAttribute("FZ_InGame") then
			c.searchCenter = c.lastSeenPosition or c.root.Position
			setState(c, "Search")
			return
		end
		if now - c.lastSeen > CC.LoseTrackTime then
			c.searchCenter = c.lastSeenPosition
			c.target = c.lastSeenPosition
			-- Sometimes it takes the vents instead of following
			if c.lastSeenPosition and math.random() < difficulty.ventChance and (c.lastSeenPosition - c.root.Position).Magnitude > 40 then
				task.spawn(travelVent, c, c.lastSeenPosition)
				return
			end
			setState(c, "Investigate")
			return
		end
		local goal = if now - c.lastSeen < 0.5 then root.Position else (c.lastSeenPosition or root.Position)
		moveTowards(c, goal, CC.ChaseSpeed, 0.6)
		if (root.Position - c.root.Position).Magnitude <= CC.AttackRange and now >= c.nextAttack then
			setState(c, "Attack")
		end
	elseif state == "Attack" then
		local player = c.targetPlayer
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		c.humanoid.WalkSpeed = 2
		if root then
			face(c, root.Position)
		end
		if elapsed >= CC.AttackWindup then
			if player and root and (root.Position - c.root.Position).Magnitude <= CC.AttackRange + 1.5 then
				HealthService.Damage(player, CC.Damage)
				Net.Event("Sfx"):FireAllClients("creature_static_burst", c.root)
			end
			c.nextAttack = now + CC.AttackCooldown
			setState(c, "Chase")
		end
	elseif state == "Retreat" then
		if not c.target or moveTowards(c, c.target, CC.InvestigateSpeed) or elapsed > 8 then
			setState(c, "Patrol")
			c.target = nil
		end
	end

	-- Observer set: fresh tracks
	if c.state ~= "Vent" and now - c.lastFootprint > 1.6 and c.root.AssemblyLinearVelocity.Magnitude > 2 then
		c.lastFootprint = now
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("FZ_Footprints") then
				Net.Event("Footprint"):FireClient(player, c.root.Position - Vector3.new(0, 5.6, 0))
			end
		end
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
local function loadTracks(c: Creature)
	local animator = c.humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	for name, id in Assets.CreatureAnimations do
		if id ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(animator.LoadAnimation, animator, animation)
			if ok then
				track.Looped = name ~= "Attack"
				c.tracks[name] = track
			end
		end
	end
end

function CreatureService.Despawn()
	for _, c in creatures do
		c.model:Destroy()
	end
	table.clear(creatures)
end

-- keepExisting = true adds another creature (survival escalation).
function CreatureService.Spawn(cframe: CFrame?, keepExisting: boolean?): Model
	if not keepExisting then
		CreatureService.Despawn()
	end
	local spawnCFrame = cframe
	if not spawnCFrame then
		local marker = CollectionService:GetTagged("FZ_CreatureSpawn")[1]
		spawnCFrame = if marker and marker:IsA("BasePart") then marker.CFrame else CFrame.new(0, 10, 0)
	end
	local model = Rig.Create()
	model:PivotTo(spawnCFrame :: CFrame)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	model.Parent = workspace
	Rig.Tag(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local c: Creature = {
		model = model,
		humanoid = humanoid,
		root = root,
		state = "",
		stateTime = os.clock(),
		target = nil,
		targetPlayer = nil,
		lastSeen = 0,
		lastSeenPosition = nil,
		waypoints = {},
		waypointIndex = 1,
		pathTarget = nil,
		nextRepath = 0,
		nextAttack = 0,
		blindReadyAt = 0,
		visitedPatrol = {},
		searchCenter = nil,
		pendingNoise = nil,
		tracks = {},
		lastFootprint = 0,
	}
	loadTracks(c)
	table.insert(creatures, c)
	setState(c, if aiEnabled then "Patrol" else "Dormant")

	task.spawn(function()
		while alive(c) do
			if aiEnabled then
				local ok, err = pcall(step, c)
				if not ok then
					warn("[FZ-Creature] AI step failed: " .. tostring(err))
				end
			end
			task.wait(TICK)
		end
	end)
	return model
end

function CreatureService.SetAIEnabled(enabled: boolean)
	aiEnabled = enabled
	for _, c in creatures do
		if enabled then
			setState(c, "Patrol")
		else
			setState(c, "Dormant")
			stop(c)
		end
	end
end

-- speed / hearing multipliers and vent chance (survival difficulty curve)
function CreatureService.SetDifficulty(values: { speed: number?, hearing: number?, ventChance: number? })
	difficulty.speed = values.speed or 1
	difficulty.hearing = values.hearing or 1
	difficulty.ventChance = values.ventChance or CC.VentChance
end

function CreatureService.Count(): number
	return #creatures
end

function CreatureService.IsAIEnabled(): boolean
	return aiEnabled
end

function CreatureService.Get(): Model?
	return creatures[1] and creatures[1].model
end

-- Loud event somewhere: the nearest creature that is not busy comes to look.
function CreatureService.Alert(position: Vector3)
	local best, bestDistance = nil, math.huge
	for _, c in creatures do
		if c.state ~= "Chase" and c.state ~= "Vent" and c.state ~= "Dormant" then
			local d = (c.root.Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = c, d
			end
		end
	end
	if best and aiEnabled then
		startInvestigate(best, position)
	end
end

function CreatureService.Start()
	NoiseService.Heard:Connect(function(position, radius, _source)
		for _, c in creatures do
			if not c.model:GetAttribute("Hidden") then
				local distance = (position - c.root.Position).Magnitude
				if distance <= radius * CC.HearingScale * difficulty.hearing then
					local current = c.pendingNoise
					if not current or radius > current.radius then
						c.pendingNoise = { position = position, radius = radius }
					end
				end
			end
		end
	end)

	-- Flashlight: the client reports a hit, the server re-validates everything.
	local limiter = RateLimiter.new(4, 2)
	local function tryBlind(player: Player, c: Creature): boolean
		if os.clock() < c.blindReadyAt or c.state == "Vent" or c.state == "Blinded" or c.state == "Dormant" then
			return false
		end
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local light = head and head:FindFirstChild("FZ_Flashlight") :: SpotLight?
		if not head or not light or not light.Enabled or player:GetAttribute("FZ_Downed") then
			return false
		end
		local eye = eyePosition(c)
		local range = CC.BlindRange * (tonumber(player:GetAttribute("FZ_FlashRange")) or 1)
		local toCreature = eye - head.Position
		if toCreature.Magnitude > range then
			return false
		end
		local facing = flat((character :: Model):GetPivot().LookVector)
		local direction = flat(toCreature)
		if facing.Magnitude > 0 and direction.Magnitude > 0 and facing.Unit:Dot(direction.Unit) < math.cos(math.rad(60)) then
			return false
		end
		if not hasLineOfSight(c, head.Position, eye, { character :: Model }) then
			return false
		end
		local cooldown = CC.BlindCooldown * (tonumber(player:GetAttribute("FZ_BlindCooldownScale")) or 1)
		c.blindReadyAt = os.clock() + cooldown
		setState(c, "Blinded")
		stop(c)
		Net.Event("Sfx"):FireAllClients("creature_static_burst", c.root)
		return true
	end

	Net.Event("FlashCreature").OnServerEvent:Connect(function(player: Player)
		if not limiter:Allow(player) or not aiEnabled then
			return
		end
		for _, c in creatures do
			if tryBlind(player, c) then
				return
			end
		end
	end)
end

return CreatureService
