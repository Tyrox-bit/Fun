-- DirectorController: performs the HorrorDirector's moments on THIS client only.
-- Respects the player's "Scare intensity": reduced = farther away, shorter, no stinger;
-- intense = closer, stinger sound. Nothing here flashes the screen or spikes volume.
--
--   apparition : a tall figure at the end of the hallway you look down - gone a moment later
--   footsteps  : steps right behind you (turn around: nothing)
--   flicker    : the lights in your room stutter for a second
--   cctv       : the security monitor shows your team 20 s in the future (+ a figure)
--   namecall   : a voice on the radio says your name - only you hear it

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)
local SessionState = require(Shared.SessionState)

local AudioController = require(script.Parent.AudioController)

local DirectorController = {}

local player = Players.LocalPlayer
local settings = nil
local showSubtitle: ((line: { [string]: any }) -> ())? = nil

local function intensity(): string
	return settings and settings.Get("scareIntensity") or "standard"
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

---------------------------------------------------------------------------
-- Figure (local only, never collides, never hurts)
---------------------------------------------------------------------------
local function buildFigure(): Model
	local model = Instance.new("Model")
	model.Name = "FZ_Apparition"
	local color = Color3.fromRGB(14, 12, 12)
	local function part(name: string, size: Vector3, cf: CFrame)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = true
		p.Parent = model
		return p
	end
	local root = part("Torso", Vector3.new(1.3, 3.4, 0.7), CFrame.new(0, 6.3, 0))
	model.PrimaryPart = root
	part("Head", Vector3.new(1.2, 1.3, 1.5), CFrame.new(0, 8.6, -0.2))
	local horn = part("Horn", Vector3.new(0.4, 2, 2), CFrame.new(0, 8.6, -1.1) * CFrame.Angles(0, math.rad(90), 0))
	horn.Shape = Enum.PartType.Cylinder
	for _, s in { -1, 1 } do
		part("Arm", Vector3.new(0.3, 6.4, 0.3), CFrame.new(s * 0.9, 4.6, 0) * CFrame.Angles(0, 0, s * 0.06))
		part("Leg", Vector3.new(0.4, 4.8, 0.4), CFrame.new(s * 0.4, 2.4, 0))
	end
	return model
end

local function apparition()
	local camera = workspace.CurrentCamera
	local character = player.Character
	if not camera or not character then
		return
	end
	local level = intensity()
	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.1 then
		return
	end
	flatLook = flatLook.Unit
	rayParams.FilterDescendantsInstances = { character, camera }
	local origin = camera.CFrame.Position
	local hit = workspace:Raycast(origin, flatLook * 90, rayParams)
	local distance = if hit then hit.Distance - 3 else 70
	local minimum = if level == "reduced" then 45 elseif level == "intense" then 22 else 30
	if distance < minimum then
		return -- not a long enough sightline right now: skip rather than force it
	end
	local floor = workspace:Raycast(origin + flatLook * distance, Vector3.new(0, -30, 0), rayParams)
	local base = if floor then floor.Position else (origin + flatLook * distance - Vector3.new(0, 4.5, 0))
	local figure = buildFigure()
	figure:PivotTo(CFrame.lookAt(base, base - flatLook))
	figure.Parent = camera
	if level == "intense" then
		AudioController.Play("stinger_low", nil, 0.5, "Creature")
	end
	AudioController.Play("creature_click", base + Vector3.new(0, 6, 0), 0.6, "Creature")
	local lifetime = if level == "reduced" then 1.2 elseif level == "intense" then 2.4 else 1.8
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local cam = workspace.CurrentCamera
		local tooClose = cam and (cam.CFrame.Position - base).Magnitude < 18
		if os.clock() - started > lifetime or tooClose then
			connection:Disconnect()
			-- gone in a single frame, like a signal dropout
			figure:Destroy()
		end
	end)
end

local function footsteps()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local count = if intensity() == "reduced" then 2 elseif intensity() == "intense" then 6 else 4
	for i = 1, count do
		task.delay(i * 0.42, function()
			local cam = workspace.CurrentCamera
			if cam then
				local behind = cam.CFrame.Position - Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit * 7 - Vector3.new(0, 4, 0)
				AudioController.Play("footstep_concrete_" .. ((i % 3) + 1), behind, 0.7)
			end
		end)
	end
end

local function flicker()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local lights = {}
	for _, fixture in CollectionService:GetTagged("FZ_SectorLight") do
		if fixture:IsA("BasePart") and (fixture.Position - camera.CFrame.Position).Magnitude < 35 then
			for _, child in fixture:GetChildren() do
				if child:IsA("Light") and child.Enabled then
					table.insert(lights, child)
				end
			end
		end
	end
	if #lights == 0 then
		return
	end
	AudioController.Play("creature_static_burst", camera.CFrame.Position + camera.CFrame.LookVector * 6, 0.3, "Creature")
	local pattern = if intensity() == "reduced" then { 0.08, 0.25 } else { 0.06, 0.12, 0.05, 0.3, 0.08 }
	task.spawn(function()
		local on = false
		for _, wait in pattern do
			for _, light in lights do
				light.Enabled = on
			end
			on = not on
			task.wait(wait)
		end
		for _, light in lights do
			-- restore only if the light is still supposed to have power
			local fixture = light.Parent
			light.Enabled = fixture == nil or fixture:GetAttribute("Powered") ~= false
		end
	end)
end

