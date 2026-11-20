-- Deutsch
return {
	-- Sprachauswahl
	LANG_PROMPT = "Wähle deine Sprache",
	LANG_SUGGESTED = "Vorschlag",
	LANG_HINT = "Du kannst das jederzeit in den Einstellungen ändern.",

	-- Hauptmenü
	MENU_PLAY = "Spielen",
	MENU_CONTINUE = "Fortsetzen",
	MENU_RESUME = "Weiter",
	MENU_LOBBY = "Team",
	MENU_CHAPTERS = "Kapitel",
	MENU_SETTINGS = "Einstellungen",
	MENU_EXTRAS = "Extras",
	MENU_BACK = "Zurück",
	MENU_TAGLINE = "Jemand sendet noch.",
	PAUSE_TITLE = "Menü",
	PAUSE_NOTE = "Die Station wartet nicht, solange dieses Menü offen ist.",

	-- Lobby / Team
	LOBBY_TITLE = "Team",
	LOBBY_COUNT = "{count} / {max} in dieser Sitzung",
	LOBBY_INVITE = "Freunde einladen",
	LOBBY_INVITE_UNAVAILABLE = "Einladungen sind gerade nicht verfügbar.",
	LOBBY_SOLO_HINT = "Alles ist auch allein spielbar. Freunde können jederzeit dazukommen.",
	LOBBY_YOU = "(du)",

	-- Kapitel
	CHAPTER_LABEL = "Kapitel {number}",
	CHAPTER_01_TITLE = "Der Empfang",
	CHAPTER_02_TITLE = "Die falsche Stimme",
	CHAPTER_03_TITLE = "Das Protokoll",
	CHAPTER_04_TITLE = "Frequenz Null",
	CHAPTER_LOCKED = "Noch kein Signal",

	-- Einstellungen
	SETTINGS_TITLE = "Einstellungen",
	SETTINGS_LANGUAGE = "Sprache",
	SETTINGS_SUBTITLES = "Untertitel",
	SETTINGS_SUBTITLE_SIZE = "Untertitelgröße",
	SETTINGS_SCARE = "Schreckintensität",
	SETTINGS_SCARE_DESC = "„Reduziert“ mildert plötzliche Schreckmomente. Die Geschichte bleibt gleich.",
	SETTINGS_CAMERA = "Kameraeffekte",
	SETTINGS_CAMERA_DESC = "Kamerawackeln, Sichtfeldänderungen und Bildverzerrung.",
	SETTINGS_GRAPHICS = "Grafik",
	SETTINGS_GRAPHICS_DESC = "Wichtige Hinweise und Kreaturen bleiben auf jeder Stufe sichtbar.",
	SETTINGS_BRIGHTNESS = "Helligkeit",
	SETTINGS_BRIGHTNESS_DESC = "Erhöhe sie, wenn dunkle Räume auf deinem Bildschirm schwer erkennbar sind.",
	VALUE_ON = "An",
	VALUE_OFF = "Aus",
	VALUE_SMALL = "Klein",
	VALUE_MEDIUM = "Mittel",
	VALUE_LARGE = "Groß",
	VALUE_REDUCED = "Reduziert",
	VALUE_STANDARD = "Standard",
	VALUE_INTENSE = "Intensiv",
	VALUE_CAM_OFF = "Aus",
	VALUE_CAM_REDUCED = "Reduziert",
	VALUE_CAM_FULL = "Voll",
	VALUE_AUTO = "Automatisch",
	VALUE_LOW = "Niedrig",
	VALUE_HIGH = "Hoch",
	VALUE_ULTRA = "Ultra",

	-- Extras / Funkcodes
	EXTRAS_TITLE = "Extras",
	EXTRAS_CODE_TITLE = "Funkcodes",
	EXTRAS_CODE_HINT = "Die Codes sind in der Station versteckt. Sieh genau hin.",
	EXTRAS_CODE_PLACEHOLDER = "Code eingeben",
	EXTRAS_REDEEM = "Senden",
	EXTRAS_BALANCE = "Signalmarken: {amount}",
	CODE_OK = "Signal empfangen. +{amount} Signalmarken.",
	CODE_INVALID = "Auf dieser Frequenz ist nichts.",
	CODE_USED = "Dieses Signal hast du bereits empfangen.",
	CODE_RATE_LIMITED = "Zu viele Versuche. Warte einen Moment.",
	CODE_ERROR = "Übertragung fehlgeschlagen. Versuche es später erneut.",

	-- Wartung (Admin)
	ADMIN_GRANTED = "Wartungszugang gewährt.",
	ADMIN_TITLE = "Wartung",
	ADMIN_DEBUG = "Leistungsanzeige",
	ADMIN_GRANT_TEST = "100 Testmarken hinzufügen",
	ADMIN_DONE = "Erledigt.",
	ADMIN_DENIED = "Zugriff verweigert.",

	-- Touch-Buttons
	TOUCH_SPRINT = "Rennen",
	TOUCH_LIGHT = "Licht",

	-- Interaktionen
	INTERACT_READ = "Lesen",
	INTERACT_OPEN = "Öffnen",
	OBJECT_FAX = "Faxgerät",
	OBJECT_DOOR = "Tür",

	-- Ziele
	OBJECTIVE_NEW = "Neues Ziel",
	OBJECTIVE_CHECK_GATEHOUSE = "Sieh in der Pförtnerloge nach.",
	OBJECTIVE_FIND_SENDER = "Finde heraus, wer da sendet.",

	-- Sprecher und Geräuschuntertitel
	SPEAKER_UNKNOWN = "Unbekannte Stimme",
	SPEAKER_RELAY = "Relais",
	SFX_STATIC = "[Funkrauschen]",
	SFX_FAX = "[Ein Faxgerät beginnt zu drucken]",

	-- Kapitel 1: Funk
	RADIO_C1_001 = "…VESPER-4 an alle, die das empfangen. Bitte. Jemand ist im Gebäude.",
	RADIO_C1_002 = "Sie sind gerade angekommen. Sie stehen am Tor.",
	RADIO_C1_003 = "Nicht antworten. Noch nicht.",

	-- Kapitel 1: Dokumente und Texte in der Welt
	DATE_FORMAT = "{d}.{m}.{y}",
	FAX_TITLE = "ARBEITSAUFTRAG 0214",
	FAX_BODY = "Inspektion der stillgelegten Relaisstation VESPER-4.\nGrund: unerlaubte Sendungen im Notrufband.\nAnweisung: Eingehende Rufe nicht beantworten.\n\nAbsender: VESPER-4 BETRIEB\nGesendet: {date}, 02:14 Uhr",
	DOC_CLOSE = "Schließen",
	SIGN_STATION = "RELAISSTATION VESPER-4\nZutritt nur für Befugte",
	NOTE_MAINTENANCE = "WARTUNG\nKanal {code} bleibt unbelegt.\nFalls er trotzdem sendet: nicht antworten.",

	-- Fehler
	ERROR_DATA = "Dein Spielstand konnte nicht geladen werden. Der Fortschritt dieser Sitzung wird nicht gespeichert.",
}
