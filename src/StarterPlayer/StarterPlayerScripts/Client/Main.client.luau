-- FREQUENCY ZERO - client bootstrap.
--
-- Flow: boot screen (logo only) -> load profile -> apply saved language BEFORE any text
-- exists -> first start: language picker / otherwise: main menu -> play.
-- Because no localized UI is created before the language is known, players never see
-- placeholder or wrong-language text that changes a moment later.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
local Updates = require(Shared.Updates)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)
local SessionState = require(Shared.SessionState)

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local InputController = require(Controllers.InputController)
local SettingsController = require(Controllers.SettingsController)
local GraphicsController = require(Controllers.GraphicsController)
local MovementController = require(Controllers.MovementController)
local FlashlightController = require(Controllers.FlashlightController)
local WorldTextController = require(Controllers.WorldTextController)
local AudioController = require(Controllers.AudioController)
local VoiceController = require(Controllers.VoiceController)
local RadioController = require(Controllers.RadioController)
local CreatureVisualsController = require(Controllers.CreatureVisualsController)
local HealthController = require(Controllers.HealthController)
local EquipmentController = require(Controllers.EquipmentController)
local DirectorController = require(Controllers.DirectorController)
local InventoryController = require(Controllers.InventoryController)
local PromptController = require(Controllers.PromptController)
local DecisionPanel = require(UI.DecisionPanel)

local Components = require(UI.Components)
local Theme = require(UI.Theme)
local Router = require(UI.Router)
local Hud = require(UI.Hud)
local DebugOverlay = require(UI.DebugOverlay)
local MainMenu = require(UI.Screens.MainMenu)
local LanguageSelect = require(UI.Screens.LanguageSelect)

---------------------------------------------------------------------------
-- 1. Screen layers (no text yet)
---------------------------------------------------------------------------
local backdropGui = Components.ScreenGui("FZ_Backdrop", 10, true)
local menuGui = Components.ScreenGui("FZ_Menu", 20)
Components.AttachScale(menuGui)
local hudGui = Components.ScreenGui("FZ_HUD", 30)
Components.AttachScale(hudGui)

-- Dark on the left (menu column), revealing the scene on the right.
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.BackgroundColor3 = Theme.Colors.Background
backdrop.BorderSizePixel = 0
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Visible = false
backdrop.Parent = backdropGui
local gradient = Instance.new("UIGradient")
gradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.05),
	NumberSequenceKeypoint.new(0.45, 0.35),
	NumberSequenceKeypoint.new(1, 0.75),
})
gradient.Parent = backdrop

InputController.Init(hudGui)

---------------------------------------------------------------------------
-- 2. Profile + language (before any localized UI is built)
---------------------------------------------------------------------------
local function waitForAttribute(name: string, timeout: number): boolean
	local deadline = os.clock() + timeout
	while player:GetAttribute(name) ~= true and os.clock() < deadline do
		task.wait(0.1)
	end
	return player:GetAttribute(name) == true
end

local profile = nil
if waitForAttribute("FZ_DataReady", 25) then
	local ok, result = pcall(function()
		return Net.Function("FetchProfile"):InvokeServer()
	end)
	if ok and type(result) == "table" then
		profile = result
	end
end
profile = profile
	or { settings = {}, signalMarks = 0, progress = { chapter = 1, completedChapters = {} }, survival = {}, seenContent = {}, lastSeenUpdate = "", persistent = false, isNew = true }

SettingsController.Load(profile.settings)

local function robloxLocale(): string
	local ok, locale = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	if ok and type(locale) == "string" and locale ~= "" then
		return locale
	end
	return player.LocaleId
end

local savedLanguage = SettingsController.Get("language")
local detectedLanguage = Localization.Detect(robloxLocale()) or Config.FallbackLanguage
Localization.SetLanguage(savedLanguage or detectedLanguage)

if RunService:IsStudio() then
	for _, problem in Localization.Validate() do
		warn("[FZ-Loc] " .. problem)
	end
end

