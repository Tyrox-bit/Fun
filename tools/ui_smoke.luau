-- Headless UI smoke test (Lune). Builds every menu screen and the HUD against Lune's Roblox
-- reflection database, so a misspelled property, a wrong enum or a bad value type fails here
-- instead of in Studio. Events are faked (they can be fired to simulate clicks), services and
-- network are stubbed. This checks construction + interaction code paths, NOT the look.
--
-- Usage: lune run tools/ui_smoke.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = "src"
local failures = 0

---------------------------------------------------------------------------
-- Fake signals
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
			fn(...)
		end
	end
	return signal
end

---------------------------------------------------------------------------
-- Instance proxies: real Lune instances (property validation) + fake events
---------------------------------------------------------------------------
local EVENTS = {
	Activated = true, MouseEnter = true, MouseLeave = true, MouseButton1Down = true, MouseButton1Up = true,
	MouseButton1Click = true, MouseButton2Click = true, SelectionGained = true, SelectionLost = true,
	FocusLost = true, Focused = true, InputBegan = true, InputEnded = true, InputChanged = true,
	Changed = true, AncestryChanged = true, Destroying = true, ChildAdded = true, ChildRemoved = true,
	DescendantAdded = true, DescendantRemoving = true, TouchTap = true, Triggered = true, ReturnPressedFromOnScreenKeyboard = true,
}

local realOf = setmetatable({}, { __mode = "k" }) -- proxy -> real
local proxyOf = {} -- real -> proxy
local signals = {} -- real -> key -> signal

local wrap, unwrap

local function signalFor(real, key)
	signals[real] = signals[real] or {}
	signals[real][key] = signals[real][key] or newSignal()
	return signals[real][key]
end

local Proxy = {}
local function isProxy(v)
	return type(v) == "table" and realOf[v] ~= nil
end

unwrap = function(v)
	if isProxy(v) then
		return realOf[v]
	end
	return v
end

local function wrapAll(...)
	local out = table.pack(...)
	for i = 1, out.n do
		local v = out[i]
		if typeof(v) == "Instance" then
			out[i] = wrap(v)
		elseif type(v) == "table" then
			for k, item in v do
				if typeof(item) == "Instance" then
					v[k] = wrap(item)
				end
			end
		end
	end
	return table.unpack(out, 1, out.n)
end

local INTERCEPT = {}
function INTERCEPT.GetPropertyChangedSignal(real, prop)
	return signalFor(real, "prop:" .. prop)
end
function INTERCEPT.GetAttributeChangedSignal(real, name)
	return signalFor(real, "attr:" .. name)
end
function INTERCEPT.WaitForChild(real, name)
	local child = real:FindFirstChild(name)
	assert(child, "WaitForChild would hang forever: " .. real:GetFullName() .. "." .. name)
	return child
end
function INTERCEPT.GetServerTimeNow()
	return os.clock()
end
-- Destroy fires Destroying on the instance and its descendants first (as the engine does),
-- so cleanup code (e.g. localization bindings) runs in the test too.
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
function INTERCEPT.TweenSize() end
function INTERCEPT.TweenPosition() end

-- simulated screen (set FZ_VIEWPORT=844x390 to test a phone in landscape)
local viewportX, viewportY = string.match(process.env.FZ_VIEWPORT or "1280x720", "(%d+)x(%d+)")
local VIEWPORT = roblox.Vector2.new(tonumber(viewportX), tonumber(viewportY))

Proxy.__index = function(p, key)
	local real = realOf[p]
	if key == "ViewportSize" and real.ClassName == "Camera" then
		return VIEWPORT
	end
	if EVENTS[key] then
		return signalFor(real, key)
	end
	if INTERCEPT[key] then
		return function(_, ...)
			return wrapAll(INTERCEPT[key](real, table.unpack(table.pack(...))))
		end
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
	local ok, err = pcall(function()
		real[key] = unwrap(value)
	end)
	if not ok then
		error(string.format("set %s.%s = %s: %s", real.ClassName, tostring(key), tostring(value), tostring(err)), 2)
	end
	local s = signals[real] and signals[real]["prop:" .. key]
	if s then
		s:Fire()
	end
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

local InstanceShim = {
	new = function(className, parent)
		local real = roblox.Instance.new(className)
		if parent then
			real.Parent = unwrap(parent)
		end
		return wrap(real)
	end,
}

