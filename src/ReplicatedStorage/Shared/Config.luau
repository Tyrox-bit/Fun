-- Config: single source of truth for values shared by client and server.
-- Anything security-relevant (codes, admin gesture) lives in ServerStorage, never here.

local Config = {}

Config.Version = "0.3.0"
Config.MaxPartySize = 4

---------------------------------------------------------------------------
-- Languages (order = order in the language picker)
---------------------------------------------------------------------------
Config.Languages = { "de", "en", "es", "fr", "pt-br" }
Config.FallbackLanguage = "en"
Config.LanguageNames = {
	de = "Deutsch",
	en = "English",
	es = "Español",
	fr = "Français",
	["pt-br"] = "Português (Brasil)",
}
Config.LanguageTags = { de = "DE", en = "EN", es = "ES", fr = "FR", ["pt-br"] = "PT" }

---------------------------------------------------------------------------
-- Player settings schema (validated identically on client and server)
---------------------------------------------------------------------------
Config.Settings = {
	-- default = nil means "not chosen yet" -> first-start language picker.
	language = { kind = "enum", values = Config.Languages, default = nil },
	subtitles = { kind = "bool", default = true },
	subtitleSize = {
		kind = "enum",
		values = { "small", "medium", "large" },
		labels = { small = "VALUE_SMALL", medium = "VALUE_MEDIUM", large = "VALUE_LARGE" },
		default = "medium",
	},
	scareIntensity = {
		kind = "enum",
		values = { "reduced", "standard", "intense" },
		labels = { reduced = "VALUE_REDUCED", standard = "VALUE_STANDARD", intense = "VALUE_INTENSE" },
		default = "standard",
	},
	cameraEffects = {
		kind = "enum",
		values = { "off", "reduced", "full" },
		labels = { off = "VALUE_CAM_OFF", reduced = "VALUE_CAM_REDUCED", full = "VALUE_CAM_FULL" },
		default = "full",
	},
	graphics = {
		kind = "enum",
		values = { "auto", "low", "medium", "high", "ultra" },
		labels = { auto = "VALUE_AUTO", low = "VALUE_LOW", medium = "VALUE_MEDIUM", high = "VALUE_HIGH", ultra = "VALUE_ULTRA" },
		default = "auto",
	},
	brightness = { kind = "int", min = 0, max = 10, default = 5 },
	radioMode = {
		kind = "enum",
		values = { "hold", "toggle" },
		labels = { hold = "VALUE_HOLD", toggle = "VALUE_TOGGLE" },
		default = "hold",
	},
}

-- Display order + localization keys for the settings screen.
Config.SettingsOrder = {
	{ key = "language", label = "SETTINGS_LANGUAGE" },
	{ key = "subtitles", label = "SETTINGS_SUBTITLES" },
	{ key = "subtitleSize", label = "SETTINGS_SUBTITLE_SIZE" },
	{ key = "scareIntensity", label = "SETTINGS_SCARE", description = "SETTINGS_SCARE_DESC" },
	{ key = "cameraEffects", label = "SETTINGS_CAMERA", description = "SETTINGS_CAMERA_DESC" },
	{ key = "graphics", label = "SETTINGS_GRAPHICS", description = "SETTINGS_GRAPHICS_DESC" },
	{ key = "brightness", label = "SETTINGS_BRIGHTNESS", description = "SETTINGS_BRIGHTNESS_DESC" },
	{ key = "radioMode", label = "SETTINGS_RADIO_MODE", description = "SETTINGS_RADIO_MODE_DESC" },
}

function Config.ValidateSetting(key: any, value: any): (boolean, any)
	if type(key) ~= "string" then
		return false, nil
	end
	local definition = Config.Settings[key]
	if not definition then
		return false, nil
	end
	if definition.kind == "enum" then
		if type(value) == "string" and table.find(definition.values, value) then
			return true, value
		end
	elseif definition.kind == "bool" then
		if type(value) == "boolean" then
			return true, value
		end
	elseif definition.kind == "int" then
		if
			type(value) == "number"
			and value == value -- NaN guard
			and value % 1 == 0
			and value >= definition.min
			and value <= definition.max
		then
			return true, value
		end
	end
	return false, nil
end

