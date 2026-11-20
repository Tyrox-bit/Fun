-- Español (neutro latinoamericano: "tú" para el jugador, "ustedes" para el equipo)
return {
	-- Selección de idioma
	LANG_PROMPT = "Elige tu idioma",
	LANG_SUGGESTED = "Sugerido",
	LANG_HINT = "Puedes cambiarlo cuando quieras en Ajustes.",

	-- Menú principal
	MENU_PLAY = "Jugar",
	MENU_CONTINUE = "Continuar",
	MENU_RESUME = "Volver",
	MENU_LOBBY = "Equipo",
	MENU_CHAPTERS = "Capítulos",
	MENU_SETTINGS = "Ajustes",
	MENU_EXTRAS = "Extras",
	MENU_BACK = "Atrás",
	MENU_TAGLINE = "Alguien sigue transmitiendo.",
	PAUSE_TITLE = "Menú",
	PAUSE_NOTE = "La estación no espera mientras este menú está abierto.",

	-- Equipo
	LOBBY_TITLE = "Equipo",
	LOBBY_COUNT = "{count} / {max} en esta sesión",
	LOBBY_INVITE = "Invitar amigos",
	LOBBY_INVITE_UNAVAILABLE = "Las invitaciones no están disponibles ahora.",
	LOBBY_SOLO_HINT = "Todo se puede jugar en solitario. Tus amigos pueden unirse en cualquier momento.",
	LOBBY_YOU = "(tú)",

	-- Capítulos
	CHAPTER_LABEL = "Capítulo {number}",
	CHAPTER_01_TITLE = "La recepción",
	CHAPTER_02_TITLE = "La voz equivocada",
	CHAPTER_03_TITLE = "El protocolo",
	CHAPTER_04_TITLE = "Frecuencia cero",
	CHAPTER_LOCKED = "Todavía sin señal",

	-- Ajustes
	SETTINGS_TITLE = "Ajustes",
	SETTINGS_LANGUAGE = "Idioma",
	SETTINGS_SUBTITLES = "Subtítulos",
	SETTINGS_SUBTITLE_SIZE = "Tamaño de subtítulos",
	SETTINGS_SCARE = "Intensidad de sustos",
	SETTINGS_SCARE_DESC = "«Reducida» suaviza los sustos repentinos. La historia no cambia.",
	SETTINGS_CAMERA = "Efectos de cámara",
	SETTINGS_CAMERA_DESC = "Temblor de cámara, cambios del campo de visión y distorsión de imagen.",
	SETTINGS_GRAPHICS = "Gráficos",
	SETTINGS_GRAPHICS_DESC = "Las pistas importantes y las criaturas siguen visibles en todos los niveles.",
	SETTINGS_BRIGHTNESS = "Brillo",
	SETTINGS_BRIGHTNESS_DESC = "Súbelo si te cuesta distinguir las salas oscuras en tu pantalla.",
	VALUE_ON = "Sí",
	VALUE_OFF = "No",
	VALUE_SMALL = "Pequeño",
	VALUE_MEDIUM = "Medio",
	VALUE_LARGE = "Grande",
	VALUE_REDUCED = "Reducida",
	VALUE_STANDARD = "Estándar",
	VALUE_INTENSE = "Intensa",
	VALUE_CAM_OFF = "Desactivados",
	VALUE_CAM_REDUCED = "Reducidos",
	VALUE_CAM_FULL = "Completos",
	VALUE_AUTO = "Automático",
	VALUE_LOW = "Bajo",
	VALUE_HIGH = "Alto",
	VALUE_ULTRA = "Ultra",

	-- Extras / códigos de transmisión
	EXTRAS_TITLE = "Extras",
	EXTRAS_CODE_TITLE = "Códigos de transmisión",
	EXTRAS_CODE_HINT = "Los códigos están escondidos en la estación. Mira con atención.",
	EXTRAS_CODE_PLACEHOLDER = "Introduce un código",
	EXTRAS_REDEEM = "Transmitir",
	EXTRAS_BALANCE = "Marcas de señal: {amount}",
	CODE_OK = "Señal recibida. +{amount} marcas de señal.",
	CODE_INVALID = "No hay nada en esta frecuencia.",
	CODE_USED = "Ya recibiste esta señal.",
	CODE_RATE_LIMITED = "Demasiados intentos. Espera un momento.",
	CODE_ERROR = "La transmisión falló. Inténtalo más tarde.",

	-- Mantenimiento (admin)
	ADMIN_GRANTED = "Acceso de mantenimiento concedido.",
	ADMIN_TITLE = "Mantenimiento",
	ADMIN_DEBUG = "Indicador de rendimiento",
	ADMIN_GRANT_TEST = "Añadir 100 marcas de prueba",
	ADMIN_DONE = "Hecho.",
	ADMIN_DENIED = "Acceso denegado.",

	-- Botones táctiles
	TOUCH_SPRINT = "Correr",
	TOUCH_LIGHT = "Luz",

	-- Interacciones
	INTERACT_READ = "Leer",
	INTERACT_OPEN = "Abrir",
	OBJECT_FAX = "Fax",
	OBJECT_DOOR = "Puerta",

	-- Objetivos
	OBJECTIVE_NEW = "Nuevo objetivo",
	OBJECTIVE_CHECK_GATEHOUSE = "Revisa la caseta de vigilancia.",
	OBJECTIVE_FIND_SENDER = "Descubre quién está transmitiendo.",

	-- Hablantes y subtítulos de sonido
	SPEAKER_UNKNOWN = "Voz desconocida",
	SPEAKER_RELAY = "Relé",
	SFX_STATIC = "[Estática de radio]",
	SFX_FAX = "[Un fax empieza a imprimir]",

	-- Capítulo 1: radio
	RADIO_C1_001 = "...VESPER-4 a quien esté escuchando. Por favor. Hay alguien dentro del edificio.",
	RADIO_C1_002 = "Acaban de llegar. Están en el portón.",
	RADIO_C1_003 = "No respondan. Todavía no.",

	-- Capítulo 1: documentos y textos del mundo
	DATE_FORMAT = "{d}/{m}/{y}",
	FAX_TITLE = "ORDEN DE TRABAJO 0214",
	FAX_BODY = "Inspección de la estación repetidora clausurada VESPER-4.\nMotivo: transmisiones no autorizadas en la banda de emergencia.\nInstrucción: no responder a las llamadas entrantes.\n\nRemitente: OPERACIONES VESPER-4\nEnviado: {date}, 02:14",
	DOC_CLOSE = "Cerrar",
	SIGN_STATION = "ESTACIÓN REPETIDORA VESPER-4\nProhibido el paso a personal no autorizado",
	NOTE_MAINTENANCE = "MANTENIMIENTO\nEl canal {code} debe quedar libre.\nSi transmite de todos modos: no respondan.",

	-- Errores
	ERROR_DATA = "No se pudo cargar tu partida. El progreso de esta sesión no se guardará.",
}
