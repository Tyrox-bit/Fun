-- Headless server playthrough (Lune). Builds a real map with its builder, starts the real
-- interaction / forecast / door / power / story systems and plays a chapter (or survival)
-- from start to finish with simulated players, virtual time and scripted choices.
-- Everything else (data stores, creature AI, analytics ...) is stubbed and recorded.
--
-- Usage: lune run tools/server_smoke.luau            (all scenarios)
--        lune run tools/server_smoke.luau ch3_order  (one scenario)
--
-- It proves the story flow is reachable and free of runtime errors; it does not judge
-- pacing, physics, pathfinding or anything visual.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = "src"

---------------------------------------------------------------------------
-- Virtual time + task scheduler
---------------------------------------------------------------------------
local now = 0
local queue = {} -- { at, seq, thread?, fn?, args }
local seq = 0
local errors = {}

local function schedule(at, entry)
	seq += 1
	entry.at = at
	entry.seq = seq
	table.insert(queue, entry)
end

local function runThread(thread, ...)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		table.insert(errors, debug.traceback(thread, tostring(err)))
	end
end

local taskShim = {}
function taskShim.spawn(fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	runThread(thread, ...)
	return thread
end
function taskShim.defer(fn, ...)
	local args = table.pack(...)
	schedule(now, { fn = fn, args = args })
end
function taskShim.delay(seconds, fn, ...)
	local args = table.pack(...)
	schedule(now + (seconds or 0), { fn = fn, args = args })
end
function taskShim.wait(seconds)
	local thread = coroutine.running()
	schedule(now + (seconds or 0.03), { thread = thread })
	coroutine.yield()
	return seconds or 0.03
end
function taskShim.cancel() end

local function advance(seconds)
	local target = now + seconds
	while true do
		table.sort(queue, function(a, b)
			return if a.at == b.at then a.seq < b.seq else a.at < b.at
		end)
		local nextEntry = queue[1]
		if not nextEntry or nextEntry.at > target then
			break
		end
		table.remove(queue, 1)
		now = math.max(now, nextEntry.at)
		if nextEntry.thread then
			if coroutine.status(nextEntry.thread) == "suspended" then
				runThread(nextEntry.thread)
			end
		else
			runThread(coroutine.create(nextEntry.fn), table.unpack(nextEntry.args, 1, nextEntry.args.n))
		end
	end
	now = target
end

---------------------------------------------------------------------------
-- Signals + instance proxies (real Lune instances: property validation)
---------------------------------------------------------------------------
local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end, Connected = true }
	end
	function signal:Once(fn)
		return self:Connect(fn)
	end
	function signal:Wait()
		return nil
	end
	function signal:Fire(...)
		for _, fn in table.clone(self.handlers) do
			local ok, err = pcall(fn, ...)
			if not ok then
				table.insert(errors, "signal handler: " .. tostring(err))
			end
		end
	end
	return signal
end

local realOf = setmetatable({}, { __mode = "k" })
local proxyOf = {}
local signals = {}
local wrap, unwrap
local function isProxy(v)
	return type(v) == "table" and realOf[v] ~= nil
end
unwrap = function(v)
	if isProxy(v) then
		return realOf[v]
	end
	return v
end
local function signalFor(real, key)
	signals[real] = signals[real] or {}
	signals[real][key] = signals[real][key] or newSignal()
	return signals[real][key]
end
local function wrapAll(...)
	local out = table.pack(...)
	for i = 1, out.n do
		local v = out[i]
		if typeof(v) == "Instance" then
			out[i] = wrap(v)
		elseif type(v) == "table" and not isProxy(v) then
			for k, item in v do
				if typeof(item) == "Instance" then
					v[k] = wrap(item)
				end
			end
		end
	end
	return table.unpack(out, 1, out.n)
end

local EVENTS = {
	Triggered = true, PromptButtonHoldBegan = true, Activated = true, Changed = true, AncestryChanged = true,
	Destroying = true, ChildAdded = true, ChildRemoved = true, Touched = true, Completed = true, Died = true,
	DescendantAdded = true,
}

local INTERCEPT = {}
function INTERCEPT.GetPropertyChangedSignal(real, prop)
	return signalFor(real, "prop:" .. prop)
end
function INTERCEPT.GetAttributeChangedSignal(real, name)
	return signalFor(real, "attr:" .. name)
end
function INTERCEPT.WaitForChild(real, name)
	return real:FindFirstChild(name)
end
function INTERCEPT.GetServerTimeNow()
	return now
end
function INTERCEPT.PivotTo(real, cf)
	local rootPart = real:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = cf
	end
end
function INTERCEPT.GetPivot(real)
	if real:IsA("Model") then
		local rootPart = real:FindFirstChild("HumanoidRootPart") or real:FindFirstChildWhichIsA("BasePart")
		return rootPart and rootPart.CFrame or roblox.CFrame.new()
	end
	return real.CFrame
end
function INTERCEPT.SetBaseMaterialOverride(real, material, name)
	real[material.Name .. "Name"] = name
end
function INTERCEPT.Destroy(real)
	local list = real:GetDescendants()
	table.insert(list, real)
	for _, d in list do
		local s = signals[d] and signals[d].Destroying
		if s then
			s:Fire()
		end
	end
	real:Destroy()
end
function INTERCEPT.SetAttribute(real, name, value)
	real:SetAttribute(name, unwrap(value))
	local s = signals[real] and signals[real]["attr:" .. name]
	if s then
		s:Fire()
	end
end