function Config.DefaultSettings(): { [string]: any }
	local settings = {}
	for key, definition in Config.Settings do
		settings[key] = definition.default
	end
	return settings
end

---------------------------------------------------------------------------
-- Movement (horror pacing: slow walk, short limited sprint)
---------------------------------------------------------------------------
Config.Movement = {
	WalkSpeed = 10,
	SprintSpeed = 16,
	StaminaSeconds = 6, -- full bar lasts this long while sprinting
	RegenSeconds = 8, -- empty -> full while not sprinting
	RegenDelay = 1, -- seconds after sprinting before regeneration starts
	ExhaustedThreshold = 0.3, -- after running dry, sprint unlocks again at 30 %
	SprintFovBoost = 4,
	BaseFov = 70,
}

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------
Config.Data = {
	StoreName = "FZ_PlayerData_v1",
	SchemaVersion = 2, -- bump + add a migration in DataService for every save change
	AutosaveInterval = 120,
	LockTimeout = 1800, -- a session lock older than this is considered stale
}

Config.Codes = {
	MaxLength = 24,
}

---------------------------------------------------------------------------
-- Voice and radio (Roblox Audio API)
---------------------------------------------------------------------------
Config.Voice = {
	ProximityFull = 12, -- studs: full volume for normal (spatial) voice
	ProximityMax = 90, -- studs: inaudible beyond this
	RadioFull = 40, -- studs: radio at full volume up to here
	RadioMax = 900, -- studs: radio fades out (only static) towards this
	RadioMinVolume = 0.08,
}

---------------------------------------------------------------------------
-- Noise (what the creature can hear). Radius in studs.
---------------------------------------------------------------------------
Config.Noise = {
	Walk = 7,
	Sprint = 20,
	Radio = 28,
	Door = 16,
	Interact = 10,
}

---------------------------------------------------------------------------
-- Creature ("Der Lauscher")
---------------------------------------------------------------------------
Config.Creature = {
	PatrolSpeed = 7,
	InvestigateSpeed = 11,
	ChaseSpeed = 15, -- slightly slower than sprint (16): breaking line of sight works
	SoloSpeedScale = 0.9,
	HearingScale = 1,
	SightRange = 42,
	SightAngle = 65, -- degrees from facing direction
	ListenTime = 1.6,
	AttackRange = 5.5,
	AttackWindup = 0.65, -- telegraphed: crackle + pose before every hit
	Damage = 34, -- three hits to go down, never a one-hit kill
	AttackCooldown = 1.8,
	LoseTrackTime = 6,
	SearchTime = 14,
	BlindRange = 26,
	BlindDuration = 1.8,
	BlindCooldown = 9,
	VentChance = 0.35,
	VentTravelTime = 4,
	VentWarning = 2.5, -- rattle at the exit vent before it appears
	ActivateAfterFuses = 1, -- the creature wakes after the first fuse is taken
}

---------------------------------------------------------------------------
-- Health, downed state, revive
---------------------------------------------------------------------------
Config.Health = {
	Max = 100,
	RegenDelay = 10,
	RegenCap = 50,
	RegenPerSecond = 3,
	DownedTimeout = 35,
	ReviveHold = 3,
	ReviveHealth = 35,
	CrawlSpeed = 2,
}

---------------------------------------------------------------------------
-- Endless survival ("Night shift")
---------------------------------------------------------------------------
Config.Survival = {
	BreakSeconds = 25, -- calm phase between shifts; extraction is open
	TaskSoftLimit = 180, -- after this the station "overloads": the creature is sent to you
	FirstEventShift = 2,
	SecondCreatureShift = 6,
	ShiftReward = 40, -- + ShiftRewardGrowth * shift, banked when a shift is completed
	ShiftRewardGrowth = 10,
	ExtractBonus = 0.2, -- +20 % when the team leaves on its own
	WipeKeep = 0.5, -- 50 % of the banked marks if the team goes down
	ExtractRadius = 28,
	MaxSpeedScale = 1.25,
	MaxHearingScale = 1.6,
	SessionIdleEnd = 20, -- seconds without players in game before a session ends
}

Config.Rewards = {
	Fuse = 60,
	Relay = 150,
	ForecastBroken = 100,
	ChapterComplete = 600,
}

return Config
