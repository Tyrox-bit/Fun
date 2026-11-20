-- CreatureVisualsController: everything the player SEES and HEARS of the creature.
--   * Procedural animation (Motor6D.Transform) for the built-in rig: long-limbed gait,
--     listening head tilt, telegraphed attack wind-up, covering its head when blinded
--   * "Signal dropouts": the pose freezes for a few frames now and then, with a crackle
--   * Breath loop on the head, random clicks, a close-range warning caption
--   * Vent travel: hidden locally while the server moves it
-- Rigs with Procedural = false (your own model with real animations) only get audio.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AudioController = require(script.Parent.AudioController)

local CreatureVisualsController = {}

type RigState = {
	model: Model,
	motors: { [string]: Motor6D },
	phase: number,
	frozenUntil: number,
	nextFreeze: number,
	nextClick: number,
	breath: Sound?,
	lastHidden: boolean?,
}

local rigs: { [Model]: RigState } = {}
local showCaption: ((line: { [string]: any }) -> ())? = nil
local lastWarning = 0

local function angles(x: number, y: number, z: number): CFrame
	return CFrame.Angles(x, y, z)
end

local function register(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local motors = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
		end
	end
	local head = model:WaitForChild("Head", 5)
	local state: RigState = {
		model = model,
		motors = motors,
		phase = 0,
		frozenUntil = 0,
		nextFreeze = os.clock() + 2,
		nextClick = os.clock() + 3,
		breath = if head and head:IsA("BasePart") then AudioController.Loop("creature_breath", head, 0.45, "Creature") else nil,
		lastHidden = nil,
	}
	rigs[model] = state
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			rigs[model] = nil
		end
	end)
end

local function setHidden(state: RigState, hidden: boolean)
	if state.lastHidden == hidden then
		return
	end
	state.lastHidden = hidden
	for _, descendant in state.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
	if state.breath then
		state.breath.Volume = if hidden then 0 else 0.45
	end
end

local function animate(state: RigState, dt: number)
	local model = state.model
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local m = state.motors
	local now = os.clock()
	local creatureState = model:GetAttribute("State") or "Patrol"
	setHidden(state, model:GetAttribute("Hidden") == true)

	-- Audio cues (distance-limited)
	local camera = workspace.CurrentCamera
	local distance = if camera then (root.Position - camera.CFrame.Position).Magnitude else math.huge
	if model == Players.LocalPlayer.Character then
		distance = math.huge -- you are the monster (admin test mode): no warnings for yourself
	end
	if now >= state.nextClick and creatureState ~= "Dormant" and distance < 60 and not state.lastHidden then
		state.nextClick = now + math.random(30, 70) / 10
		AudioController.Play("creature_click", root, 0.7, "Creature")
	end
	if distance < 16 and creatureState ~= "Dormant" and not state.lastHidden and now - lastWarning > 25 and showCaption then
		lastWarning = now
		showCaption({ text = "SFX_CREATURE_NEAR", channel = "world", duration = 2.5, critical = true })
	end

	if model:GetAttribute("Procedural") ~= true then
		return
	end

	-- Signal dropout: freeze the pose for a few frames
	if now >= state.nextFreeze then
		state.frozenUntil = now + math.random(6, 16) / 100
		state.nextFreeze = now + math.random(8, 26) / 10
		if distance < 35 and math.random() < 0.35 then
			AudioController.Play("creature_static_burst", root, 0.35, "Creature")
		end
	end
	if now < state.frozenUntil then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local stride = math.clamp(speed / 12, 0, 1.2)
	state.phase += dt * (2 + speed * 0.45)
	local p = state.phase
	local swing = math.sin(p) * 0.7 * stride
	local breathe = math.sin(now * 1.7) * 0.04

	local hunch, neckX, neckZ = -0.15, 0.25, 0
	local armL, armR, elbow = 0.25 - swing * 0.6, 0.25 + swing * 0.6, -0.35
	if creatureState == "Listen" then
		hunch, neckX, neckZ = 0.05, 0.1, math.sin(now * 0.8) * 0.15 + 0.55
		armL, armR = 0.05, 0.05
	elseif creatureState == "Attack" then
		hunch, neckX = -0.35, 0.45
		armL, armR, elbow = -2.3, -2.1, -0.6
	elseif creatureState == "Blinded" then
		hunch, neckX = 0.25, -0.4
		armL, armR, elbow = -2.6, -2.6, -2.0
	elseif creatureState == "Chase" then
		hunch, neckX = -0.45, 0.55
	end

	local function set(name: string, cf: CFrame)
		local motor = m[name]
		if motor then
			motor.Transform = cf
		end
	end
	set("RootJoint", angles(hunch + breathe, 0, math.sin(p) * 0.06 * stride))
	set("Neck", angles(neckX, math.sin(now * 0.37) * 0.15, neckZ))
	set("LeftShoulder", angles(armL, 0, -0.08))
	set("RightShoulder", angles(armR, 0, 0.08))
	set("LeftElbow", angles(elbow - math.max(0, swing) * 0.4, 0, 0))
	set("RightElbow", angles(elbow - math.max(0, -swing) * 0.4, 0, 0))
	set("LeftHip", angles(swing, 0, 0))
	set("RightHip", angles(-swing, 0, 0))
	set("LeftKnee", angles(-math.max(0, math.sin(p + 0.9)) * 1.1 * stride, 0, 0))
	set("RightKnee", angles(-math.max(0, math.sin(p + 0.9 + math.pi)) * 1.1 * stride, 0, 0))
end

function CreatureVisualsController.Init(captionCallback: (line: { [string]: any }) -> ())
	showCaption = captionCallback
	CollectionService:GetInstanceAddedSignal("FZ_CreatureRig"):Connect(register)
	for _, model in CollectionService:GetTagged("FZ_CreatureRig") do
		task.spawn(register, model)
	end
	CollectionService:GetInstanceRemovedSignal("FZ_CreatureRig"):Connect(function(model)
		rigs[model :: Model] = nil
	end)
	-- Stepped runs before physics/animation, the documented place for Motor6D.Transform.
	RunService.Stepped:Connect(function(_, dt)
		for _, state in rigs do
			animate(state, dt)
		end
	end)
end

return CreatureVisualsController