local Proxy = {}
Proxy.__index = function(p, key)
	local real = realOf[p]
	if EVENTS[key] then
		return signalFor(real, key)
	end
	if INTERCEPT[key] then
		return function(_, ...)
			local args = table.pack(...)
			for i = 1, args.n do
				args[i] = unwrap(args[i])
			end
			return wrapAll(INTERCEPT[key](real, table.unpack(args, 1, args.n)))
		end
	end
	if key == "Terrain" and real.ClassName == "Workspace" then
		local terrain = real:FindFirstChild("Terrain")
		if not terrain then
			terrain = roblox.Instance.new("Folder")
			terrain.Name = "Terrain"
			terrain.Parent = real
		end
		return wrap(terrain)
	end
	if real.Name == "Terrain" and (key == "FillBlock" or key == "FillBall" or key == "FillWedge" or key == "Clear") then
		return function() end
	end
	if key == "Position" and real:IsA("BasePart") then
		return real.CFrame.Position
	end
	local ok, value = pcall(function()
		return real[key]
	end)
	if not ok then
		error(string.format("read %s.%s: %s", real.ClassName, tostring(key), tostring(value)), 2)
	end
	if type(value) == "function" then
		return function(_, ...)
			local args = table.pack(...)
			for i = 1, args.n do
				args[i] = unwrap(args[i])
			end
			return wrapAll(value(real, table.unpack(args, 1, args.n)))
		end
	end
	if typeof(value) == "Instance" then
		return wrap(value)
	end
	return value
end
Proxy.__newindex = function(p, key, value)
	local real = realOf[p]
	if real.Name == "Terrain" and real.ClassName == "Folder" then
		return -- water settings of the stand-in terrain
	end
	if key == "Position" and real:IsA("BasePart") then
		real.CFrame = roblox.CFrame.new(value)
		return
	end
	local ok, err = pcall(function()
		real[key] = unwrap(value)
	end)
	if not ok then
		error(string.format("set %s.%s = %s: %s", real.ClassName, tostring(key), tostring(value), tostring(err)), 2)
	end
end
Proxy.__eq = function(a, b)
	return unwrap(a) == unwrap(b)
end
Proxy.__tostring = function(p)
	return "Proxy<" .. realOf[p]:GetFullName() .. ">"
end
wrap = function(real)
	if real == nil then
		return nil
	end
	local p = proxyOf[real]
	if not p then
		p = setmetatable({}, Proxy)
		realOf[p] = real
		proxyOf[real] = p
	end
	return p
end

---------------------------------------------------------------------------
-- DataModel, CollectionService (backed by real Lune tags)
---------------------------------------------------------------------------
local dataModel = roblox.Instance.new("DataModel")
local realWorkspace = dataModel:GetService("Workspace")
local realLighting = dataModel:GetService("Lighting")
local realPlayers = roblox.Instance.new("Folder")
realPlayers.Name = "Players"

local addedSignals, removedSignals = {}, {}
local CollectionServiceShim = {
	AddTag = function(_, instance, tag)
		local real = unwrap(instance)
		real:AddTag(tag)
		if addedSignals[tag] then
			addedSignals[tag]:Fire(wrap(real))
		end
	end,
	RemoveTag = function(_, instance, tag)
		unwrap(instance):RemoveTag(tag)
	end,
	HasTag = function(_, instance, tag)
		return unwrap(instance):HasTag(tag)
	end,
	GetTagged = function(_, tag)
		local out = {}
		for _, d in dataModel:GetDescendants() do
			if d:HasTag(tag) then
				table.insert(out, wrap(d))
			end
		end
		return out
	end,
	GetInstanceAddedSignal = function(_, tag)
		addedSignals[tag] = addedSignals[tag] or newSignal()
		return addedSignals[tag]
	end,
	GetInstanceRemovedSignal = function(_, tag)
		removedSignals[tag] = removedSignals[tag] or newSignal()
		return removedSignals[tag]
	end,
}

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------
local players = {}
local PlayersShim = {
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
	GetPlayers = function()
		return table.clone(players)
	end,
}

local function makePlayer(index)
	local attributes = {}
	local attrSignals = {}
	local character = roblox.Instance.new("Model")
	character.Name = "Player" .. index
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = roblox.Vector3.new(2, 2, 1)
	root.CFrame = roblox.CFrame.new(0, 3, 600) -- far away, like the menu spawn
	root.Parent = character
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = character
	character.Parent = realWorkspace
	local player = {
		Name = "Player" .. index,
		DisplayName = ({ "Mika", "Jona", "Sam", "Alex" })[index],
		UserId = 1000 + index,
		Parent = realPlayers,
		Character = wrap(character),
		CharacterAdded = newSignal(),
		CharacterRemoving = newSignal(),
	}
	function player:GetAttribute(name)
		return attributes[name]
	end
	function player:SetAttribute(name, value)
		attributes[name] = value
		if attrSignals[name] then
			attrSignals[name]:Fire()
		end
	end
	function player:GetAttributeChangedSignal(name)
		attrSignals[name] = attrSignals[name] or newSignal()
		return attrSignals[name]
	end
	function player:LoadCharacter() end
	function player:Kick() end
	function player:IsA(class)
		return class == "Player" or class == "Instance"
	end
	player.root = root
	attributes.FZ_InGame = true
	table.insert(players, player)
	return player
end

---------------------------------------------------------------------------
-- Module loading (Rojo paths) + stubs
---------------------------------------------------------------------------
local DIRS, FILES = {}, {}
local function indexTree(path)
	DIRS[path] = true
	for _, name in fs.readDir(path) do
		local full = path .. "/" .. name
		if fs.isDir(full) then
			indexTree(full)
		elseif string.sub(name, -5) == ".luau" then
			FILES[full] = fs.readFile(full)
		end
	end
end
indexTree(ROOT)

local PathMeta = {}
local function pathProxy(path)
	return setmetatable({ __path = path }, PathMeta)
end
local function childPath(path, name)
	if DIRS[path .. "/" .. name] then
		return path .. "/" .. name
	end
	for _, suffix in { ".luau", ".server.luau", ".client.luau" } do
		if FILES[path .. "/" .. name .. suffix] then
			return path .. "/" .. name .. suffix
		end
	end
	return nil
