-- FREQUENCY ZERO - client bootstrap.
--
-- Flow: boot screen (logo only) -> load profile -> apply saved language BEFORE any text
-- exists -> first start: language picker / otherwise: main menu -> play.
-- Because no localized UI is created before the language is known, players never see
-- placeholder or wrong-language text that changes a moment later.

local CollectionService = game:GetService("CollectionService")
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
	or { settings = {}, signalMarks = 0, progress = { chapter = 1, completed = {} }, persistent = false, isNew = true }

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

Net.Event("Subtitle").OnClientEvent:Connect(Hud.ShowSubtitle)
Net.Event("Document").OnClientEvent:Connect(Hud.ShowDocument)
Net.Event("Notify").OnClientEvent:Connect(function(key, params)
	if type(key) == "string" then
		Hud.Notify(key, if type(params) == "table" then params else nil)
	end
end)
SessionState.Observe("Objective", function(key)
	if state == "playing" and type(key) == "string" then
		Hud.ShowObjective(key)
	end
end)

---------------------------------------------------------------------------
-- 4. App flow
---------------------------------------------------------------------------
local readyRemote = Net.Event("ClientReady")
local pauseOpenedAt = 0

local app = {
	Settings = SettingsController,
	Input = InputController,
	Hud = Hud,
	Debug = DebugOverlay,
	Profile = profile,
}
router.App = app

function app.HasProgress(): boolean
	return profile.isNew == false
end

function app.Play(_chapter: number?)
	if state == "menu" then
		state = "playing"
		router:Clear()
		backdrop.Visible = false
		setMenuCamera(false)
		setGameplay(true)
		readyRemote:FireServer()
		local objective = SessionState.Get("Objective")
		if type(objective) == "string" then
			Hud.ShowObjective(objective, false)
		end
	elseif state == "paused" then
		state = "playing"
		router:Clear()
		backdrop.Visible = false
		setGameplay(true)
	end
end

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
		app.Play()
	end
end)

local function showMainMenu()
	state = "menu"
	backdrop.Visible = true
	setMenuCamera(true)
	router:Replace(MainMenu, { mode = "main" })
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
		end,
	})
else
	showMainMenu()
end

if player:GetAttribute("FZ_DataPersistent") == false then
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