---------------------------------------------------------------------------
-- 3. Controllers and HUD
---------------------------------------------------------------------------
local state = "boot" -- boot | language | menu | playing | paused
local router = Router.new(menuGui, InputController)

local controls = nil
local function getControls()
	if controls then
		return controls
	end
	local ok, result = pcall(function()
		local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
		return (playerModule :: any):GetControls()
	end)
	if ok then
		controls = result
	else
		warn("[FZ] PlayerModule controls unavailable: " .. tostring(result))
	end
	return controls
end

local function setGameplay(enabled: boolean)
	InputController.SetGameplayEnabled(enabled)
	MovementController.SetActive(enabled)
	-- No world interactions (E / X / tap prompts) while a menu or document is open.
	pcall(function()
		(ProximityPromptService :: any).Enabled = enabled
	end)
	if not enabled then
		RadioController.Stop()
	end
	EquipmentController.SetActive(enabled)
	local c = getControls()
	if c then
		if enabled then
			c:Enable()
		else
			c:Disable()
		end
	end
end

local function setMenuCamera(active: boolean)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if active then
		local anchor = CollectionService:GetTagged("FZ_MenuCamera")[1]
		if anchor and anchor:IsA("BasePart") then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = anchor.CFrame
		end
	else
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = Config.Movement.BaseFov
	end
end

GraphicsController.Init(SettingsController)
WorldTextController.Init()
Hud.Init(hudGui, SettingsController, InputController, {
	onOpen = function()
		setGameplay(false)
	end,
	onClose = function()
		if state == "playing" then
			setGameplay(true)
		end
	end,
})
DebugOverlay.Init(hudGui, {
	profile = GraphicsController.GetProfileName,
	quality = GraphicsController.GetRobloxQualityLevel,
	device = InputController.GetDevice,
	input = function()
		return if InputController.IsUsingActionSystem() then "IAS" else "UIS"
	end,
})
MovementController.Init(SettingsController, Hud.SetStamina)
FlashlightController.Init()
AudioController.Init(SettingsController)
VoiceController.SetVolume((SettingsController.Get("volumeVoice") or 10) / 10)
SettingsController.Changed:Connect(function(key, value)
	if key == "volumeVoice" then
		VoiceController.SetVolume(value / 10)
	end
end)
VoiceController.Init()
RadioController.Init(hudGui, SettingsController)
CreatureVisualsController.Init(Hud.ShowSubtitle)
HealthController.Init(hudGui, SettingsController)
EquipmentController.Init()
DirectorController.Init(SettingsController, Hud.ShowSubtitle)
DecisionPanel.Init(hudGui, InputController)
InventoryController.Init(hudGui)
PromptController.Init()

-- Forecast countdown (the prediction you can break)
local function updateForecast()
	local key = SessionState.Get("Forecast")
	local ends = SessionState.Get("ForecastEnds")
	if type(key) == "string" and type(ends) == "number" then
		Hud.SetForecast(key, ends - workspace:GetServerTimeNow())
	else
		Hud.SetForecast(nil)
	end
end
SessionState.Observe("Forecast", updateForecast)
task.spawn(function()
	while true do
		task.wait(0.5)
		if SessionState.Get("Forecast") then
			updateForecast()
		end
	end
end)

-- Scare intensity: creature sounds are mixed down on "reduced" (medic set dampens too).
local function applyScareMix()
	local level = SettingsController.Get("scareIntensity")
	local volume = if level == "reduced" then 0.55 elseif level == "intense" then 1 else 0.85
	if player:GetAttribute("FZ_ScareDampening") then
		volume *= 0.8
	end
	AudioController.SetScareFactor(volume)
end
applyScareMix()
SettingsController.Changed:Connect(applyScareMix)
player:GetAttributeChangedSignal("FZ_ScareDampening"):Connect(applyScareMix)

if not VoiceController.IsAvailable() then
	task.delay(8, function()
		Hud.Notify("VOICE_UNAVAILABLE")
	end)
end

