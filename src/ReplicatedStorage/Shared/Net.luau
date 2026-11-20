-- Net: declares every remote in one place. The server creates them, clients wait for them.
-- Direction is documented per remote; every client->server remote is validated and
-- rate limited on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "FZ_Remotes"

local EVENTS = {
	"UpdateSetting", -- C->S (key, value)
	"SetFlashlight", -- C->S (enabled)
	"Subtitle", -- S->C (line)
	"Document", -- S->C (document)
	"Notify", -- S->C (key, params)
	"Sfx", -- S->C (soundName, position | instance, volume?)
	"RadioState", -- C->S (transmitting)
	"MicMute", -- C->S (muted)
	"FlashCreature", -- C->S () flashlight cone hits the creature (server validates)
	"MonsterAttack", -- C->S () admin monster mode
	"Footprint", -- S->C (position) observer set only
	"Hurt", -- S->C (amount)
	"MarkSeen", -- C->S (contentId | "update:<id>") NEW badges
}

local FUNCTIONS = {
	"FetchProfile", -- C->S () -> snapshot of settings/progress
	"RedeemCode", -- C->S (code) -> result
	"AdminAction", -- C->S (action, payload) -> result
	"ShopAction", -- C->S (action, itemId) -> result
	"Session", -- C->S (action, mode, contentId) -> result
	"GetLeaderboard", -- C->S (survivalId) -> top entries
}

local Net = {}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			folder = existing
		else
			local created = Instance.new("Folder")
			created.Name = FOLDER_NAME
			for _, name in EVENTS do
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = created
			end
			for _, name in FUNCTIONS do
				local remote = Instance.new("RemoteFunction")
				remote.Name = name
				remote.Parent = created
			end
			created.Parent = ReplicatedStorage
			folder = created
		end
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end
	return folder :: Folder
end

function Net.Event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), "[FZ-Net] Unknown RemoteEvent: " .. name)
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	assert(table.find(FUNCTIONS, name), "[FZ-Net] Unknown RemoteFunction: " .. name)
	return getFolder():WaitForChild(name) :: RemoteFunction
end

-- Call on the server before any client can need the remotes.
function Net.Init()
	getFolder()
end

return Net
