-- SettingsService: persists player settings (language, subtitles, accessibility, graphics).
-- Settings are not security relevant, but are still validated against the shared schema
-- so a manipulated client can never write garbage into the save.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local AnalyticsTracker = require(script.Parent.AnalyticsTracker)

local SettingsService = {}

function SettingsService.Start()
	local limiter = RateLimiter.new(20, 5)
	Net.Event("UpdateSetting").OnServerEvent:Connect(function(player: Player, key: any, value: any)
		if not limiter:Allow(player) then
			return
		end
		local ok, sanitized = Config.ValidateSetting(key, value)
		if not ok then
			return
		end
		DataService.Mutate(player, function(data)
			data.settings[key] = sanitized
		end)
		if key == "language" and player:GetAttribute("FZ_NewPlayer") then
			AnalyticsTracker.Onboarding(player, 2, "LanguageChosen")
		end
	end)
end

return SettingsService
