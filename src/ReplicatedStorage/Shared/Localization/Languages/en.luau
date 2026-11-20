-- English (reference language and fallback). Every key must exist here.
return {
	-- Language selection
	LANG_PROMPT = "Choose your language",
	LANG_SUGGESTED = "Suggested",
	LANG_HINT = "You can change this anytime in Settings.",

	-- Main menu
	MENU_PLAY = "Play",
	MENU_CONTINUE = "Continue",
	MENU_RESUME = "Resume",
	MENU_LOBBY = "Team",
	MENU_CHAPTERS = "Chapters",
	MENU_SETTINGS = "Settings",
	MENU_EXTRAS = "Extras",
	MENU_BACK = "Back",
	MENU_TAGLINE = "Someone is still transmitting.",
	PAUSE_TITLE = "Menu",
	PAUSE_NOTE = "The station does not wait while this menu is open.",

	-- Lobby / team
	LOBBY_TITLE = "Team",
	LOBBY_COUNT = "{count} / {max} in this session",
	LOBBY_INVITE = "Invite friends",
	LOBBY_INVITE_UNAVAILABLE = "Invites are not available right now.",
	LOBBY_SOLO_HINT = "Everything can be played alone. Friends can join at any time.",
	LOBBY_YOU = "(you)",

	-- Chapters
	CHAPTER_LABEL = "Chapter {number}",
	CHAPTER_01_TITLE = "The Reception",
	CHAPTER_02_TITLE = "The Wrong Voice",
	CHAPTER_03_TITLE = "The Protocol",
	CHAPTER_04_TITLE = "Frequency Zero",
	CHAPTER_LOCKED = "No signal yet",

	-- Settings
	SETTINGS_TITLE = "Settings",
	SETTINGS_LANGUAGE = "Language",
	SETTINGS_SUBTITLES = "Subtitles",
	SETTINGS_SUBTITLE_SIZE = "Subtitle size",
	SETTINGS_SCARE = "Scare intensity",
	SETTINGS_SCARE_DESC = "Reduced softens sudden scares. The story stays the same.",
	SETTINGS_CAMERA = "Camera effects",
	SETTINGS_CAMERA_DESC = "Camera shake, field-of-view changes and screen distortion.",
	SETTINGS_GRAPHICS = "Graphics",
	SETTINGS_GRAPHICS_DESC = "Important hints and creatures stay visible on every level.",
	SETTINGS_BRIGHTNESS = "Brightness",
	SETTINGS_BRIGHTNESS_DESC = "Raise it if dark rooms are hard to read on your screen.",
	VALUE_ON = "On",
	VALUE_OFF = "Off",
	VALUE_SMALL = "Small",
	VALUE_MEDIUM = "Medium",
	VALUE_LARGE = "Large",
	VALUE_REDUCED = "Reduced",
	VALUE_STANDARD = "Standard",
	VALUE_INTENSE = "Intense",
	VALUE_CAM_OFF = "Off",
	VALUE_CAM_REDUCED = "Reduced",
	VALUE_CAM_FULL = "Full",
	VALUE_AUTO = "Automatic",
	VALUE_LOW = "Low",
	VALUE_HIGH = "High",
	VALUE_ULTRA = "Ultra",

	-- Extras / transmission codes
	EXTRAS_TITLE = "Extras",
	EXTRAS_CODE_TITLE = "Transmission codes",
	EXTRAS_CODE_HINT = "Codes are hidden inside the station. Look closely.",
	EXTRAS_CODE_PLACEHOLDER = "Enter code",
	EXTRAS_REDEEM = "Transmit",
	EXTRAS_BALANCE = "Signal marks: {amount}",
	CODE_OK = "Signal received. +{amount} signal marks.",
	CODE_INVALID = "Nothing on this frequency.",
	CODE_USED = "You have already received this signal.",
	CODE_RATE_LIMITED = "Too many attempts. Wait a moment.",
	CODE_ERROR = "Transmission failed. Please try again later.",

	-- Maintenance (admin)
	ADMIN_GRANTED = "Maintenance access granted.",
	ADMIN_TITLE = "Maintenance",
	ADMIN_DEBUG = "Performance overlay",
	ADMIN_GRANT_TEST = "Add 100 test marks",
	ADMIN_DONE = "Done.",
	ADMIN_DENIED = "Access denied.",

	-- Touch buttons
	TOUCH_SPRINT = "Run",
	TOUCH_LIGHT = "Light",

	-- Interaction prompts
	INTERACT_READ = "Read",
	INTERACT_OPEN = "Open",
	OBJECT_FAX = "Fax machine",
	OBJECT_DOOR = "Door",

	-- Objectives
	OBJECTIVE_NEW = "New objective",
	OBJECTIVE_CHECK_GATEHOUSE = "Check the gatehouse.",
	OBJECTIVE_FIND_SENDER = "Find out who is transmitting.",

	-- Speakers and sound captions
	SPEAKER_UNKNOWN = "Unknown voice",
	SPEAKER_RELAY = "Relay",
	SFX_STATIC = "[Radio static]",
	SFX_FAX = "[A fax machine starts printing]",

	-- Chapter 1: radio
	RADIO_C1_001 = "...VESPER-4 to anyone receiving. Please. Someone is inside the building.",
	RADIO_C1_002 = "They just arrived. They're standing at the gate.",
	RADIO_C1_003 = "Don't answer. Not yet.",

	-- Chapter 1: documents and world text
	DATE_FORMAT = "{m}/{d}/{y}",
	FAX_TITLE = "WORK ORDER 0214",
	FAX_BODY = "Inspection of decommissioned relay station VESPER-4.\nReason: unauthorized transmissions on the emergency band.\nInstruction: Do not respond to incoming calls.\n\nSender: VESPER-4 OPERATIONS\nSent: {date}, 02:14",
	DOC_CLOSE = "Close",
	SIGN_STATION = "VESPER-4 RELAY STATION\nNo unauthorized entry",
	NOTE_MAINTENANCE = "MAINTENANCE\nChannel {code} must stay unassigned.\nIf it transmits anyway: do not reply.",

	-- Errors
	ERROR_DATA = "Your save could not be loaded. Progress in this session will not be saved.",
}
