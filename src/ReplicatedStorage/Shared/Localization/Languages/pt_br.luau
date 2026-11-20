-- Português (Brasil)
return {
	-- Escolha de idioma
	LANG_PROMPT = "Escolha seu idioma",
	LANG_SUGGESTED = "Sugerido",
	LANG_HINT = "Você pode mudar isso a qualquer momento nas Configurações.",

	-- Menu principal
	MENU_PLAY = "Jogar",
	MENU_CONTINUE = "Continuar",
	MENU_RESUME = "Voltar ao jogo",
	MENU_LOBBY = "Equipe",
	MENU_CHAPTERS = "Capítulos",
	MENU_SETTINGS = "Configurações",
	MENU_EXTRAS = "Extras",
	MENU_BACK = "Voltar",
	MENU_TAGLINE = "Alguém ainda está transmitindo.",
	PAUSE_TITLE = "Menu",
	PAUSE_NOTE = "A estação não espera enquanto este menu está aberto.",

	-- Equipe
	LOBBY_TITLE = "Equipe",
	LOBBY_COUNT = "{count} / {max} nesta sessão",
	LOBBY_INVITE = "Convidar amigos",
	LOBBY_INVITE_UNAVAILABLE = "Os convites não estão disponíveis no momento.",
	LOBBY_SOLO_HINT = "Tudo pode ser jogado sozinho. Seus amigos podem entrar a qualquer momento.",
	LOBBY_YOU = "(você)",

	-- Capítulos
	CHAPTER_LABEL = "Capítulo {number}",
	CHAPTER_01_TITLE = "A Recepção",
	CHAPTER_02_TITLE = "A Voz Errada",
	CHAPTER_03_TITLE = "O Protocolo",
	CHAPTER_04_TITLE = "Frequência Zero",
	CHAPTER_LOCKED = "Ainda sem sinal",

	-- Configurações
	SETTINGS_TITLE = "Configurações",
	SETTINGS_LANGUAGE = "Idioma",
	SETTINGS_SUBTITLES = "Legendas",
	SETTINGS_SUBTITLE_SIZE = "Tamanho das legendas",
	SETTINGS_SCARE = "Intensidade dos sustos",
	SETTINGS_SCARE_DESC = "“Reduzida” suaviza os sustos repentinos. A história continua a mesma.",
	SETTINGS_CAMERA = "Efeitos de câmera",
	SETTINGS_CAMERA_DESC = "Tremor de câmera, mudanças no campo de visão e distorção da imagem.",
	SETTINGS_GRAPHICS = "Gráficos",
	SETTINGS_GRAPHICS_DESC = "Pistas importantes e criaturas continuam visíveis em todos os níveis.",
	SETTINGS_BRIGHTNESS = "Brilho",
	SETTINGS_BRIGHTNESS_DESC = "Aumente se as salas escuras estiverem difíceis de enxergar na sua tela.",
	VALUE_ON = "Ligadas",
	VALUE_OFF = "Desligadas",
	VALUE_SMALL = "Pequeno",
	VALUE_MEDIUM = "Médio",
	VALUE_LARGE = "Grande",
	VALUE_REDUCED = "Reduzida",
	VALUE_STANDARD = "Padrão",
	VALUE_INTENSE = "Intensa",
	VALUE_CAM_OFF = "Desligados",
	VALUE_CAM_REDUCED = "Reduzidos",
	VALUE_CAM_FULL = "Completos",
	VALUE_AUTO = "Automático",
	VALUE_LOW = "Baixo",
	VALUE_HIGH = "Alto",
	VALUE_ULTRA = "Ultra",

	-- Extras / códigos de transmissão
	EXTRAS_TITLE = "Extras",
	EXTRAS_CODE_TITLE = "Códigos de transmissão",
	EXTRAS_CODE_HINT = "Os códigos estão escondidos na estação. Olhe com atenção.",
	EXTRAS_CODE_PLACEHOLDER = "Digite um código",
	EXTRAS_REDEEM = "Transmitir",
	EXTRAS_BALANCE = "Marcas de sinal: {amount}",
	CODE_OK = "Sinal recebido. +{amount} marcas de sinal.",
	CODE_INVALID = "Não há nada nesta frequência.",
	CODE_USED = "Você já recebeu este sinal.",
	CODE_RATE_LIMITED = "Tentativas demais. Espere um momento.",
	CODE_ERROR = "A transmissão falhou. Tente novamente mais tarde.",

	-- Manutenção (admin)
	ADMIN_GRANTED = "Acesso de manutenção liberado.",
	ADMIN_TITLE = "Manutenção",
	ADMIN_DEBUG = "Indicador de desempenho",
	ADMIN_GRANT_TEST = "Adicionar 100 marcas de teste",
	ADMIN_DONE = "Pronto.",
	ADMIN_DENIED = "Acesso negado.",

	-- Botões de toque
	TOUCH_SPRINT = "Correr",
	TOUCH_LIGHT = "Luz",

	-- Interações
	INTERACT_READ = "Ler",
	INTERACT_OPEN = "Abrir",
	OBJECT_FAX = "Fax",
	OBJECT_DOOR = "Porta",

	-- Objetivos
	OBJECTIVE_NEW = "Novo objetivo",
	OBJECTIVE_CHECK_GATEHOUSE = "Verifique a guarita.",
	OBJECTIVE_FIND_SENDER = "Descubra quem está transmitindo.",

	-- Falantes e legendas de som
	SPEAKER_UNKNOWN = "Voz desconhecida",
	SPEAKER_RELAY = "Relé",
	SFX_STATIC = "[Chiado de rádio]",
	SFX_FAX = "[Um fax começa a imprimir]",

	-- Capítulo 1: rádio
	RADIO_C1_001 = "...VESPER-4 para quem estiver na escuta. Por favor. Tem alguém dentro do prédio.",
	RADIO_C1_002 = "Eles acabaram de chegar. Estão no portão.",
	RADIO_C1_003 = "Não respondam. Ainda não.",

	-- Capítulo 1: documentos e textos do cenário
	DATE_FORMAT = "{d}/{m}/{y}",
	FAX_TITLE = "ORDEM DE SERVIÇO 0214",
	FAX_BODY = "Inspeção da estação repetidora desativada VESPER-4.\nMotivo: transmissões não autorizadas na faixa de emergência.\nInstrução: não responder a chamadas recebidas.\n\nRemetente: OPERAÇÕES VESPER-4\nEnviado em: {date}, 02:14",
	DOC_CLOSE = "Fechar",
	SIGN_STATION = "ESTAÇÃO REPETIDORA VESPER-4\nEntrada proibida a pessoas não autorizadas",
	NOTE_MAINTENANCE = "MANUTENÇÃO\nO canal {code} deve ficar livre.\nSe transmitir mesmo assim: não respondam.",

	-- Erros
	ERROR_DATA = "Não foi possível carregar seu progresso salvo. O progresso desta sessão não será salvo.",
}
