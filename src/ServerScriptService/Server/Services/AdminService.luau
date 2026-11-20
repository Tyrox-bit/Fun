-- AdminService: server-side authorization and audit log for maintenance tools.
--
-- Security model:
--   1. IsAuthorized() checks UserId / ownership on the server (cached per session).
--   2. The gesture code is read from ServerStorage at runtime (attribute
--      "FZ_AdminGesture", set by the owner in Studio, NOT committed to git). It only
--      unlocks the hidden menu entry for authorized players.
--   3. Every admin remote call re-checks authorization; the client-visible attribute
--      FZ_Admin is only a UI hint and is never trusted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local AdminConfig = require(script.Parent.Parent.AdminConfig)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local AdminService = {}

local authorizedCache: { [Player]: boolean } = {}
local unlocked: { [Player]: boolean } = {}
local auditLog: { { time: number, userId: number, name: string, action: string, detail: string } } = {}
local MAX_LOG = 200

function AdminService.Log(player: Player, action: string, detail: string?)
	local entry = {
		time = os.time(),
		userId = player.UserId,
		name = player.Name,
		action = action,
		detail = detail or "",
	}
	table.insert(auditLog, entry)
	if #auditLog > MAX_LOG then
		table.remove(auditLog, 1)
	end
	print(string.format("[FZ-ADMIN] %s (%d) %s %s", entry.name, entry.userId, action, entry.detail))
end

function AdminService.IsAuthorized(player: Player): boolean
	local cached = authorizedCache[player]
	if cached ~= nil then
		return cached
	end
	local authorized = false
	local certain = true
	if RunService:IsStudio() and AdminConfig.AllowAllInStudio then
		authorized = true
	elseif table.find(AdminConfig.UserIds, player.UserId) then
		authorized = true
	elseif game.CreatorType == Enum.CreatorType.User then
		authorized = player.UserId == game.CreatorId
	elseif game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		if ok then
			authorized = rank >= AdminConfig.MinGroupRank
		else
			certain = false -- web call failed: do not cache a false negative
		end
	end
	if certain then
		authorizedCache[player] = authorized
	end
	return authorized
end

function AdminService.MatchesGesture(normalizedCode: string): boolean
	local gesture = ServerStorage:GetAttribute("FZ_AdminGesture")
	if type(gesture) ~= "string" or #gesture < 6 then
		return false
	end
	return string.upper(gesture) == normalizedCode
end

function AdminService.Unlock(player: Player)
	unlocked[player] = true
	player:SetAttribute("FZ_Admin", true)
	AdminService.Log(player, "unlock")
end

local function isAllowed(player: Player): boolean
	return unlocked[player] == true and AdminService.IsAuthorized(player)
end

local ACTIONS = {}

ACTIONS.grant_test_marks = function(player: Player)
	local ok = DataService.Mutate(player, function(data)
		data.signalMarks += 100
	end)
	return { ok = ok }
end

-- World tools. Anything that can affect other players is limited to Studio and private
-- servers, so admins can never harass or break public sessions.
local function isTestServer(): boolean
	return RunService:IsStudio() or game.PrivateServerId ~= ""
end

local function lazy(name: string)
	return require(script.Parent[name])
end

ACTIONS.spawn_creature = function(player: Player)
	if not isTestServer() then
		return { ok = false, reason = "public" }
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return { ok = false }
	end
	local cf = root.CFrame * CFrame.new(0, 3, -18)
	lazy("CreatureService").Spawn(CFrame.lookAt(cf.Position, root.Position * Vector3.new(1, 0, 1) + Vector3.new(0, cf.Position.Y, 0)))
	return { ok = true }
end

ACTIONS.toggle_ai = function()
	local creatures = lazy("CreatureService")
	creatures.SetAIEnabled(not creatures.IsAIEnabled())
	return { ok = true, enabled = creatures.IsAIEnabled() }
end

ACTIONS.play_creature = function(player: Player)
	if not isTestServer() then
		return { ok = false, reason = "public" }
	end
	local Rig = require(script.Parent.Parent.Creature.Rig)
	local old = player.Character
	local pivot = if old then old:GetPivot() else CFrame.new(0, 10, 0)
	local model = Rig.Create()
	model.Name = player.Name
	model:PivotTo(pivot + Vector3.new(0, 4, 0))
	player:SetAttribute("FZ_MonsterMode", true)
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 10
	player.CameraMaxZoomDistance = 18
	model.Parent = workspace
	Rig.Tag(model)
	player.Character = model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 14
	end
	if old then
		old:Destroy()
	end
	return { ok = true }
end

ACTIONS.play_human = function(player: Player)
	player:SetAttribute("FZ_MonsterMode", false)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	player:LoadCharacter()
	return { ok = true }
end

ACTIONS.tp_core = function(player: Player)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(0, 4, 32))
	end
	return { ok = true }
end

ACTIONS.toggle_speed = function(player: Player)
	player:SetAttribute("FZ_AdminSpeed", not player:GetAttribute("FZ_AdminSpeed"))
	return { ok = true }
end

ACTIONS.reset = function()
	lazy("GameFlowService").ResetChapter()
	lazy("HealthService").HealAll()
	lazy("DoorService").CloseAll()
	return { ok = true }
end

ACTIONS.get_log = function()
	local recent = {}
	for i = math.max(1, #auditLog - 19), #auditLog do
		table.insert(recent, auditLog[i])
	end
	return { ok = true, log = recent }
end

function AdminService.Start()
	if type(ServerStorage:GetAttribute("FZ_AdminGesture")) ~= "string" then
		warn("[FZ-ADMIN] No gesture configured. Set the string attribute 'FZ_AdminGesture' on ServerStorage (min. 6 characters) to enable the hidden maintenance entry.")
	end

	local limiter = RateLimiter.new(10, 1)
	Net.Function("AdminAction").OnServerInvoke = function(player: Player, action: any, _payload: any)
		if not limiter:Allow(player) then
			return { ok = false, reason = "rate_limited" }
		end
		if type(action) ~= "string" or not isAllowed(player) then
			AdminService.Log(player, "denied", tostring(action))
			return { ok = false, reason = "denied" }
		end
		local handler = ACTIONS[action]
		if not handler then
			return { ok = false, reason = "unknown" }
		end
		AdminService.Log(player, action)
		return handler(player)
	end

	-- Monster mode attack: same telegraphed damage as the AI, test servers only.
	local attackLimiter = RateLimiter.new(1, 0.6)
	Net.Event("MonsterAttack").OnServerEvent:Connect(function(player: Player)
		if not player:GetAttribute("FZ_MonsterMode") or not isAllowed(player) or not isTestServer() or not attackLimiter:Allow(player) then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local creatureConfig = require(ReplicatedStorage.Shared.Config).Creature
		player.Character:SetAttribute("State", "Attack")
		task.delay(creatureConfig.AttackWindup, function()
			if not player.Character then
				return
			end
			player.Character:SetAttribute("State", "Chase")
			for _, other in Players:GetPlayers() do
				local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if otherRoot and (otherRoot.Position - root.Position).Magnitude <= creatureConfig.AttackRange + 1.5 then
					lazy("HealthService").Damage(other, creatureConfig.Damage)
				end
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		authorizedCache[player] = nil
		unlocked[player] = nil
	end)
end

return AdminService