end
PathMeta.__index = function(p, key)
	local path = rawget(p, "__path")
	if key == "Parent" then
		local parent = string.match(path, "^(.*)/[^/]+$")
		if FILES[path] and string.match(path, "/init%.luau$") then
			parent = string.match(parent, "^(.*)/[^/]+$")
		end
		return pathProxy(parent)
	elseif key == "Name" then
		return (string.gsub(string.match(path, "([^/]+)$"), "%.luau$", ""))
	elseif key == "WaitForChild" or key == "FindFirstChild" then
		return function(self, name)
			local child = childPath(rawget(self, "__path"), name)
			return child and pathProxy(child)
		end
	elseif key == "IsA" then
		return function(_, class)
			return class == "ModuleScript" or class == "Instance"
		end
	elseif key == "GetChildren" then
		return function()
			local out = {}
			local prefix = path .. "/"
			for f in FILES do
				if string.sub(f, 1, #prefix) == prefix and not string.find(f, "/", #prefix + 1, true) then
					table.insert(out, pathProxy(f))
				end
			end
			return out
		end
	end
	local child = childPath(path, key)
	if not child then
		error("no child '" .. tostring(key) .. "' under " .. path, 2)
	end
	return pathProxy(child)
end

local STUBS = {}
local cache = {}
local env

local function requireModule(target)
	local path = type(target) == "table" and rawget(target, "__path")
	assert(path, "require of a non-module: " .. tostring(target))
	local scriptPath = path
	if DIRS[path] then
		path = path .. "/init.luau"
	end
	if cache[path] ~= nil then
		return cache[path]
	end
	for suffix, stub in STUBS do
		if string.sub(path, -#suffix) == suffix then
			cache[path] = stub
			return stub
		end
	end
	local source = assert(FILES[path], "no module " .. path)
	local moduleEnv = setmetatable({ script = pathProxy(scriptPath), require = requireModule }, { __index = env })
	local chunk = luau.load(source, { debugName = path, environment = moduleEnv, injectGlobals = false, codegenEnabled = false })
	local result = chunk()
	cache[path] = result
	return result
end

-- records of what the game sent / awarded
local record = { events = {}, notify = {}, awards = {}, lore = {}, finished = 0, objectives = {}, lines = {} }

local function recorder(name)
	return {
		FireAllClients = function(_, ...)
			table.insert(record.events, { name, ... })
			if name == "Subtitle" then
				local line = ...
				table.insert(record.lines, line.text)
			end
		end,
		FireClient = function(_, player, ...)
			table.insert(record.events, { name, ... })
			if name == "Notify" then
				table.insert(record.notify, (...))
			end
			if name == "Subtitle" then
				local line = ...
				table.insert(record.lines, line.text)
			end
		end,
		OnServerEvent = newSignal(),
	}
end
STUBS["Shared/Net.luau"] = {
	Event = function(name)
		return recorder(name)
	end,
	Function = function(name)
		return { Name = name }
	end,
}
local sessionState = {}
STUBS["Shared/SessionState.luau"] = {
	Get = function(key)
		return sessionState[key]
	end,
	Set = function(key, value)
		sessionState[key] = value
		if key == "Objective" and value then
			table.insert(record.objectives, value)
		end
	end,
	Observe = function() end,
}

local profiles = {}
local function profileFor(player)
	profiles[player] = profiles[player] or {
		Data = {
			signalMarks = 0,
			progress = { completedChapters = {} },
			secrets = { logs = {}, photos = {}, forecastsBroken = {}, solved = {} },
			storyChoices = {},
			equipped = { radioSkin = "radio_rust" },
			achievements = {},
		},
	}
	return profiles[player]
end
STUBS["Services/DataService.luau"] = {
	Get = function(player)
		return profileFor(player)
	end,
	WaitFor = function(player)
		return profileFor(player)
	end,
	Mutate = function(player, fn)
		fn(profileFor(player).Data)
		return true
	end,
	Grant = function(player, amount)
		profileFor(player).Data.signalMarks += amount
		return true
	end,
	SaveNow = function()
		return true
	end,
}
local function permissive(name, extra)
	return setmetatable(extra or {}, {
		__index = function(_, key)
			return function() end
		end,
	})
end
STUBS["Services/AnalyticsTracker.luau"] = permissive("AnalyticsTracker")
STUBS["Services/BadgeTracker.luau"] = permissive("BadgeTracker", {
	Award = function(player, key)
		table.insert(record.awards, "badge:" .. key)
	end,
})
STUBS["Services/AchievementService.luau"] = permissive("AchievementService", {
	Award = function(player, id)
		table.insert(record.awards, "ach:" .. id)
	end,
	Has = function()
		return false
	end,
})
STUBS["Services/LoreService.luau"] = permissive("LoreService", {
	Unlock = function(player, id)
		table.insert(record.lore, id)
		profileFor(player).Data.secrets.logs[id] = 1
		return true
	end,
	UnlockAll = function(list, id)
		for _, player in list do
			table.insert(record.lore, id)
			profileFor(player).Data.secrets.logs[id] = 1
		end
	end,
})
local creatures = 0
STUBS["Services/CreatureService.luau"] = permissive("CreatureService", {
	Spotted = {},
	Spawn = function()
		creatures += 1
	end,
	Despawn = function()
		creatures = 0
	end,
	Count = function()
		return creatures
	end,
	Get = function()
		return nil
	end,
	IsAIEnabled = function()
		return true
	end,
	IsChasingNear = function()
		return false
	end,
})
STUBS["Services/HealthService.luau"] = permissive("HealthService", { SessionStats = { eliminated = {} } })
STUBS["Services/InventoryService.luau"] = permissive("InventoryService")
STUBS["Services/NoiseService.luau"] = permissive("NoiseService")
STUBS["Services/DirectorService.luau"] = permissive("DirectorService", {
	AreaOf = function()
		return nil
	end,
	NearTagged = function()
		return false
	end,
})
STUBS["Services/LeaderboardService.luau"] = permissive("LeaderboardService")
STUBS["Services/ReferralService.luau"] = permissive("ReferralService")
local decisionChoices = {} -- [decisionId] = option index the simulated team picks
STUBS["Services/DecisionService.luau"] = permissive("DecisionService", {
	Ask = function(decision, voters)
		local choice = decisionChoices[decision.id] or (if string.sub(decision.id, 1, 8) == "sv_risk_" then 2 else nil) or decision.default or 1
		assert(decision.options[choice], "decision " .. decision.id .. " has no option " .. choice)
		taskShim.delay(3, function()
			for _, player in voters() do
				profileFor(player).Data.storyChoices[decision.id] = choice
			end
			decision.onDecided(choice)
		end)
	end,
	IsOpen = function()
		return false
	end,
})

local SERVICES = {
	CollectionService = CollectionServiceShim,
	Players = PlayersShim,
	Lighting = wrap(realLighting),
	MaterialService = wrap(dataModel:GetService("MaterialService")),
	Workspace = wrap(realWorkspace),
	ReplicatedStorage = pathProxy(ROOT .. "/ReplicatedStorage"),
	ServerStorage = wrap(roblox.Instance.new("Folder")),
	TweenService = {
		Create = function(_, object, _info, goals)
			return {
				Play = function()
					for key, value in goals do
						object[key] = value
					end
				end,
				Cancel = function() end,
				Completed = newSignal(),
			}
		end,
	},
	RunService = { Heartbeat = newSignal(), Stepped = newSignal(), IsStudio = function()
		return false
	end, IsServer = function()
		return true
	end },
	HttpService = { JSONEncode = function()
		return "{}"
	end, JSONDecode = function()
		return {}
	end },
}
local fakeGame = {
	GetService = function(_, name)
		return assert(SERVICES[name], "unstubbed service " .. name)
	end,
	PlaceId = 0,
	JobId = "smoke",
}

local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed)
	return setmetatable({ state = (seed or 1) % 2147483647 }, RandomShim)
end
function RandomShim:NextNumber(min, max)
	self.state = (self.state * 48271) % 2147483647
	return (min or 0) + ((max or 1) - (min or 0)) * (self.state / 2147483647)
end
function RandomShim:NextInteger(min, max)
	return math.floor(self:NextNumber(min, max + 1))
end

local osShim = setmetatable({ clock = function()
	return now
end, time = function()
	return 1700000000 + math.floor(now)
end }, { __index = os })

env = setmetatable({
	setmetatable = setmetatable, getmetatable = getmetatable, pairs = pairs, ipairs = ipairs, next = next,
	select = select, type = type, tostring = tostring, tonumber = tonumber, pcall = pcall, xpcall = xpcall,
	error = error, assert = assert, rawget = rawget, rawset = rawset, rawequal = rawequal, rawlen = rawlen,
	unpack = table.unpack, print = print, math = math, string = string, table = table, os = osShim,
	coroutine = coroutine, utf8 = utf8, bit32 = bit32, buffer = buffer, debug = debug,
	game = fakeGame,
	workspace = wrap(realWorkspace),
	Instance = { new = function(className, parent)
		local real = roblox.Instance.new(className)
		if parent then
			real.Parent = unwrap(parent)
		end
		return wrap(real)
	end },
	task = taskShim,
	Random = RandomShim,
	typeof = function(v)
		if isProxy(v) then
			return "Instance"
		end
		if type(v) == "table" and v.UserId then
			return "Instance"
		end
		return typeof(v)
	end,
	warn = function(...)
		local text = table.concat(table.pack(...), " ")
		table.insert(errors, "warn: " .. text)
	end,
	Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	Enum = roblox.Enum, UDim = roblox.UDim, UDim2 = roblox.UDim2, NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, Font = roblox.Font,
	TweenInfo = { new = function(...)
		return { ... }
	end },
}, { __index = _G })

---------------------------------------------------------------------------
-- Test helpers
---------------------------------------------------------------------------
local SERVER = pathProxy(ROOT .. "/ServerScriptService/Server")
local function find(tag, filter)
	for _, d in dataModel:GetDescendants() do
		if d:HasTag(tag) and (not filter or filter(d)) then
			return d
		end
	end
	return nil
end
local function interactable(id, attr, value)
	return find("FZ_Interactable", function(d)
		return d:GetAttribute("InteractId") == id and (attr == nil or d:GetAttribute(attr) == value)
	end)
end
local function moveTo(player, position)
	player.root.CFrame = roblox.CFrame.new(position + roblox.Vector3.new(0, 3, 0))
end
local function moveAll(position)
	for i, player in players do
		moveTo(player, position + roblox.Vector3.new(i, 0, 0))
	end
end
-- walk to an interactable and trigger its prompt (exactly the server path a click takes)
local function use(player, id, attr, value)
	local target = interactable(id, attr, value)
	assert(target, "no interactable " .. id .. (if attr then " " .. attr .. "=" .. tostring(value) else ""))
	local position = if target:IsA("BasePart") then target.CFrame.Position else target:GetPivot().Position
	moveTo(player, position + roblox.Vector3.new(1.5, 0, 0))
	local prompt = target:FindFirstChild("FZ_Prompt")
	assert(prompt, "interactable " .. id .. " has no prompt")
	advance(0.6) -- rate limiter
	signalFor(prompt, "Triggered"):Fire(player)
end
local function doorLocked(attr)
	local panel = find("FZ_Door", function(d)
		return d:GetAttribute(attr) ~= nil
	end)
	assert(panel, "no door with attribute " .. attr)
	return panel:GetAttribute("Locked") == true, panel
end
-- lets a running forecast run out (deadlines scale with the team size)
local function letForecastHappen()
	local waited = 0
	while sessionState.Forecast ~= nil and waited < 90 do
		advance(1)
		waited += 1
	end
	advance(1)
end
local function has(list, value)
	return table.find(list, value) ~= nil
end

---------------------------------------------------------------------------
-- World setup (once per scenario)
---------------------------------------------------------------------------
local function setup(builderName, playerCount)
	for _, child in realWorkspace:GetChildren() do
		child:Destroy()
	end
	table.clear(players)
	table.clear(queue)
	table.clear(errors)
	table.clear(sessionState)
	table.clear(decisionChoices)
	table.clear(profiles)
	for key in record do
		if type(record[key]) == "table" then
			table.clear(record[key])
		end
	end
	record.finished = 0
	creatures = 0
	cache = {}
	addedSignals, removedSignals = {}, {}
	now = 0
	local builder = requireModule(SERVER.Map[builderName])
	builder.SkipTerrain = true
	builder.Build()
	-- services in Main.server order (the ones that are real here)
	for _, name in { "InteractionService", "DoorService", "PowerService" } do
		local service = requireModule(SERVER.Services[name])
		if name == "PowerService" then
			service.Start(requireModule(SERVER.Services.DoorService))
		else
			service.Start()
		end
	end
	requireModule(SERVER.Services.DoorService).CloseAll()
	for i = 1, playerCount do
		makePlayer(i)
	end
	return {
		setCheckpoint = function(id)
			sessionState.Checkpoint = id
		end,
		finish = function()
			record.finished += 1
		end,
		playersInGame = function()
			return table.clone(players)
		end,
		leave = function() end,
	}
end

local function startChapter(moduleName, ctx)
	local chapter = requireModule(SERVER.Chapters[moduleName])
	chapter.Init(ctx)
	chapter.Begin({})
	for _, player in players do
		if chapter.OnPlayerEntered then
			taskShim.spawn(chapter.OnPlayerEntered, player, true)
		end
	end
	return chapter
end

---------------------------------------------------------------------------
-- Scenarios
---------------------------------------------------------------------------
local SCENARIOS = {}
local order = {}
local function scenario(name, fn)
	SCENARIOS[name] = fn
	table.insert(order, name)
end

-- MapService: baked relay07 in the workspace, stored maps in ServerStorage (tags stashed),
-- switching back and forth must never leave tags of another map in the world.
scenario("map_switching", function()
	setup("RelayStation07", 1)
	local relay = realWorkspace:FindFirstChild("FZ_RelayStation07")
	relay.Name = "FZ_Map"
	local storage = unwrap(SERVICES.ServerStorage)
	local maps = roblox.Instance.new("Folder")
	maps.Name = "Maps"
	maps.Parent = storage
	for _, entry in { { "Dam03", "Dam03" }, { "Chapel", "Church" }, { "Mine", "Mine" } } do
		local builder = requireModule(SERVER.Map[entry[1]])
		builder.SkipTerrain = true
		local model = unwrap(builder.Build())
		model.Name = entry[2]
		model.Parent = maps
	end
	local function count(tag)
		return #CollectionServiceShim:GetTagged(tag)
	end
	local MapService = requireModule(SERVER.Services.MapService)
	MapService.Start() -- stashes stored tags, loads relay07 (baked)
	local relayDoors = count("FZ_Door")
	assert(find("FZ_Checkpoint", function(d)
		return d:GetAttribute("CheckpointId") == "C1_START"
	end), "relay07 checkpoint missing")
	assert(not find("FZ_Checkpoint", function(d)
		return d:GetAttribute("CheckpointId") == "C2_START"
	end), "a stored map leaked its tags")
	for _, id in { "dam03", "church", "mine", "relay07", "dam03" } do
		assert(MapService.Load(id), "load " .. id)
		local expected = ({ dam03 = "C2_START", church = "C3_START", mine = "C4_START", relay07 = "C1_START" })[id]
		local checkpoints = {}
		for _, cp in CollectionServiceShim:GetTagged("FZ_Checkpoint") do
			checkpoints[unwrap(cp):GetAttribute("CheckpointId")] = true
		end
		assert(checkpoints[expected], id .. ": own checkpoint missing")
		for _, other in { "C1_START", "C2_START", "C3_START", "C4_START" } do
			if other ~= expected then
				assert(not checkpoints[other], id .. ": leaked checkpoint " .. other)
			end
		end
		assert(MapService.CurrentId() == id, "current id")
	end
	assert(MapService.Load("relay07"))
	assert(count("FZ_Door") == relayDoors, "relay07 doors changed after a round trip")
end)

-- Photo textures: with ids filled, every material gets a variant + base material override.
scenario("textures", function()
	setup("Mine", 1)
	local assets = requireModule(pathProxy(ROOT .. "/ReplicatedStorage/Shared/Assets.luau"))
	local textures = requireModule(pathProxy(ROOT .. "/ReplicatedStorage/Shared/Textures.luau"))
	local expected, overrides = 0, 0
	for name, spec in textures.Variants do
		expected += 1
		if spec.override then
			overrides += 1
		end
		for _, map in spec.maps do
			assets.Textures[name][map] = "rbxassetid://" .. (100 + expected)
		end
	end
	for kind in assets.Grime do
		assets.Grime[kind] = "rbxassetid://9"
	end
	requireModule(SERVER.Services.TextureService).Start()
	local ms = dataModel:GetService("MaterialService")
	assert(#ms:GetChildren() == expected, "variants: " .. #ms:GetChildren())
	assert(ms.ConcreteName == "SR_Concrete" and ms.RockName == "SR_Rock" and ms.MarbleName == "SR_Marble", "overrides missing")
	assert(ms.ConcreteName ~= "SR_DamConcrete", "a surface variant must not override its base")
	-- the mine got its surface variants and grime decals, and they received their image
	local timber, grime = 0, 0
	for _, d in realWorkspace:GetDescendants() do
		if d:IsA("BasePart") and d.MaterialVariant == "SR_Timber" then
			timber += 1
		elseif d:IsA("Decal") and d:HasTag("FZ_Grime") then
			assert(d.Texture == "rbxassetid://9", "grime decal without image")
			grime += 1
		end
	end
	assert(timber > 20 and grime > 5, string.format("timber %d, grime %d", timber, grime))
	for name in textures.Variants do
		for map in pairs(assets.Textures[name]) do
			assets.Textures[name][map] = ""
		end
	end
	for kind in assets.Grime do
		assets.Grime[kind] = ""
	end
end)

-- Chapter 1 (regression), as a returning team after the "Answer" ending (New Game+)
scenario("ch1_full", function()
	local ctx = setup("RelayStation07", 2)
	decisionChoices.c1_answer = 2
	profileFor(players[1]).Data.storyChoices.c4_ending = 1
	local chapter = startChapter("Chapter1", ctx)
	advance(16)
	assert(has(record.lines, "RADIO_C1_RETURN"), "New Game+ greeting missing")
	use(players[1], "c1_fax")
	advance(30)
	use(players[1], "c1_terminal")
	use(players[1], "c1_power", "System", "cameras")
	use(players[1], "c1_power", "System", "halls")
	advance(10)
	assert(sessionState.Objective == "OBJECTIVE_FIND_FUSES", "fuses objective: " .. tostring(sessionState.Objective))
	for i = 1, 3 do
		use(players[1], "c1_fuse")
		if i == 2 then
			advance(2)
			use(players[2], "c1_breaker_a")
		end
	end
	use(players[1], "c1_relay_b")
	advance(14)
	if sessionState.Forecast == "FORECAST_GENERATOR_E" then
		use(players[2], "generator", "GeneratorId", 1)
	end
	use(players[1], "c1_core")
	advance(10)
	use(players[1], "c1_antenna")
	advance(16)
	assert(record.finished == 1, "chapter 1 did not finish")
	assert(profiles[players[1]].Data.secrets.forecastsBroken["kind:power"], "forecast kind not saved")
	chapter.Stop()
end)

-- Chapter 2: every forecast comes true, the team trusts the unknown voice.
scenario("ch2_kept_unknown", function()
	local ctx = setup("Dam03", 2)
	decisionChoices.c2_trust = 1
	local chapter = startChapter("Chapter2", ctx)
	advance(15)
	assert(sessionState.Objective == "OBJ_C2_CREW", "objective after arrival: " .. tostring(sessionState.Objective))
	moveAll(roblox.Vector3.new(-70, 0, 60))
	advance(2)
	assert(sessionState.Objective == "OBJ_C2_LOG", "crew zone did not fire")
	use(players[1], "lore", "LogId", "c2_keeper_log")
	advance(12)
	assert(sessionState.Forecast == "FORECAST_CANTEEN", "door forecast missing")
	letForecastHappen() -- kept
	assert(doorLocked("Canteen"), "canteen doors should be locked")
	advance(30)
	assert(not doorLocked("Canteen"), "canteen doors should unlock again")
	assert(sessionState.Objective == "OBJ_C2_TURBINES", "turbines objective: " .. tostring(sessionState.Objective))
	use(players[1], "generator", "GeneratorId", 1)
	advance(5)
	assert(sessionState.Forecast == "FORECAST_FLOOD", "flood forecast missing")
	letForecastHappen() -- kept
	assert(doorLocked("Gallery"), "gallery should be closed after the flood")
	use(players[2], "generator", "GeneratorId", 2)
	advance(3)
	assert(sessionState.Objective == "OBJ_C2_CREST_RAMP", "crest (ramp) objective: " .. tostring(sessionState.Objective))
	moveAll(roblox.Vector3.new(132, 44, -10))
	advance(1)
	advance(22) -- voices + decision (3 s)
	assert(not doorLocked("YardGate"), "trusting the unknown voice opens the yard gate")
	assert(sessionState.Objective == "OBJ_C2_UPLINK", "uplink objective: " .. tostring(sessionState.Objective))
	use(players[1], "c2_uplink")
	moveAll(roblox.Vector3.new(6, 44, -34))
	advance(30)
	advance(25)
	assert(record.finished == 1, "chapter 2 did not finish")
	assert(profiles[players[1]].Data.progress.completedChapters.ch2, "ch2 not saved")
	assert(has(record.awards, "badge:ch2_complete"), "badge missing")
	chapter.Stop()
end)

-- Chapter 2: every forecast broken, the team trusts the Relay (spillway task first).
scenario("ch2_broken_relay", function()
	local ctx = setup("Dam03", 1)
	decisionChoices.c2_trust = 2
	local chapter = startChapter("Chapter2", ctx)
	advance(15)
	moveAll(roblox.Vector3.new(-70, 0, 60))
	advance(2)
	use(players[1], "lore", "LogId", "c2_keeper_log")
	advance(12)
	use(players[1], "c2_override")
	assert(sessionState.Forecast == nil, "door forecast should be broken")
	assert(profiles[players[1]].Data.secrets.forecastsBroken["kind:door"], "door kind not saved")
	advance(7)
	use(players[1], "generator", "GeneratorId", 1)
	advance(5)
	use(players[1], "c2_valve")
	assert(not doorLocked("Gallery"), "gallery must stay open when the flood is broken")
	use(players[1], "generator", "GeneratorId", 2)
	advance(3)
	assert(sessionState.Objective == "OBJ_C2_CREST", "crest objective: " .. tostring(sessionState.Objective))
	moveAll(roblox.Vector3.new(132, 44, -10))
	advance(25)
	assert(sessionState.Objective == "OBJ_C2_SPILLWAY", "spillway objective: " .. tostring(sessionState.Objective))
	assert(doorLocked("YardGate"), "yard gate stays locked until the spillway is closed")
	use(players[1], "c2_spillway")
	assert(not doorLocked("YardGate"), "yard gate opens after the spillway")
	use(players[1], "c2_uplink")
	moveAll(roblox.Vector3.new(6, 44, -34))
	advance(60)
	assert(record.finished == 1, "chapter 2 did not finish")
	chapter.Stop()
end)

-- Chapter 3: tapes in a wrong order first (deck resets), then the right order.
scenario("ch3_order", function()
	local ctx = setup("Chapel", 2)
	decisionChoices.c3_recorder = 1
	local chapter = startChapter("Chapter3", ctx)
	advance(14)
	assert(sessionState.Objective == "OBJ_C3_CHAPEL", "chapel objective: " .. tostring(sessionState.Objective))
	moveAll(roblox.Vector3.new(0, 0, 10))
	advance(1)
	use(players[1], "c3_altar")
	assert(not doorLocked("Hidden"), "the altar must open the hidden passage")
	moveAll(roblox.Vector3.new(48, 0, -20))
	advance(1)
	advance(9)
	assert(sessionState.Objective == "OBJ_C3_TAPES", "tapes objective: " .. tostring(sessionState.Objective))
	use(players[2], "c3_breaker", "Sector", "ARCHIVE") -- breaks the power forecast
	-- which recorder holds which fragment? listen to all and remember (like players would)
	local fragmentAt = {}
	for slot = 1, 5 do
		use(players[1], "c3_tape", "TapeSlot", slot)
		advance(2)
		fragmentAt[players[1]:GetAttribute("FZ_Tape")] = slot
	end
	-- wrong tape on purpose: the deck resets
	use(players[1], "c3_tape", "TapeSlot", fragmentAt[3])
	use(players[1], "c3_deck")
	advance(1)
	assert(has(record.lines, "RADIO_C3_TAPE_WRONG"), "wrong tape not rejected")
	for fragment = 1, 5 do
		use(players[1], "c3_tape", "TapeSlot", fragmentAt[fragment])
		use(players[1], "c3_deck")
		advance(1)
		if fragment == 2 then
			advance(5)
			assert(sessionState.Forecast == "FORECAST_ARCHIVE_GATE", "gate forecast missing")
			use(players[2], "c3_winch")
		end
	end
	if doorLocked("Sealed") then
		error("sealed door still locked; objective=" .. tostring(sessionState.Objective) .. " lines=" .. table.concat(record.lines, ",", math.max(1, #record.lines - 8)) .. " notify=" .. table.concat(record.notify, ","))
	end
	moveAll(roblox.Vector3.new(85, 0, -75))
	advance(2)
	assert(sessionState.Objective == "OBJ_C3_RECORDER", "recorder objective: " .. tostring(sessionState.Objective))
	use(players[1], "c3_relay_recorder")
	advance(36)
	assert(sessionState.Objective == "OBJ_C3_BELL", "bell objective: " .. tostring(sessionState.Objective))
	use(players[1], "c3_bell")
	advance(25)
	assert(record.finished == 1, "chapter 3 did not finish")
	assert(has(record.awards, "ach:run_0007"), "run 0007 achievement missing")
	assert(profiles[players[1]].Data.storyChoices.c3_recorder == 1, "recorder choice not saved")
	chapter.Stop()
end)

-- Chapter 4: forecasts kept (blast door opens only in 2009), team stays silent.
scenario("ch4_kept_silence", function()
	local ctx = setup("Mine", 2)
	decisionChoices.c4_ending = 2
	local chapter = startChapter("Chapter4", ctx)
	advance(16)
	assert(sessionState.Objective == "OBJ_C4_GATE", "gate objective: " .. tostring(sessionState.Objective))
	use(players[1], "c4_winch")
	assert(not doorLocked("MineGate"), "the winch must open the mine gate")
	moveAll(roblox.Vector3.new(0, 0, -130))
	advance(7)
	assert(sessionState.Forecast == "FORECAST_CAGE", "cage forecast missing")
	letForecastHappen() -- kept
	assert(doorLocked("LoopDoor"), "the crash must jam the loop")
	advance(21)
	assert(sessionState.Forecast == "FORECAST_MINE_FLOOD", "flood forecast missing")
	letForecastHappen()
	-- wait for a 2009 layer and walk through the old passage
	local waited = 0
	while sessionState.TimeLayer ~= "2009" and waited < 60 do
		advance(1)
		waited += 1
	end
	assert(sessionState.TimeLayer == "2009", "no 2009 layer within 60 s")
	local rubble = find("FZ_Layer", function(d)
		return d:GetAttribute("Layer") == "now"
	end)
	assert(rubble and rubble.CanCollide == false, "rubble must be passable in 2009")
	moveAll(roblox.Vector3.new(0, 0, -240))
	advance(4)
	assert(sessionState.Forecast == "FORECAST_TRANSFORMER", "power forecast missing")
	letForecastHappen() -- kept
	advance(7)
	assert(sessionState.Forecast == "FORECAST_BLAST", "blast forecast missing")
	letForecastHappen() -- kept
	assert(sessionState.Objective == "OBJ_C4_BLAST_WAIT", "wait objective: " .. tostring(sessionState.Objective))
	waited = 0
	while doorLocked("BlastDoor") and waited < 70 do
		advance(1)
		waited += 1
	end
	assert(not doorLocked("BlastDoor"), "the blast door must open in the 2009 layer")
	moveAll(roblox.Vector3.new(0, 0, -288))
	use(players[1], "c4_core")
	moveAll(roblox.Vector3.new(0, 0, -288))
	advance(25)
	assert(sessionState.Ending == "silence", "silence ending: " .. tostring(sessionState.Ending))
	advance(32)
	assert(record.finished == 1, "chapter 4 did not finish")
	assert(has(record.awards, "ach:ending_silence"), "ending achievement missing")
	chapter.Stop()
	assert(realLighting.ClockTime < 6, "lighting must be reset to the mine preset after the ending")
end)

-- Chapter 4: all forecasts broken, secret ending unlocked (6 ghost logs + every kind).
scenario("ch4_counter", function()
	local ctx = setup("Mine", 1)
	decisionChoices.c4_ending = 3
	local data = profileFor(players[1]).Data
	for _, id in { "log_okafor", "log_venn", "log_ehle", "log_0006", "log_kessler", "log_marek" } do
		data.secrets.logs[id] = 1
	end
	data.secrets.forecastsBroken["kind:water"] = true
	data.secrets.forecastsBroken["kind:door"] = true
	local chapter = startChapter("Chapter4", ctx)
	advance(16)
	use(players[1], "c4_winch")
	moveAll(roblox.Vector3.new(0, 0, -130))
	advance(7)
	use(players[1], "c4_brake")
	assert(not doorLocked("LoopDoor"), "loop must stay open when the cage forecast is broken")
	advance(21)
	use(players[1], "c4_pump")
	-- take the loop instead of waiting for 2009
	moveAll(roblox.Vector3.new(-61, 0, -200))
	advance(2)
	moveAll(roblox.Vector3.new(0, 0, -240))
	advance(4)
	use(players[1], "c4_breaker")
	advance(7)
	use(players[1], "c4_override")
	assert(not doorLocked("BlastDoor"), "override must open the blast door")
	assert(data.secrets.forecastsBroken["kind:power"] and data.secrets.forecastsBroken["kind:machine"], "kinds not saved")
	use(players[1], "c4_core")
	advance(25)
	assert(sessionState.Ending == "counter", "counter ending: " .. tostring(sessionState.Ending))
	advance(32)
	assert(record.finished == 1, "chapter 4 did not finish")
	assert(has(record.awards, "badge:ending_counter"), "secret badge missing")
	chapter.Stop()
end)

-- Survival on the dam: three shifts with every task type, then extraction at the van.
local SV_MAPS = {
	dam03 = { builder = "Dam03", start = "CP_SV_DAM", relay = "dam_relay", relayObjective = "SV_OBJ_DAM_RELAY", stations = { "dam_station_1", "dam_station_2", "dam_station_3" }, uplink = "c2_uplink" },
	relay07 = { builder = "RelayStation07", start = "C1_CONTROL", relay = "c1_relay_b", relayObjective = "OBJECTIVE_RELAY_B", stations = { "c1_terminal", "c1_breaker_a", "c1_core" }, uplink = "c1_core" },
	church = { builder = "Chapel", start = "CP_SV_CHURCH", relay = "church_relay", relayObjective = "SV_OBJ_CHURCH_RELAY", stations = { "church_station_1", "church_station_2", "church_station_3" }, uplink = "c3_deck" },
	mine = { builder = "Mine", start = "CP_SV_MINE", relay = "mine_relay", relayObjective = "SV_OBJ_MINE_RELAY", stations = { "mine_station_1", "mine_station_2", "mine_station_3" }, uplink = "c4_core" },
}
local function survivalRun(mapId)
	local m = SV_MAPS[mapId]
	local ctx = setup(m.builder, 2)
	local survival = requireModule(SERVER.Modes.Survival)
	survival.Init(ctx)
	assert(survival.StartCheckpointFor({ map = mapId }) == m.start, "start checkpoint")
	survival.Begin({ map = mapId, id = "sv_" .. mapId })
	for _, player in players do
		survival.OnPlayerEntered(player, true)
	end
	advance(11)
	local done = 0
	for _ = 1, 6 do
		local objective = sessionState.Objective
		if objective == "OBJECTIVE_FIND_FUSES" then
			for _ = 1, 3 do -- two players: three fuses (Config.Team.Fuses)
				local fuse = interactable("sv_fuse")
				assert(fuse, "fuse missing")
				use(players[1], "sv_fuse")
			end
			assert(sessionState.Objective == m.relayObjective, "fuse delivery objective: " .. tostring(sessionState.Objective))
			use(players[1], m.relay)
		elseif objective == "SV_TASK_GENERATORS" then
			use(players[1], "generator", "GeneratorId", 1)
			use(players[1], "generator", "GeneratorId", 2)
		elseif objective == "SV_TASK_STATIONS" then
			for _, id in m.stations do
				use(players[1], id)
			end
		elseif objective == "SV_TASK_KEYS" then
			-- first alone and too slow (the lock resets), then together
			use(players[1], "sync_key", "KeyIndex", 1)
			advance(4)
			assert(has(record.notify, "SV_KEY_MISSED"), "lock did not reset")
			use(players[1], "sync_key", "KeyIndex", 1)
			use(players[2], "sync_key", "KeyIndex", 2)
		elseif objective == "SV_TASK_UPLINK" then
			local uplink = interactable(m.uplink)
			moveAll(uplink.CFrame.Position)
			advance(42)
			if sessionState.SvPhase ~= "break" then
				error(string.format("uplink stuck: objective=%s params=%s phase=%s", tostring(sessionState.Objective), tostring(sessionState.ObjectiveParams), tostring(sessionState.SvPhase)))
			end
		else
			error("unexpected survival objective " .. tostring(objective))
		end
		assert(sessionState.SvPhase == "break", "task did not complete: " .. tostring(objective))
		done += 1
		if done == 3 then
			break
		end
		moveAll(roblox.Vector3.new(0, 0, 300))
		local waited = 0
		while sessionState.SvPhase ~= "task" and waited < 40 do
			advance(1)
			waited += 1
		end
	end
	assert(done == 3, "three shifts expected")
	survival.Stop()
end
scenario("sv_dam03", function()
	survivalRun("dam03")
end)
scenario("sv_relay07", function()
	survivalRun("relay07")
end)
scenario("sv_church", function()
	survivalRun("church")
end)
scenario("sv_mine", function()
	survivalRun("mine")
end)

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------
-- survival picks tasks/events at random: replay it with several seeds
for seed = 1, 12 do
	scenario("sv_dam03_seed" .. seed, function()
		math.randomseed(seed)
		SCENARIOS[({ "sv_dam03", "sv_relay07", "sv_church", "sv_mine" })[seed % 4 + 1]]()
	end)
end

local only = process.args[1]
local failed = 0
for _, name in order do
	if not only or only == name then
		local ok, err = pcall(SCENARIOS[name])
		local problems = table.clone(errors)
		if ok and #problems == 0 then
			print(string.format("ok    %s  (%.0f s virtual, %d lines, %d objectives)", name, now, #record.lines, #record.objectives))
		else
			failed += 1
			print("FAIL  " .. name)
			if not ok then
				print("      " .. tostring(err))
			end
			for i, problem in problems do
				if i > 6 then
					print("      ...")
					break
				end
				print("      " .. (string.split(problem, "\nstack traceback")[1]))
			end
		end
	end
end
print(if failed == 0 then "server smoke test: all passed" else string.format("server smoke test: %d failed", failed))
if failed > 0 then
	process.exit(1)
end
