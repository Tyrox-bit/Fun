-- InteractionService: one interaction system for every platform.
--
-- Level designers tag an object (BasePart, Model or Attachment) with "FZ_Interactable"
-- and set attributes:
--   InteractId   (string, required) handler id registered by a chapter module
--   ActionKey    (string) localization key for the verb, e.g. "INTERACT_READ"
--   ObjectKey    (string) localization key for the object, e.g. "OBJECT_FAX"
--   HoldDuration (number, optional) seconds to hold
--   MaxDistance  (number, optional) default 8 studs
--
-- A ProximityPrompt is generated automatically. ProximityPrompts give us keyboard (E),
-- gamepad (X / Square) and touch (tap) with the same logical action for free.
-- Text is localized per player on the client (prompts are tagged "FZ_Prompt").
-- The server validates distance and rate-limits every trigger.

local CollectionService = game:GetService("CollectionService")

local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local AnalyticsTracker = require(script.Parent.AnalyticsTracker)

local TAG = "FZ_Interactable"
local PROMPT_TAG = "FZ_Prompt"
local DISTANCE_TOLERANCE = 6

local InteractionService = {}

type Handler = (player: Player, instance: Instance, prompt: ProximityPrompt) -> ()
local handlers: { [string]: { Handler } } = {}
local limiter = RateLimiter.new(6, 3)

-- Several modes may handle the same object (e.g. the relay panel is used by chapter 1
-- and by survival). Every handler checks itself whether its mode is active.
function InteractionService.Register(id: string, handler: Handler)
	handlers[id] = handlers[id] or {}
	table.insert(handlers[id], handler)
end

local function worldPosition(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	end
	return nil
end

local function onTriggered(player: Player, instance: Instance, prompt: ProximityPrompt)
	if not limiter:Allow(player) or not prompt.Enabled then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local position = worldPosition(instance)
	if not position or ((root :: BasePart).Position - position).Magnitude > prompt.MaxActivationDistance + DISTANCE_TOLERANCE then
		return
	end
	local id = instance:GetAttribute("InteractId")
	local list = if type(id) == "string" then handlers[id] else nil
	if not list then
		warn("[FZ-Interact] No handler for InteractId " .. tostring(id) .. " on " .. instance:GetFullName())
		return
	end
	if player:GetAttribute("FZ_NewPlayer") then
		AnalyticsTracker.Onboarding(player, 4, "FirstInteraction")
	end
	for _, handler in list do
		local ok, err = pcall(handler, player, instance, prompt)
		if not ok then
			warn("[FZ-Interact] Handler " .. id .. " failed: " .. tostring(err))
		end
	end
end

local function setup(instance: Instance)
	if not worldPosition(instance) then
		warn("[FZ-Interact] Unsupported interactable: " .. instance:GetFullName())
		return
	end
	local prompt = instance:FindFirstChild("FZ_Prompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FZ_Prompt"
		prompt.Parent = instance
	end
	local p = prompt :: ProximityPrompt
	p.ActionText = "" -- localized on each client
	p.ObjectText = ""
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = tonumber(instance:GetAttribute("HoldDuration")) or 0
	p.MaxActivationDistance = tonumber(instance:GetAttribute("MaxDistance")) or 8
	p.RequiresLineOfSight = true
	p.Style = Enum.ProximityPromptStyle.Custom -- drawn by PromptController (all devices)
	p:SetAttribute("FZ_Action", instance:GetAttribute("ActionKey"))
	p:SetAttribute("FZ_Object", instance:GetAttribute("ObjectKey"))
	CollectionService:AddTag(p, PROMPT_TAG)
	p.Triggered:Connect(function(player)
		onTriggered(player, instance, p)
	end)
end

function InteractionService.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(setup)
	for _, instance in CollectionService:GetTagged(TAG) do
		setup(instance)
	end
end

return InteractionService
