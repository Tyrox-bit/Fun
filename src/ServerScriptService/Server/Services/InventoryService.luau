-- InventoryService: small hotbar per player and session (bandages, syringes).
-- Server-authoritative; replicated as the player attribute "FZ_Items" ("bandage,syringe").
--   * 3 slots, technician set 4
--   * medic set: starts every session with 2 bandages + 1 syringe and heals 50 % more
--   * a syringe also gets you back up when you are down (self-revive)
-- Items reset per session; they are not a currency and cannot be bought.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local InteractionService = require(script.Parent.InteractionService)
local HealthService = require(script.Parent.HealthService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local InventoryService = {}

local inventories: { [Player]: { string } } = {}
local using: { [Player]: boolean } = {}
local worldFolder: Folder? = nil

local function slots(player: Player): number
	return if player:GetAttribute("FZ_Set") == "set_technician" then Config.Inventory.TechnicianSlots else Config.Inventory.Slots
end

local function publish(player: Player)
	player:SetAttribute("FZ_Items", table.concat(inventories[player] or {}, ","))
	player:SetAttribute("FZ_ItemSlots", slots(player))
end

function InventoryService.Give(player: Player, itemId: string): boolean
	local list = inventories[player]
	if not list then
		list = {}
		inventories[player] = list
	end
	if not Config.Items[itemId] or #list >= slots(player) then
		return false
	end
	table.insert(list, itemId)
	publish(player)
	return true
end

function InventoryService.Has(player: Player, itemId: string): boolean
	return table.find(inventories[player] or {}, itemId) ~= nil
end

function InventoryService.Take(player: Player, itemId: string): boolean
	local list = inventories[player]
	local index = list and table.find(list, itemId)
	if not index then
		return false
	end
	table.remove(list :: { string }, index)
	publish(player)
	return true
end

function InventoryService.Reset(player: Player)
	inventories[player] = {}
	for _, itemId in Config.Inventory.EveryoneStart do
		InventoryService.Give(player, itemId)
	end
	if player:GetAttribute("FZ_Set") == "set_medic" then
		for _, itemId in Config.Inventory.MedicStart do
			InventoryService.Give(player, itemId)
		end
	end
	publish(player)
end

function InventoryService.Clear(player: Player)
	inventories[player] = {}
	publish(player)
end

function InventoryService.ClearWorld()
	if worldFolder then
		worldFolder:Destroy()
		worldFolder = nil
	end
end

-- Places random items at free FZ_ItemSpot spots.
function InventoryService.SpawnWorldItems(count: number)
	if not worldFolder or not worldFolder.Parent then
		local folder = Instance.new("Folder")
		folder.Name = "FZ_WorldItems"
		folder.Parent = workspace
		worldFolder = folder
	end
	local folder = worldFolder :: Folder
	local spots = {}
	for _, spot in CollectionService:GetTagged("FZ_ItemSpot") do
		if spot:IsA("BasePart") and not spot:GetAttribute("Occupied") then
			table.insert(spots, spot)
		end
	end
	for _ = 1, math.min(count, #spots) do
		local spot = table.remove(spots, math.random(1, #spots))
		local roll = math.random()
		local itemId = if roll < 0.5 then "bandage" elseif roll < 0.85 then "medkit" else "syringe"
		local part = Instance.new("Part")
		part.Name = itemId
		part.Anchored = true
		part.CanCollide = false
		part.Size = if itemId == "bandage" then Vector3.new(0.9, 0.5, 0.9) elseif itemId == "medkit" then Vector3.new(1.4, 0.9, 1) else Vector3.new(0.25, 0.25, 1.2)
		part.Color = if itemId == "bandage" then Color3.fromRGB(226, 222, 210) elseif itemId == "medkit" then Color3.fromRGB(170, 60, 54) else Color3.fromRGB(120, 200, 220)
		part.Material = if itemId == "syringe" then Enum.Material.Glass else Enum.Material.Fabric
		part.CFrame = spot.CFrame
		local glow = Instance.new("PointLight")
		glow.Range = 4
		glow.Brightness = 0.6
		glow.Color = Color3.fromRGB(200, 230, 255)
		glow.Parent = part
		part:SetAttribute("InteractId", "item")
		part:SetAttribute("ItemId", itemId)
		part:SetAttribute("ActionKey", "INTERACT_PICKUP")
		part:SetAttribute("ObjectKey", Config.Items[itemId].name)
		part:SetAttribute("MaxDistance", 7)
		part.Parent = folder
		spot:SetAttribute("Occupied", true)
		part.Destroying:Connect(function()
			spot:SetAttribute("Occupied", nil)
		end)
		CollectionService:AddTag(part, "FZ_Interactable")
	end
end

-- First-aid cabinets (tag FZ_MedCabinet): hold medkits, refilled per session / survival break.
function InventoryService.RefillCabinets()
	for _, cabinet in CollectionService:GetTagged("FZ_MedCabinet") do
		cabinet:SetAttribute("Medkits", Config.Inventory.CabinetMedkits)
	end
end

function InventoryService.Start()
	InteractionService.Register("medcabinet", function(player, cabinet)
		local left = tonumber(cabinet:GetAttribute("Medkits")) or 0
		if left <= 0 then
			Net.Event("Notify"):FireClient(player, "CABINET_EMPTY")
			return
		end
		if InventoryService.Give(player, "medkit") then
			cabinet:SetAttribute("Medkits", left - 1)
			Net.Event("Sfx"):FireAllClients("door_open", (cabinet :: BasePart).Position, 0.4)
		else
			Net.Event("Notify"):FireClient(player, "INV_FULL")
		end
	end)

	InteractionService.Register("item", function(player, part)
		local itemId = part:GetAttribute("ItemId")
		if type(itemId) ~= "string" or not part.Parent then
			return
		end
		if InventoryService.Give(player, itemId) then
			Net.Event("Sfx"):FireAllClients("fuse_pickup", (part :: BasePart).Position)
			part:Destroy()
		else
			Net.Event("Notify"):FireClient(player, "INV_FULL")
		end
	end)

	local limiter = RateLimiter.new(3, 1)
	Net.Event("UseItem").OnServerEvent:Connect(function(player: Player, slot: any)
		local list = inventories[player]
		if not list or not limiter:Allow(player) or using[player] or type(slot) ~= "number" or slot % 1 ~= 0 then
			return
		end
		local itemId = list[slot]
		local item = itemId and Config.Items[itemId]
		if not item then
			return
		end
		local downed = player:GetAttribute("FZ_Downed") == true
		if downed and itemId ~= "syringe" then
			return
		end
		using[player] = true
		local character = player.Character
		player:SetAttribute("FZ_UsingItem", itemId)
		task.delay(item.useTime, function()
			using[player] = nil
			player:SetAttribute("FZ_UsingItem", nil)
			if player.Character ~= character or inventories[player] ~= list or list[slot] ~= itemId then
				return
			end
			table.remove(list, slot)
			publish(player)
			local bonus = if player:GetAttribute("FZ_Set") == "set_medic" then Config.Inventory.MedicHealBonus else 1
			if player:GetAttribute("FZ_Downed") then
				HealthService.Revive(player, 60 * bonus)
			else
				HealthService.Heal(player, item.heal * bonus)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
		using[player] = nil
	end)
end

return InventoryService