Net.Event("Subtitle").OnClientEvent:Connect(Hud.ShowSubtitle)
Net.Event("Document").OnClientEvent:Connect(Hud.ShowDocument)
Net.Event("Notify").OnClientEvent:Connect(function(key, params)
	if type(key) == "string" then
		Hud.Notify(key, if type(params) == "table" then params else nil)
	end
end)
local function objectiveParams(): { [string]: any }?
	local raw = SessionState.Get("ObjectiveParams")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(decoded) == "table" then decoded else nil
end
local function showObjective(announce: boolean?)
	local key = SessionState.Get("Objective")
	if state == "playing" and type(key) == "string" then
		Hud.ShowObjective(key, announce, objectiveParams())
	end
end
SessionState.Observe("Objective", function()
	showObjective()
end)
SessionState.Observe("ObjectiveParams", function()
	showObjective()
end)

---------------------------------------------------------------------------
-- 4. App flow
---------------------------------------------------------------------------
local sessionRemote = Net.Function("Session")
local pauseOpenedAt = 0
local leaving = false

local app = {
	Settings = SettingsController,
	Input = InputController,
	Hud = Hud,
	Debug = DebugOverlay,
	Profile = profile,
	Voice = VoiceController,
	Radio = RadioController,
}
router.App = app
router.ShouldIgnoreBack = Hud.IsDocumentOpen

function app.HasProgress(): boolean
	return profile.isNew == false
end

function app.HasNewContent(): boolean
	local seen = profile.seenContent or {}
	for _, entry in Content.Chapters do
		if entry.since and entry.status == "available" and not seen[entry.id] then
			return true
		end
	end
	for _, entry in Content.SurvivalMaps do
		if entry.since and entry.status == "available" and not seen[entry.id] then
			return true
		end
	end
	return false
end

function app.HasNewUpdate(): boolean
	local newest = Updates[1]
	return newest ~= nil and profile.lastSeenUpdate ~= newest.id
end

local function enterGame()
	AudioController.SetMenu(false)
	state = "playing"
	router:Clear()
	backdrop.Visible = false
	setMenuCamera(false)
	setGameplay(true)
	showObjective(false)
end

local function showMainMenu()
	AudioController.SetMenu(true)
	state = "menu"
	setGameplay(false)
	backdrop.Visible = true
	setMenuCamera(true)
	Hud.SetStatus(nil)
	router:Replace(MainMenu, { mode = "main" })
end

local function callSession(action: string, mode: string?, contentId: string?)
	local ok, result = pcall(function()
		return sessionRemote:InvokeServer(action, mode, contentId)
	end)
	return if ok and type(result) == "table" then result else { status = "error" }
end

local SESSION_MESSAGES = { teleport = "SESSION_TELEPORT", locked = "SESSION_LOCKED", error = "SESSION_ERROR" }

-- Start (or join) a chapter / survival map chosen in the Play screen.
function app.Start(mode: string, contentId: string)
	local result = callSession("start", mode, contentId)
	if result.status == "ok" then
		enterGame()
	elseif result.status == "busy" then
		local entry = Content.Entry(result.mode, result.contentId)
		Hud.Notify("SESSION_BUSY", { name = if entry then Localization.T(entry.title) else "?" })
	else
		Hud.Notify(SESSION_MESSAGES[result.status] or "SESSION_ERROR")
	end
end

-- Join whatever the team in this server is playing.
function app.Join()
	local result = callSession("join")
	if result.status == "ok" then
		enterGame()
	else
		router:Push(require(UI.Screens.Play))
	end
end

-- Close the menu (pause) or, for owner tests, walk around without a session.
function app.Resume()
	AudioController.SetMenu(false)
	if state == "paused" or state == "menu" then
		state = "playing"
		router:Clear()
		backdrop.Visible = false
		setMenuCamera(false)
		setGameplay(true)
	end
end

function app.CreatePrivate()
	local result = callSession("private")
	Hud.Notify(if result.status == "teleport" then "SESSION_TELEPORT" elseif result.status == "invited" then "PARTY_SENT" else "SESSION_ERROR")
end