---------------------------------------------------------------------------
-- Module paths (Rojo layout) and require
---------------------------------------------------------------------------
-- Lune's fs calls may yield, which is not allowed inside metamethods: index the tree up front.
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
local function listDir(path)
	local out = {}
	local prefix = path .. "/"
	for p in DIRS do
		if string.sub(p, 1, #prefix) == prefix and not string.find(p, "/", #prefix + 1, true) then
			table.insert(out, string.sub(p, #prefix + 1))
		end
	end
	for p in FILES do
		if string.sub(p, 1, #prefix) == prefix and not string.find(p, "/", #prefix + 1, true) then
			table.insert(out, string.sub(p, #prefix + 1))
		end
	end
	return out
end

local PathMeta = {}
local function pathProxy(path)
	return setmetatable({ __path = path }, PathMeta)
end
local function childPath(path, name)
	if DIRS[path .. "/" .. name] then
		return path .. "/" .. name
	end
	for _, suffix in { ".luau", ".client.luau", ".server.luau" } do
		if FILES[path .. "/" .. name .. suffix] then
			return path .. "/" .. name .. suffix
		end
	end
	return nil
end
local function parentPath(path)
	return string.match(path, "^(.*)/[^/]+$")
end
PathMeta.__index = function(p, key)
	local path = rawget(p, "__path")
	if key == "Parent" then
		local parent = parentPath(path)
		if FILES[path] and string.match(path, "/init%.luau$") then
			parent = parentPath(parent)
		end
		return pathProxy(parent)
	elseif key == "Name" then
		return (string.gsub(string.match(path, "([^/]+)$"), "%.luau$", ""))
	elseif key == "WaitForChild" or key == "FindFirstChild" then
		return function(self, name)
			local child = childPath(rawget(self, "__path"), name)
			if key == "WaitForChild" then
				assert(child, "WaitForChild on module path would hang: " .. path .. "/" .. name)
			end
			return child and pathProxy(child)
		end
	elseif key == "IsA" then
		return function(_, class)
			return class == "ModuleScript" or class == "Instance"
		end
	elseif key == "GetChildren" then
		return function()
			local out = {}
			if DIRS[path] then
				for _, name in listDir(path) do
					if name ~= "init.luau" then
						table.insert(out, pathProxy(path .. "/" .. name))
					end
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

local STUB_MODULES = {} -- path suffix -> stub value
local cache = {}
local env

local function permissiveStub(name)
	return setmetatable({}, {
		__index = function(self, key)
			-- events: "...Changed", "Prompt...", "...Began/Ended/Added/Removing", "Action"
			if string.match(key, "Changed$") or string.match(key, "^Prompt") or string.match(key, "Began$") or string.match(key, "Ended$") or string.match(key, "Added$") or string.match(key, "Removing$") or key == "Action" or key == "Triggered" then
				local signal = newSignal()
				rawset(self, key, signal)
				return signal
			end
			return function()
				return nil
			end
		end,
		__tostring = function()
			return "Stub<" .. name .. ">"
		end,
	})
end

local function requireModule(target)
	local path = if type(target) == "table" and rawget(target, "__path") then rawget(target, "__path") else nil
	assert(path, "require of a non-module: " .. tostring(target))
	local scriptPath = path
	if DIRS[path] then
		path = path .. "/init.luau"
	end
	if cache[path] ~= nil then
		return cache[path]
	end
	for suffix, stub in STUB_MODULES do
		if string.sub(path, -#suffix) == suffix then
			cache[path] = stub
			return stub
		end
	end
	local source = assert(FILES[path], "no module file " .. path)
	local moduleEnv = setmetatable({ script = pathProxy(scriptPath), require = requireModule, game = env.game, task = env.task, Instance = env.Instance, typeof = env.typeof, workspace = env.workspace, warn = env.warn }, { __index = env })
	local chunk = luau.load(source, { debugName = path, environment = moduleEnv, injectGlobals = false, codegenEnabled = false })
	local result = chunk()
	cache[path] = result
	return result
end

---------------------------------------------------------------------------
-- Services and globals
---------------------------------------------------------------------------
local dataModel = roblox.Instance.new("DataModel")
local realWorkspace = dataModel:GetService("Workspace")
local realLighting = dataModel:GetService("Lighting")
local playerGui = roblox.Instance.new("Folder")
playerGui.Name = "PlayerGui"

local localPlayer = setmetatable({
	Name = "Tester",
	DisplayName = "Tester",
	UserId = 1,
	LocaleId = "de-de",
	GetAttribute = function()
		return nil
	end,
	SetAttribute = function() end,
	CharacterAdded = newSignal(),
	CharacterRemoving = newSignal(),
	Character = nil,
	GetAttributeChangedSignal = function()
		return newSignal()
	end,
	WaitForChild = function(_, name)
		if name == "PlayerGui" then
			return wrap(playerGui)
		end
		error("LocalPlayer:WaitForChild(" .. name .. ")")
	end,
	FindFirstChild = function(_, name)
		if name == "PlayerGui" then
			return wrap(playerGui)
		end
		return nil
	end,
}, {})

local SERVICES = {
	Players = { LocalPlayer = localPlayer, GetUserThumbnailAsync = function()
		return "rbxthumb://type=AvatarHeadShot&id=1&w=100&h=100"
	end, GetPlayers = function()
		return { localPlayer }
	end, PlayerAdded = newSignal(), PlayerRemoving = newSignal() },
	TweenService = {
		Create = function(_, object, info, goals)
			assert(typeof(info) == "TweenInfo" or type(info) == "table", "TweenService:Create needs TweenInfo")
			for key, value in goals do
				object[key] = value -- validates property + value type
			end
			return { Play = function() end, Cancel = function() end, Pause = function() end, Completed = newSignal() }
		end,
	},
	RunService = { RenderStepped = newSignal(), Heartbeat = newSignal(), Stepped = newSignal(), IsStudio = function()
		return false
	end, IsClient = function()
		return true
	end, IsServer = function()
		return false
	end, BindToRenderStep = function() end, UnbindFromRenderStep = function() end },
	UserInputService = setmetatable({ TouchEnabled = false, KeyboardEnabled = true, GamepadEnabled = false, MouseEnabled = true, InputBegan = newSignal(), InputEnded = newSignal(), InputChanged = newSignal(), LastInputTypeChanged = newSignal(), GetFocusedTextBox = function()
		return nil
	end, GetLastInputType = function()
		return Enum.UserInputType.MouseButton1
	end }, {}),
	-- like the engine: a destroyed selection reads back as nil
	GuiService = setmetatable({ MenuOpened = newSignal(), MenuClosed = newSignal(), GetGuiInset = function()
		return Vector2.new(0, 36), Vector2.zero
	end }, {
		__index = function(self, key)
			if key == "SelectedObject" then
				local selected = rawget(self, "_selected")
				if selected and isProxy(selected) and realOf[selected].Parent == nil then
					return nil
				end
				return selected
			end
			return nil
		end,
		__newindex = function(self, key, value)
			if key == "SelectedObject" then
				rawset(self, "_selected", value)
			else
				rawset(self, key, value)
			end
		end,
	}),
	GroupService = permissiveStub("GroupService"),
	Stats = permissiveStub("Stats"),
	TeleportService = permissiveStub("TeleportService"),
	CollectionService = { GetTagged = function()
		return {}
	end, GetInstanceAddedSignal = function()
		return newSignal()
	end, GetInstanceRemovedSignal = function()
		return newSignal()
	end, HasTag = function()
		return false
	end },
	HttpService = { JSONEncode = function()
		return "{}"
	end, JSONDecode = function()
		return {}
	end, GenerateGUID = function()
		return "guid"
	end },
	LocalizationService = { RobloxLocaleId = "de-de" },
	SoundService = permissiveStub("SoundService"),
	MarketplaceService = permissiveStub("MarketplaceService"),
	SocialService = permissiveStub("SocialService"),
	TextService = permissiveStub("TextService"),
	ProximityPromptService = permissiveStub("ProximityPromptService"),
	ContextActionService = permissiveStub("ContextActionService"),
	ReplicatedStorage = pathProxy(ROOT .. "/ReplicatedStorage"),
}
local fakeGame = {
	GetService = function(_, name)
		if name == "Lighting" then
			return wrap(realLighting)
		elseif name == "Workspace" then
			return wrap(realWorkspace)
		end
		local service = SERVICES[name]
		assert(service, "unstubbed service " .. name)
		return service
	end,
}

local taskShim = {
	spawn = function(fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			error(err, 2)
		end
	end,
	defer = function() end,
	delay = function() end,
	wait = function()
		return 0
	end,
	cancel = function() end,
}

env = setmetatable({
	setmetatable = setmetatable, getmetatable = getmetatable, pairs = pairs, ipairs = ipairs, next = next,
	select = select, type = type, tostring = tostring, tonumber = tonumber, pcall = pcall, xpcall = xpcall,
	error = error, assert = assert, rawget = rawget, rawset = rawset, rawequal = rawequal, rawlen = rawlen,
	unpack = table.unpack, print = print, math = math, string = string, table = table, os = os,
	coroutine = coroutine, utf8 = utf8, bit32 = bit32, buffer = buffer, debug = debug,
	game = fakeGame,
	workspace = wrap(realWorkspace),
	Instance = InstanceShim,
	require = requireModule,
	task = taskShim,
	typeof = function(v)
		if isProxy(v) then
			return "Instance"
		end
		return typeof(v)
	end,
	warn = function() end,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	Font = roblox.Font,
	Rect = roblox.Rect,
	TweenInfo = { new = function(...)
		return { args = table.pack(...) }
	end },
	DateTime = { now = function()
		return { UnixTimestamp = os.time() }
	end },
}, { __index = _G })

---------------------------------------------------------------------------
-- Stubs for modules with engine/network side effects
---------------------------------------------------------------------------
local netStub = {
	Function = function(name)
		return { InvokeServer = function()
			return nil
		end, Name = name }
	end,
	Event = function(name)
		return { FireServer = function() end, OnClientEvent = newSignal(), Name = name }
	end,
}
STUB_MODULES["Shared/Net.luau"] = netStub
STUB_MODULES["Shared/SessionState.luau"] = {
	Get = function()
		return nil
	end,
	Observe = function() end,
	Changed = newSignal(),
}
for _, name in { "AudioController", "InputController", "SettingsController", "GraphicsController", "VoiceController", "RadioController" } do
	STUB_MODULES["Controllers/" .. name .. ".luau"] = permissiveStub(name)
end

---------------------------------------------------------------------------
-- Scenario
---------------------------------------------------------------------------
local CLIENT = pathProxy(ROOT .. "/StarterPlayer/StarterPlayerScripts/Client")
local UI = CLIENT.UI

local function check(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end

local Config = requireModule(pathProxy(ROOT .. "/ReplicatedStorage/Shared/Config.luau"))
local Localization = requireModule(pathProxy(ROOT .. "/ReplicatedStorage/Shared/Localization"))
Localization.SetLanguage("de")

local values = Config.DefaultSettings()
values.language = "de"
local settingsStub = {
	Changed = newSignal(),
	Get = function(key)
		return values[key]
	end,
	Set = function(key, value)
		values[key] = value
	end,
	Step = function() end,
	Describe = function(key)
		return tostring(values[key])
	end,
}
local inputStub = permissiveStub("Input")
inputStub = setmetatable({ DeviceChanged = newSignal(), Action = newSignal(), GetDevice = function()
	return "keyboard"
end }, { __index = inputStub })

local Components = requireModule(UI.Components)
local Router = requireModule(UI.Router)
local menuGui = Components.ScreenGui("FZ_Menu", 20)
local router = Router.new(menuGui, inputStub)
local hudStub = permissiveStub("Hud")
router.App = setmetatable({
	Settings = settingsStub,
	Input = inputStub,
	Hud = hudStub,
	Debug = permissiveStub("Debug"),
	Profile = { signalMarks = 120, secrets = { logs = {}, photos = {} }, achievements = {}, progress = { chapter = 1, completedChapters = {} }, survival = {}, seenContent = {}, settings = values },
	Radio = { IsMuted = function()
		return false
	end, ToggleMute = function() end },
	Voice = permissiveStub("Voice"),
	HasNewContent = function()
		return true
	end,
	HasNewUpdate = function()
		return true
	end,
	HasProgress = function()
		return true
	end,
}, { __index = function(_, key)
	return function() end
end })

-- Simulates hover/focus/press on every button of a screen (and optionally clicks).
local function exercise(root, click)
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") or d:IsA("ImageButton") then
			local real = unwrap(d)
			for _, event in { "MouseEnter", "SelectionGained", "MouseButton1Down", "MouseButton1Up", "MouseLeave", "SelectionLost" } do
				signalFor(real, event):Fire()
			end
			if click then
				signalFor(real, "Activated"):Fire()
			end
		end
	end
end

-- Optional: dump GUI trees as JSON for tools/render_ui.py (lune run tools/ui_smoke.luau <outdir>)
local serde = require("@lune/serde")
local exportDir = process.args[1]
local function prop(inst, name)
	local ok, value = pcall(function()
		return inst[name]
	end)
	return if ok then value else nil
end
local function udim2(v)
	return if v then { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset } else nil
end
local function color(v)
	return if v then { v.R, v.G, v.B } else nil
end
local function dumpTree(inst)
	local node = { class = inst.ClassName, name = inst.Name, children = {} }
	if inst:IsA("GuiObject") or inst:IsA("LayerCollector") then
		node.visible = prop(inst, "Visible")
		node.pos = udim2(prop(inst, "Position"))
		node.size = udim2(prop(inst, "Size"))
		local anchor = prop(inst, "AnchorPoint")
		node.anchor = if anchor then { anchor.X, anchor.Y } else nil
		node.bg = color(prop(inst, "BackgroundColor3"))
		node.bgT = prop(inst, "BackgroundTransparency")
		node.z = prop(inst, "ZIndex")
		node.order = prop(inst, "LayoutOrder")
		local auto = prop(inst, "AutomaticSize")
		node.auto = if auto then auto.Name else nil
		node.clip = prop(inst, "ClipsDescendants")
		if inst:IsA("CanvasGroup") then
			node.groupT = prop(inst, "GroupTransparency")
		end
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			node.text = prop(inst, "Text")
			if node.text == "" and inst:IsA("TextBox") then
				node.text = prop(inst, "PlaceholderText")
			end
			node.textSize = prop(inst, "TextSize")
			node.textColor = color(prop(inst, "TextColor3"))
			node.textT = prop(inst, "TextTransparency")
			local font = prop(inst, "FontFace")
			node.font = if font then tostring(font.Family) .. "|" .. tostring(font.Weight.Name) else nil
			local xa, ya = prop(inst, "TextXAlignment"), prop(inst, "TextYAlignment")
			node.xalign = if xa then xa.Name else nil
			node.yalign = if ya then ya.Name else nil
			node.wrapped = prop(inst, "TextWrapped")
			node.rich = prop(inst, "RichText")
		end
		if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
			node.image = prop(inst, "Image")
		end
	elseif inst:IsA("UICorner") then
		local r = prop(inst, "CornerRadius")
		node.radius = if r then { r.Scale, r.Offset } else nil
	elseif inst:IsA("UIStroke") then
		node.color = color(prop(inst, "Color"))
		node.t = prop(inst, "Transparency")
		node.thickness = prop(inst, "Thickness")
	elseif inst:IsA("UIPadding") then
		node.pad = {}
		for _, side in { "PaddingLeft", "PaddingTop", "PaddingRight", "PaddingBottom" } do
			local v = prop(inst, side)
			table.insert(node.pad, if v then v.Offset else 0)
		end
	elseif inst:IsA("UIListLayout") then
		node.dir = prop(inst, "FillDirection").Name
		node.padding = prop(inst, "Padding").Offset
		node.valign = prop(inst, "VerticalAlignment").Name
		node.halign = prop(inst, "HorizontalAlignment").Name
	elseif inst:IsA("UIGradient") then
		node.rotation = prop(inst, "Rotation")
		local tr = prop(inst, "Transparency")
		node.tKeys = {}
		if tr then
			for _, k in tr.Keypoints do
				table.insert(node.tKeys, { k.Time, k.Value })
			end
		end
		local c = prop(inst, "Color")
		node.cKeys = {}
		if c then
			for _, k in c.Keypoints do
				table.insert(node.cKeys, { k.Time, k.Value.R, k.Value.G, k.Value.B })
			end
		end
	elseif inst:IsA("UISizeConstraint") then
		local m = prop(inst, "MaxSize")
		node.max = if m then { m.X, m.Y } else nil
	end
	for _, child in inst:GetChildren() do
		table.insert(node.children, dumpTree(child))
	end
	return node
end
local function export(name, gui)
	if exportDir then
		fs.writeFile(exportDir .. "/" .. name .. ".json", serde.encode("json", dumpTree(unwrap(gui))))
	end
end

local Screens = UI.Screens
local screenList = {
	{ "MainMenu (main)", Screens.MainMenu, { mode = "main" } },
	{ "MainMenu (pause)", Screens.MainMenu, { mode = "pause" } },
	{ "Play", Screens.Play },
	{ "Lobby", Screens.Lobby },
	{ "Settings", Screens.Settings },
	{ "Shop", Screens.Shop },
	{ "Archive", Screens.Archive },
	{ "Extras", Screens.Extras },
	{ "Updates", Screens.Updates },
	{ "Community", Screens.Community },
	{ "Leaderboard", Screens.Leaderboard, { entry = requireModule(pathProxy(ROOT .. "/ReplicatedStorage/Shared/Content.luau")).SurvivalMaps[1] } },
	{ "LanguageSelect", Screens.LanguageSelect, { firstStart = true, suggested = "de", onChosen = function() end } },
	{ "Admin", Screens.Admin },
}
for _, item in screenList do
	check("screen " .. item[1], function()
		local screen = router:Replace(requireModule(item[2]), item[3])
		screen.Root.GroupTransparency = 0
		export("screen_" .. string.gsub(item[1], "[^%w]", ""), menuGui)
		exercise(screen.Root, false)
	end)
end
-- tab / category clicks inside screens that rebuild their lists
for _, item in { { "Settings tabs", Screens.Settings }, { "Shop tabs", Screens.Shop }, { "Archive tabs", Screens.Archive } } do
	check(item[1], function()
		local screen = router:Replace(requireModule(item[2]))
		for _, d in screen.Root:GetDescendants() do
			if d:IsA("TextButton") and d.Parent and (d.Parent.Name == "Frame" or d.Parent:IsA("ScrollingFrame")) then
				signalFor(unwrap(d), "Activated"):Fire()
			end
		end
	end)
end
check("language switch re-render", function()
	router:Replace(requireModule(Screens.MainMenu), { mode = "main" })
	for _, code in Config.Languages do
		Localization.SetLanguage(code)
	end
	Localization.SetLanguage("de")
end)

local Hud = requireModule(UI.Hud)
local hudGui = Components.ScreenGui("FZ_HUD", 30)
check("Hud.Init", function()
	Hud.Init(hudGui, settingsStub, inputStub, { onOpen = function() end, onClose = function() end })
end)
check("Hud elements", function()
	Hud.ShowSubtitle({ text = "VOICE_UNAVAILABLE", speaker = "SPEAKER_RELAY", duration = 3 })
	Hud.ShowSubtitle({ text = "VOICE_UNAVAILABLE", duration = 3 })
	Hud.ShowSubtitle({ text = "VOICE_UNAVAILABLE", speaker = "SPEAKER_RELAY", duration = 3 })
	Hud.ShowSubtitle({ text = "VOICE_UNAVAILABLE", duration = 3 }) -- 4th line pushes the first out
	Hud.Notify("REWARD_MARKS", { amount = 40 })
	Hud.ShowObjective("OBJECTIVE_NEW", true)
	Hud.SetStatus("SV_SHIFT", { shift = 3 })
	Hud.SetStatus(nil)
	Hud.SetStamina(0.4, true)
	Hud.SetStamina(1, false)
	Hud.ShowObjective("OBJECTIVE_NEW", true)
	Hud.SetStatus("SV_SHIFT", { shift = 3 })
	export("hud", hudGui)
	Hud.ShowDocument({ title = "DOC_CLOSE", body = "VOICE_UNAVAILABLE" })
	export("hud_document", hudGui)
	exercise(hudGui, false)
	Hud.CloseDocument()
end)
for _, name in { "InventoryController", "HealthController", "PromptController", "RescueController" } do
	check("controller " .. name, function()
		local controller = requireModule(CLIENT.Controllers[name])
		if controller.Init then
			controller.Init(hudGui, settingsStub)
		end
	end)
end
for _, name in { "DecisionPanel", "PhotoView", "DebugOverlay" } do
	check("load " .. name, function()
		requireModule(UI[name])
	end)
end

print(if failures == 0 then "UI smoke test: all passed" else string.format("UI smoke test: %d failed", failures))
if failures > 0 then
	process.exit(1)
end
