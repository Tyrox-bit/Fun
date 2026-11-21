-- FREQUENCY ZERO - server bootstrap.
-- Order matters: remotes and shared state first, then data, then gameplay services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Net).Init()
require(Shared.SessionState).Init()

local SERVICES = {
	"DataService",
	"MapService",
	"SettingsService",
	"AdminService",
	"CodeService",
	"InteractionService",
	"NoiseService",
	"DoorService",
	"PowerService",
	"HealthService",
	"InventoryService",
	"VoiceService",
	"ShopService",
	"CreatureService",
	"FlashlightService",
	"LeaderboardService",
	"DecisionService",
	"DirectorService",
	"PlaceService",
	"SessionService",
}

for _, name in SERVICES do
	local module = script.Parent.Services:FindFirstChild(name)
	local ok, err = pcall(function()
		local service = require(module)
		if name == "PowerService" then
			service.Start(require(script.Parent.Services.DoorService))
		else
			service.Start()
		end
	end)
	if not ok then
		warn(string.format("[FZ] %s failed to start: %s", name, tostring(err)))
	end
end

print("[FZ] Server ready")
