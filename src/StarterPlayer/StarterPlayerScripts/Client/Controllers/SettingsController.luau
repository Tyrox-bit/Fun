-- SettingsController: local source of truth for player settings.
-- Changes apply instantly on this client and are persisted through the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local SettingsController = {}
SettingsController.Changed = Signal.new() -- (key, value)

local values: { [string]: any } = Config.DefaultSettings()
local updateRemote = Net.Event("UpdateSetting")

function SettingsController.Load(saved: { [string]: any }?)
	for key, value in saved or {} do
		local ok, sanitized = Config.ValidateSetting(key, value)
		if ok then
			values[key] = sanitized
		end
	end
end

function SettingsController.Get(key: string): any
	return values[key]
end

function SettingsController.Set(key: string, value: any): boolean
	local ok, sanitized = Config.ValidateSetting(key, value)
	if not ok then
		return false
	end
	if values[key] == sanitized then
		return true
	end
	values[key] = sanitized
	if key == "language" then
		Localization.SetLanguage(sanitized)
	end
	SettingsController.Changed:Fire(key, sanitized)
	updateRemote:FireServer(key, sanitized)
	return true
end

-- Cycles enum / bool / int settings by delta (+1 / -1). Wraps for enums and bools.
function SettingsController.Step(key: string, delta: number)
	local definition = Config.Settings[key]
	if not definition then
		return
	end
	local current = values[key]
	if definition.kind == "bool" then
		SettingsController.Set(key, not current)
	elseif definition.kind == "enum" then
		local index = table.find(definition.values, current) or 1
		local nextIndex = ((index - 1 + delta) % #definition.values) + 1
		SettingsController.Set(key, definition.values[nextIndex])
	elseif definition.kind == "int" then
		SettingsController.Set(key, math.clamp((current or definition.default) + delta, definition.min, definition.max))
	end
end

-- Display text for a setting value in the current language.
function SettingsController.Describe(key: string): string
	local definition = Config.Settings[key]
	local value = values[key]
	if not definition then
		return ""
	end
	if key == "language" then
		return Config.LanguageNames[value] or ""
	elseif definition.kind == "bool" then
		return Localization.T(if value then "VALUE_ON" else "VALUE_OFF")
	elseif definition.kind == "enum" then
		return Localization.T(definition.labels[value])
	elseif definition.kind == "int" then
		return tostring(value)
	end
	return tostring(value)
end

return SettingsController
