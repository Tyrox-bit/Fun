-- FREQUENCY ZERO - server bootstrap.
-- Order matters: remotes and shared state first, then data, then gameplay services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Net).Init()
require(Shared.SessionState).Init()

if not workspace:FindFirstChild("FZ_Map") then
	require(script.Parent.Dev.Greybox).Build()
end

local SERVICES = {
	"DataService",
	"SettingsService",
	"AdminService",
	"CodeService",
	"InteractionService",
	"FlashlightService",
	"GameFlowService",
}

for _, name in SERVICES do
	local module = script.Parent.Services:FindFirstChild(name)
	local ok, err = pcall(function()
		require(module).Start()
	end)
	if not ok then
		warn(string.format("[FZ] %s failed to start: %s", name, tostring(err)))
	end
end

print("[FZ] Server ready")
