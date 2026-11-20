-- LocalizationManager
-- Our own, fully controlled translation layer. Roblox auto-translation is disabled on every
-- text object that is bound through this module (AutoLocalize = false), so a player never
-- sees machine-translated or mixed-language game text.
--
-- Usage:
--   Localization.T("MENU_PLAY")                         -> "Spielen"
--   Localization.T("CODE_OK", { amount = 25 })          -> "... +25 ..."
--   Localization.Bind(label, "MENU_PLAY")               -> label.Text stays in sync on language change
--   Localization.Bind(box, "EXTRAS_CODE_PLACEHOLDER", nil, "PlaceholderText")

local Config = require(script.Parent.Config)
local Signal = require(script.Parent.Signal)

local Localization = {}
Localization.Changed = Signal.new()

local tables: { [string]: { [string]: string } } = {}
local languageFolder = script:WaitForChild("Languages")
for _, code in Config.Languages do
	local moduleName = (string.gsub(code, "-", "_"))
	local module = languageFolder:FindFirstChild(moduleName)
	if module then
		tables[code] = require(module)
	else
		warn("[FZ-Loc] Missing language module: " .. moduleName)
	end
end
assert(tables[Config.FallbackLanguage], "[FZ-Loc] Fallback language table is required")

local current = Config.FallbackLanguage
local reported: { [string]: boolean } = {}

-- object -> { [property]: { key, params } }
-- Strong references on purpose: Instance wrappers in weak tables can be collected while the
-- Instance still exists. Entries are removed when the object is destroyed.
local bindings: { [Instance]: { [string]: { key: string, params: { [string]: any }? } } } = {}

local function report(language: string, key: string)
	local id = language .. ":" .. key
	if reported[id] then
		return
	end
	reported[id] = true
	warn(string.format("[FZ-Loc] Missing translation '%s' for language '%s'", key, language))
end

local function format(text: string, params: { [string]: any }?): string
	if not params then
		return text
	end
	return (string.gsub(text, "{([%w_]+)}", function(name)
		local value = params[name]
		if value == nil then
			return "{" .. name .. "}"
		end
		return tostring(value)
	end))
end

function Localization.T(key: string, params: { [string]: any }?, language: string?): string
	local lang = language or current
	local languageTable = tables[lang]
	local text = languageTable and languageTable[key]
	if text == nil then
		if lang ~= Config.FallbackLanguage then
			report(lang, key)
		end
		text = tables[Config.FallbackLanguage][key]
		if text == nil then
			report(Config.FallbackLanguage, key)
			return key
		end
	end
	return format(text, params)
end

function Localization.Has(key: string): boolean
	return tables[Config.FallbackLanguage][key] ~= nil
end

function Localization.GetLanguage(): string
	return current
end

function Localization.IsSupported(language: any): boolean
	return type(language) == "string" and tables[language] ~= nil
end

-- Maps a Roblox locale id ("de-de", "pt-br", "es-mx") to one of our languages, or nil.
function Localization.Detect(localeId: string?): string?
	local id = string.lower(localeId or "")
	if tables[id] then
		return id
	end
	local base = string.match(id, "^(%a+)")
	if base == "pt" then
		return "pt-br"
	end
	if base and tables[base] then
		return base
	end
	return nil
end

local function applyBinding(object: Instance, property: string, entry)
	(object :: any)[property] = Localization.T(entry.key, entry.params)
end

function Localization.Bind(object: Instance, key: string, params: { [string]: any }?, property: string?)
	local prop = property or "Text"
	if object:IsA("GuiBase2d") then
		(object :: any).AutoLocalize = false
	end
	local objectBindings = bindings[object]
	if not objectBindings then
		objectBindings = {}
		bindings[object] = objectBindings
		object.Destroying:Connect(function()
			bindings[object] = nil
		end)
	end
	local entry = { key = key, params = params }
	objectBindings[prop] = entry
	applyBinding(object, prop, entry)
end

function Localization.Unbind(object: Instance)
	bindings[object] = nil
end

function Localization.SetLanguage(language: string): boolean
	if not tables[language] then
		return false
	end
	if language == current then
		return true
	end
	current = language
	-- Update everything synchronously in the same frame: no flicker, no mixed languages.
	for object, objectBindings in bindings do
		for prop, entry in objectBindings do
			applyBinding(object, prop, entry)
		end
	end
	Localization.Changed:Fire(language)
	return true
end

-- Development check: returns a list of human readable problems (missing keys, extra keys,
-- mismatching {placeholders}). Run automatically in Studio by the client bootstrap.
function Localization.Validate(): { string }
	local problems = {}
	local reference = tables[Config.FallbackLanguage]
	local function placeholders(text: string): string
		local found = {}
		for name in string.gmatch(text, "{([%w_]+)}") do
			table.insert(found, name)
		end
		table.sort(found)
		return table.concat(found, ",")
	end
	for language, languageTable in tables do
		if language == Config.FallbackLanguage then
			continue
		end
		for key, text in reference do
			local translated = languageTable[key]
			if translated == nil then
				table.insert(problems, string.format("%s: missing %s", language, key))
			elseif placeholders(translated) ~= placeholders(text) then
				table.insert(problems, string.format("%s: placeholder mismatch in %s", language, key))
			end
		end
		for key in languageTable do
			if reference[key] == nil then
				table.insert(problems, string.format("%s: extra key %s (not in %s)", language, key, Config.FallbackLanguage))
			end
		end
	end
	return problems
end

return Localization