-- Security monitor: a little scene of the team in a hallway, time-stamped 20 s ahead.
local function cctv(data: { [string]: any })
	local screen = CollectionService:GetTagged("FZ_CctvScreen")[1]
	if not screen or not screen:IsA("BasePart") then
		return
	end
	local old = screen:FindFirstChild("FZ_Feed")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "FZ_Feed"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.AutoLocalize = false
	gui.LightInfluence = 0
	gui.Parent = screen
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.fromRGB(6, 12, 8)
	viewport.Ambient = Color3.fromRGB(110, 140, 120)
	viewport.LightColor = Color3.fromRGB(170, 220, 180)
	viewport.Parent = gui
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	-- corridor
	local function slab(size: Vector3, cf: CFrame, color: Color3)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.Concrete
		p.Parent = world
	end
	slab(Vector3.new(14, 1, 60), CFrame.new(0, -0.5, -20), Color3.fromRGB(60, 62, 58))
	slab(Vector3.new(1, 14, 60), CFrame.new(-7, 7, -20), Color3.fromRGB(80, 82, 78))
	slab(Vector3.new(1, 14, 60), CFrame.new(7, 7, -20), Color3.fromRGB(80, 82, 78))
	-- the team (copies of the real characters, walking away from the camera)
	local index = 0
	for _, member in Players:GetPlayers() do
		local character = member.Character
		if character and member:GetAttribute("FZ_InGame") then
			local archivable = character.Archivable
			character.Archivable = true
			local copy = character:Clone()
			character.Archivable = archivable
			if copy then
				for _, d in copy:GetDescendants() do
					if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("Light") then
						d:Destroy()
					elseif d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				copy:PivotTo(CFrame.new((index % 2) * 3 - 1.5, 3, -18 - index * 4) * CFrame.Angles(0, math.rad(180), 0))
				copy.Parent = world
				index += 1
			end
		end
	end
	if data.withFigure then
		local figure = buildFigure()
		figure:PivotTo(CFrame.new(0, 0, -18 - index * 4 - 6))
		figure.Parent = world
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 60
	camera.CFrame = CFrame.lookAt(Vector3.new(4.5, 11, 8), Vector3.new(0, 3, -22))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local stamp = Instance.new("TextLabel")
	stamp.BackgroundTransparency = 1
	stamp.Size = UDim2.new(1, -8, 0, 16)
	stamp.Position = UDim2.fromOffset(4, 2)
	stamp.Font = Enum.Font.RobotoMono
	stamp.TextScaled = true
	stamp.TextXAlignment = Enum.TextXAlignment.Left
	stamp.TextColor3 = Color3.fromRGB(230, 236, 230)
	stamp.AutoLocalize = false
	stamp.Text = Localization.T("CCTV_STAMP", { seconds = data.offset or 20 })
	stamp.Parent = viewport
	-- static fade-out after a few seconds
	task.delay(if intensity() == "reduced" then 6 else 9, function()
		if gui.Parent then
			TweenService:Create(viewport, TweenInfo.new(0.6), { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.wait(0.7)
			gui:Destroy()
		end
	end)
end

local function namecall(data: { [string]: any })
	if showSubtitle then
		showSubtitle({
			speaker = "SPEAKER_UNKNOWN",
			text = if data.answered then "RADIO_NAMECALL_ANSWERED" else "RADIO_NAMECALL",
			params = { name = tostring(data.name or player.DisplayName) },
			channel = "radio",
			duration = 3.5,
		})
	end
	AudioController.Play("radio_squelch_on", nil, 0.5)
end

-- Live creature location on the second monitor while the cameras have power.
local function bindCctvText()
	local function refresh()
		for _, screen in CollectionService:GetTagged("FZ_CctvText") do
			if screen:IsA("BasePart") then
				local gui = screen:FindFirstChild("FZ_CctvGui") :: SurfaceGui?
				if not gui then
					local g = Instance.new("SurfaceGui")
					g.Name = "FZ_CctvGui"
					g.Face = Enum.NormalId.Front
					g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
					g.PixelsPerStud = 120
					g.AutoLocalize = false
					g.LightInfluence = 0
					local label = Instance.new("TextLabel")
					label.Name = "Text"
					label.BackgroundTransparency = 1
					label.Size = UDim2.fromScale(1, 1)
					label.Font = Enum.Font.RobotoMono
					label.TextScaled = true
					label.TextColor3 = Color3.fromRGB(10, 40, 20)
					label.AutoLocalize = false
					label.Parent = g
					g.Parent = screen
					gui = g
				end
				local label = (gui :: SurfaceGui):FindFirstChild("Text") :: TextLabel
				local area = SessionState.Get("CctvArea")
				if SessionState.Get("Cameras") and area == "-" then
					label.Text = Localization.T("CCTV_NONE")
				elseif SessionState.Get("Cameras") and type(area) == "string" then
					local areaKey = if area == "?" then "AREA_UNKNOWN" else "AREA_" .. area
					label.Text = Localization.T("CCTV_AREA", { area = Localization.T(areaKey) })
				else
					label.Text = Localization.T("CCTV_OFFLINE")
				end
			end
		end
	end
	SessionState.Observe("Cameras", refresh)
	SessionState.Observe("CctvArea", refresh)
	Localization.Changed:Connect(refresh)
	CollectionService:GetInstanceAddedSignal("FZ_CctvText"):Connect(refresh)
end

function DirectorController.Init(settingsController, captionCallback: (line: { [string]: any }) -> ())
	settings = settingsController
	showSubtitle = captionCallback
	Net.Event("Scare").OnClientEvent:Connect(function(kind: any, data: any)
		if type(kind) ~= "string" then
			return
		end
		data = if type(data) == "table" then data else {}
		if kind == "apparition" then
			apparition()
		elseif kind == "footsteps" then
			footsteps()
		elseif kind == "flicker" then
			flicker()
		elseif kind == "cctv" then
			cctv(data)
		elseif kind == "namecall" then
			namecall(data)
		end
	end)
	bindCctvText()
end

return DirectorController
