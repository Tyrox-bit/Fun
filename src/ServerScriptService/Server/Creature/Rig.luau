-- Creature rig factory.
--
-- 1. Your own monster: put a Model into ServerStorage > Creatures. Requirements:
--    Humanoid + HumanoidRootPart (PrimaryPart), anchored = false, correct HipHeight.
--    Optional animation ids in Shared/Assets.luau (CreatureAnimations).
-- 2. Otherwise the built-in placeholder "Der Lauscher" is built from parts:
--    ~8.5 studs tall, very thin, horn-speaker head, arms down to the knees.
--    It is animated procedurally on the clients (CreatureVisualsController) by
--    driving Motor6D.Transform - no animation assets needed.

local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Rig = {}

local SKIN = Color3.fromRGB(58, 52, 50)
local SKIN_DARK = Color3.fromRGB(34, 30, 30)
local FABRIC = Color3.fromRGB(24, 22, 22)

local function part(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = collide == true
	p.CanQuery = true
	p.CanTouch = false
	p.Massless = not collide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	return m
end

function Rig.BuildPlaceholder(): Model
	local model = Instance.new("Model")
	model.Name = "Lauscher"

	local root = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), SKIN, Enum.Material.SmoothPlastic, true)
	root.Transparency = 1
	model.PrimaryPart = root

	local torso = part(model, "Torso", Vector3.new(1.3, 3.2, 0.8), SKIN, Enum.Material.Fabric, true)
	local head = part(model, "Head", Vector3.new(1.3, 1.3, 1.6), SKIN_DARK, Enum.Material.Metal)
	local horn = part(model, "Horn", Vector3.new(0.4, 2.1, 2.1), SKIN_DARK, Enum.Material.Metal)
	horn.Shape = Enum.PartType.Cylinder
	local grille = part(model, "Grille", Vector3.new(0.12, 1.9, 1.9), FABRIC, Enum.Material.Fabric)
	grille.Shape = Enum.PartType.Cylinder

	motor("RootJoint", root, torso, CFrame.new(0, -1, 0), CFrame.new(0, -1.6, 0) * CFrame.Angles(math.rad(-12), 0, 0))
	motor("Neck", torso, head, CFrame.new(0, 1.6, 0), CFrame.new(0, -0.7, 0.2))
	-- Horn faces forward (-Z). Cylinders extend along X, so rotate 90 degrees around Y.
	local hornWeld = Instance.new("Weld")
	hornWeld.Part0 = head
	hornWeld.Part1 = horn
	hornWeld.C0 = CFrame.new(0, 0, -0.9) * CFrame.Angles(0, math.rad(90), 0)
	hornWeld.Parent = head
	local grilleWeld = Instance.new("Weld")
	grilleWeld.Part0 = head
	grilleWeld.Part1 = grille
	grilleWeld.C0 = CFrame.new(0, 0, -1.12) * CFrame.Angles(0, math.rad(90), 0)
	grilleWeld.Parent = head

	for _, side in { { "Left", -1 }, { "Right", 1 } } do
		local name, s = side[1], side[2]
		local upperArm = part(model, name .. "UpperArm", Vector3.new(0.35, 3.2, 0.35), SKIN, Enum.Material.Fabric)
		local lowerArm = part(model, name .. "LowerArm", Vector3.new(0.3, 3.4, 0.3), SKIN, Enum.Material.Fabric)
		local hand = part(model, name .. "Hand", Vector3.new(0.5, 1.1, 0.25), SKIN_DARK, Enum.Material.Fabric)
		motor(name .. "Shoulder", torso, upperArm, CFrame.new(s * 0.85, 1.3, 0), CFrame.new(0, 1.6, 0))
		motor(name .. "Elbow", upperArm, lowerArm, CFrame.new(0, -1.6, 0), CFrame.new(0, 1.7, 0))
		motor(name .. "Wrist", lowerArm, hand, CFrame.new(0, -1.7, 0), CFrame.new(0, 0.55, 0))

		local upperLeg = part(model, name .. "UpperLeg", Vector3.new(0.45, 2.4, 0.45), SKIN, Enum.Material.Fabric)
		local lowerLeg = part(model, name .. "LowerLeg", Vector3.new(0.4, 2.4, 0.4), SKIN, Enum.Material.Fabric)
		motor(name .. "Hip", root, upperLeg, CFrame.new(s * 0.4, -1, 0), CFrame.new(0, 1.2, 0))
		motor(name .. "Knee", upperLeg, lowerLeg, CFrame.new(0, -1.2, 0), CFrame.new(0, 1.2, 0))
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 4.8
	humanoid.AutomaticScalingEnabled = false
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = 1e6
	humanoid.Health = 1e6
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid

	model:SetAttribute("Procedural", true)
	return model
end

-- Returns the creature model to use (your model if present, else the placeholder).
function Rig.Create(): Model
	local folder = ServerStorage:FindFirstChild("Creatures")
	if folder then
		for _, candidate in folder:GetChildren() do
			if candidate:IsA("Model") and candidate:FindFirstChildOfClass("Humanoid") and candidate:FindFirstChild("HumanoidRootPart") then
				local clone = candidate:Clone()
				clone.PrimaryPart = clone:FindFirstChild("HumanoidRootPart") :: BasePart
				for _, descendant in clone:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.Anchored = false
					end
				end
				if clone:GetAttribute("Procedural") == nil then
					clone:SetAttribute("Procedural", false)
				end
				return clone
			end
		end
		warn("[FZ-Creature] ServerStorage.Creatures has no valid model (needs Humanoid + HumanoidRootPart); using placeholder")
	end
	return Rig.BuildPlaceholder()
end

function Rig.Tag(model: Model)
	CollectionService:AddTag(model, "FZ_CreatureRig")
end

return Rig
