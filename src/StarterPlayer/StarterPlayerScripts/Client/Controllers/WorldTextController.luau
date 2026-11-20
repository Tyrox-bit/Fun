-- WorldTextController: per-player localization of text that lives in the 3D world.
--   * ProximityPrompts tagged "FZ_Prompt" (attributes FZ_Action / FZ_Object)
--   * TextLabels on SurfaceGuis tagged "FZ_WorldText" (attribute LocKey, LocParam_<name>)
-- Text is set locally, so four players can read the same sign in four languages.
-- Works with StreamingEnabled: objects are localized whenever they stream in.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))

local WorldTextController = {}

local function localizePrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local action = prompt:GetAttribute("FZ_Action")
	local object = prompt:GetAttribute("FZ_Object")
	prompt.ActionText = if type(action) == "string" then Localization.T(action) else ""
	prompt.ObjectText = if type(object) == "string" then Localization.T(object) else ""
end

local function localizeText(label: Instance)
	if not label:IsA("TextLabel") then
		return
	end
	local key = label:GetAttribute("LocKey")
	if type(key) ~= "string" then
		return
	end
	local params = {}
	for name, value in label:GetAttributes() do
		local paramName = string.match(name, "^LocParam_(.+)$")
		if paramName then
			params[paramName] = value
		end
	end
	label.AutoLocalize = false
	label.Text = Localization.T(key, params)
end

local function refreshAll()
	for _, prompt in CollectionService:GetTagged("FZ_Prompt") do
		localizePrompt(prompt)
	end
	for _, label in CollectionService:GetTagged("FZ_WorldText") do
		localizeText(label)
	end
end

function WorldTextController.Init()
	CollectionService:GetInstanceAddedSignal("FZ_Prompt"):Connect(localizePrompt)
	CollectionService:GetInstanceAddedSignal("FZ_WorldText"):Connect(localizeText)
	Localization.Changed:Connect(refreshAll)
	refreshAll()
end

return WorldTextController
