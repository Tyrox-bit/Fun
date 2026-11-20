-- Français
return {
	-- Choix de la langue
	LANG_PROMPT = "Choisis ta langue",
	LANG_SUGGESTED = "Suggestion",
	LANG_HINT = "Tu peux la changer à tout moment dans les Paramètres.",

	-- Menu principal
	MENU_PLAY = "Jouer",
	MENU_CONTINUE = "Continuer",
	MENU_RESUME = "Reprendre",
	MENU_LOBBY = "Équipe",
	MENU_CHAPTERS = "Chapitres",
	MENU_SETTINGS = "Paramètres",
	MENU_EXTRAS = "Extras",
	MENU_BACK = "Retour",
	MENU_TAGLINE = "Quelqu'un émet encore.",
	PAUSE_TITLE = "Menu",
	PAUSE_NOTE = "La station n'attend pas pendant que ce menu est ouvert.",

	-- Équipe
	LOBBY_TITLE = "Équipe",
	LOBBY_COUNT = "{count} / {max} dans cette session",
	LOBBY_INVITE = "Inviter des amis",
	LOBBY_INVITE_UNAVAILABLE = "Les invitations ne sont pas disponibles pour le moment.",
	LOBBY_SOLO_HINT = "Tout peut se jouer en solo. Tes amis peuvent te rejoindre à tout moment.",
	LOBBY_YOU = "(toi)",

	-- Chapitres
	CHAPTER_LABEL = "Chapitre {number}",
	CHAPTER_01_TITLE = "La Réception",
	CHAPTER_02_TITLE = "La Mauvaise Voix",
	CHAPTER_03_TITLE = "Le Protocole",
	CHAPTER_04_TITLE = "Fréquence Zéro",
	CHAPTER_LOCKED = "Pas encore de signal",

	-- Paramètres
	SETTINGS_TITLE = "Paramètres",
	SETTINGS_LANGUAGE = "Langue",
	SETTINGS_SUBTITLES = "Sous-titres",
	SETTINGS_SUBTITLE_SIZE = "Taille des sous-titres",
	SETTINGS_SCARE = "Intensité de la peur",
	SETTINGS_SCARE_DESC = "« Réduite » atténue les frayeurs soudaines. L'histoire reste la même.",
	SETTINGS_CAMERA = "Effets de caméra",
	SETTINGS_CAMERA_DESC = "Tremblements, variations du champ de vision et distorsions de l'image.",
	SETTINGS_GRAPHICS = "Qualité graphique",
	SETTINGS_GRAPHICS_DESC = "Les indices importants et les créatures restent visibles à tous les niveaux.",
	SETTINGS_BRIGHTNESS = "Luminosité",
	SETTINGS_BRIGHTNESS_DESC = "Augmente-la si les pièces sombres sont difficiles à distinguer sur ton écran.",
	VALUE_ON = "Activés",
	VALUE_OFF = "Désactivés",
	VALUE_SMALL = "Petite",
	VALUE_MEDIUM = "Moyenne",
	VALUE_LARGE = "Grande",
	VALUE_REDUCED = "Réduite",
	VALUE_STANDARD = "Standard",
	VALUE_INTENSE = "Intense",
	VALUE_CAM_OFF = "Désactivés",
	VALUE_CAM_REDUCED = "Réduits",
	VALUE_CAM_FULL = "Complets",
	VALUE_AUTO = "Automatique",
	VALUE_LOW = "Faible",
	VALUE_HIGH = "Élevée",
	VALUE_ULTRA = "Ultra",

	-- Extras / codes de transmission
	EXTRAS_TITLE = "Extras",
	EXTRAS_CODE_TITLE = "Codes de transmission",
	EXTRAS_CODE_HINT = "Les codes sont cachés dans la station. Regarde bien.",
	EXTRAS_CODE_PLACEHOLDER = "Saisir un code",
	EXTRAS_REDEEM = "Transmettre",
	EXTRAS_BALANCE = "Marques de signal : {amount}",
	CODE_OK = "Signal reçu. +{amount} marques de signal.",
	CODE_INVALID = "Rien sur cette fréquence.",
	CODE_USED = "Tu as déjà reçu ce signal.",
	CODE_RATE_LIMITED = "Trop de tentatives. Patiente un instant.",
	CODE_ERROR = "Échec de la transmission. Réessaie plus tard.",

	-- Maintenance (admin)
	ADMIN_GRANTED = "Accès maintenance accordé.",
	ADMIN_TITLE = "Maintenance",
	ADMIN_DEBUG = "Indicateur de performances",
	ADMIN_GRANT_TEST = "Ajouter 100 marques de test",
	ADMIN_DONE = "Terminé.",
	ADMIN_DENIED = "Accès refusé.",

	-- Boutons tactiles
	TOUCH_SPRINT = "Courir",
	TOUCH_LIGHT = "Lampe",

	-- Interactions
	INTERACT_READ = "Lire",
	INTERACT_OPEN = "Ouvrir",
	OBJECT_FAX = "Télécopieur",
	OBJECT_DOOR = "Porte",

	-- Objectifs
	OBJECTIVE_NEW = "Nouvel objectif",
	OBJECTIVE_CHECK_GATEHOUSE = "Inspecte la loge du gardien.",
	OBJECTIVE_FIND_SENDER = "Découvre qui émet.",

	-- Interlocuteurs et sous-titres sonores
	SPEAKER_UNKNOWN = "Voix inconnue",
	SPEAKER_RELAY = "Relais",
	SFX_STATIC = "[Grésillements radio]",
	SFX_FAX = "[Un télécopieur se met à imprimer]",

	-- Chapitre 1 : radio
	RADIO_C1_001 = "...Ici VESPER-4, à quiconque reçoit ce message. Je vous en prie. Quelqu'un est dans le bâtiment.",
	RADIO_C1_002 = "Ils viennent d'arriver. Ils sont devant le portail.",
	RADIO_C1_003 = "Ne répondez pas. Pas encore.",

	-- Chapitre 1 : documents et textes du décor
	DATE_FORMAT = "{d}/{m}/{y}",
	FAX_TITLE = "ORDRE DE MISSION 0214",
	FAX_BODY = "Inspection de la station relais désaffectée VESPER-4.\nMotif : émissions non autorisées sur la bande d'urgence.\nConsigne : ne pas répondre aux appels entrants.\n\nExpéditeur : EXPLOITATION VESPER-4\nEnvoyé le : {date}, 02 h 14",
	DOC_CLOSE = "Fermer",
	SIGN_STATION = "STATION RELAIS VESPER-4\nAccès interdit à toute personne non autorisée",
	NOTE_MAINTENANCE = "MAINTENANCE\nLe canal {code} doit rester libre.\nS'il émet quand même : ne pas répondre.",

	-- Erreurs
	ERROR_DATA = "Ta sauvegarde n'a pas pu être chargée. La progression de cette session ne sera pas enregistrée.",
}
