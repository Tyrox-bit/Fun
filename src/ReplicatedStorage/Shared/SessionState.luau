-- SessionState: session-wide story state (shared by the whole team in this server).
-- Stored as attributes on ReplicatedStorage.FZ_State, so late joiners automatically
-- receive the current state without any extra remote calls or race conditions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "FZ_State"

local SessionState = {}

local cached: Folder? = nil

local function getFolder(): Folder
	if cached then
		return cached
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not existing then
			existing = Instance.new("Folder")
			existing.Name = FOLDER_NAME
			existing.Parent = ReplicatedStorage
		end
		cached = existing :: Folder
	else
		cached = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end
	return cached :: Folder
end

function SessionState.Get(key: string): any
	return getFolder():GetAttribute(key)
end

function SessionState.Set(key: string, value: any)
	assert(RunService:IsServer(), "SessionState.Set is server-only")
	getFolder():SetAttribute(key, value)
end

-- Calls callback immediately with the current value and again on every change.
function SessionState.Observe(key: string, callback: (any) -> ()): RBXScriptConnection
	local folder = getFolder()
	task.spawn(callback, folder:GetAttribute(key))
	return folder:GetAttributeChangedSignal(key):Connect(function()
		callback(folder:GetAttribute(key))
	end)
end

function SessionState.Init()
	getFolder()
end

return SessionState