function app.Rejoin()
	local result = callSession("rejoin")
	Hud.Notify(if result.status == "teleport" then "SESSION_TELEPORT" else "SESSION_ERROR")
end

function app.Leave()
	leaving = true
	callSession("leave")
	leaving = false
	showMainMenu()
end

-- The server ended the session (chapter finished, run over, idle): back to the menu.
player:GetAttributeChangedSignal("FZ_InGame"):Connect(function()
	if player:GetAttribute("FZ_InGame") ~= true and not leaving and (state == "playing" or state == "paused") then
		if not player:GetAttribute("FZ_MonsterMode") then
			Hud.CloseDocument()
			task.delay(0.5, showMainMenu)
		end
	end
end)

-- Survival status line
local function updateStatus()
	local shift = SessionState.Get("SvShift")
	if type(shift) ~= "number" or shift <= 0 then
		Hud.SetStatus(nil)
		return
	end
	if SessionState.Get("SvPhase") == "break" then
		local ends = SessionState.Get("SvBreakEnds")
		local seconds = if type(ends) == "number" then math.max(0, math.ceil(ends - workspace:GetServerTimeNow())) else 0
		Hud.SetStatus("SV_BREAK_TIMER", { seconds = seconds })
	else
		local event = SessionState.Get("SvEvent")
		Hud.SetStatus("SV_SHIFT", { shift = shift }, if type(event) == "string" then event else nil)
	end
end
for _, key in { "SvShift", "SvEvent", "SvPhase", "SvBreakEnds" } do
	SessionState.Observe(key, updateStatus)
end
task.spawn(function()
	while true do
		task.wait(1)
		if SessionState.Get("SvPhase") == "break" then
			updateStatus()
		end
	end
end)
Localization.Changed:Connect(updateStatus)

local function openPause()
	if state ~= "playing" or Hud.IsDocumentOpen() then
		return
	end
	state = "paused"
	pauseOpenedAt = os.clock()
	setGameplay(false)
	backdrop.Visible = true
	router:Replace(MainMenu, { mode = "pause" })
end

InputController.Action:Connect(function(name, pressed)
	if name == "Pause" and pressed then
		openPause()
	end
end)

-- The same buttons close the in-game menu again (only from its first page).
UserInputService.InputBegan:Connect(function(input)
	if state ~= "paused" or #router.Stack ~= 1 or os.clock() - pauseOpenedAt < 0.25 then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.ButtonSelect or (key == Enum.KeyCode.P and not UserInputService:GetFocusedTextBox()) then
		app.Resume()
	end
end)

local function afterMenu()
	-- Arrived by teleport with a selection: straight into the session.
	if player:GetAttribute("FZ_AutoJoin") then
		app.Join()
	end
end

setGameplay(false)
if savedLanguage == nil then
	state = "language"
	backdrop.Visible = true
	router:Replace(LanguageSelect, {
		firstStart = true,
		suggested = detectedLanguage,
		onChosen = function(code: string)
			SettingsController.Set("language", code)
			showMainMenu()
			afterMenu()
		end,
	})
else
	showMainMenu()
	afterMenu()
end

if player:GetAttribute("FZ_DataTooNew") then
	Hud.Notify("ERROR_DATA_NEWER")
elseif player:GetAttribute("FZ_DataPersistent") == false then
	Hud.Notify("ERROR_DATA")
end

---------------------------------------------------------------------------
-- 5. Remove boot screen (fade)
---------------------------------------------------------------------------
local boot = player:WaitForChild("PlayerGui"):FindFirstChild("FZ_Boot")
if boot then
	local background = boot:FindFirstChild("Background")
	if background then
		for _, child in background:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, Theme.Slow, { TextTransparency = 1 }):Play()
			elseif child:IsA("Frame") then
				TweenService:Create(child, Theme.Slow, { BackgroundTransparency = 1 }):Play()
			end
		end
		local fade = TweenService:Create(background, Theme.Slow, { BackgroundTransparency = 1 })
		fade.Completed:Once(function()
			boot:Destroy()
		end)
		fade:Play()
	else
		boot:Destroy()
	end
end
