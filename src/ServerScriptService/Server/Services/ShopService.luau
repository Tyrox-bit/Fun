-- ShopService: unlock and equip items with earned Signal Marks (server-authoritative).
-- Effects are published as player attributes so client visuals and server rules read
-- the same values. Robux: only the cosmetic supporter game pass (Catalog.GamePasses).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local AnalyticsTracker = require(script.Parent.AnalyticsTracker)

local ShopService = {}

function ShopService.Publish(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local data = profile.Data
	local effects = Catalog.Effects(data.inventory, data.equipped)
	player:SetAttribute("FZ_Set", data.equipped.set or "")
	player:SetAttribute("FZ_HoldMultiplier", effects.interactHoldMultiplier or 1)
	player:SetAttribute("FZ_NightVision", effects.nightVision == true)
	player:SetAttribute("FZ_Footprints", effects.footprints == true)
	player:SetAttribute("FZ_ReviveMultiplier", effects.reviveMultiplier or 1)
	player:SetAttribute("FZ_ReviveHealth", effects.reviveHealth or Config.Health.ReviveHealth)
	player:SetAttribute("FZ_RegenCap", effects.regenCap or Config.Health.RegenCap)
	player:SetAttribute("FZ_ScareDampening", effects.scareDampening == true)
	player:SetAttribute("FZ_FlashRange", effects.flashlightRange or 1)
	player:SetAttribute("FZ_BlindCooldownScale", effects.blindCooldown or 1)
	local skin = data.equipped.radioSkin and Catalog.Items[data.equipped.radioSkin]
	player:SetAttribute("FZ_RadioColor", if skin then skin.color else Catalog.DefaultRadioColor)
end

local function snapshot(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false }
	end
	return {
		ok = true,
		inventory = table.clone(profile.Data.inventory),
		equipped = table.clone(profile.Data.equipped),
		balance = profile.Data.signalMarks,
	}
end

local function buy(player: Player, itemId: string)
	local item = Catalog.Items[itemId]
	local profile = DataService.Get(player)
	if not item or not profile then
		return { ok = false, reason = "error" }
	end
	if not profile.Persistent then
		return { ok = false, reason = "error" } -- never sell into a save that cannot be stored
	end
	if profile.Data.inventory[itemId] then
		return { ok = false, reason = "owned" }
	end
	if profile.Data.signalMarks < item.price then
		return { ok = false, reason = "funds" }
	end
	DataService.Mutate(player, function(data)
		data.signalMarks -= item.price
		data.inventory[itemId] = true
	end)
	DataService.SaveNow(player)
	AnalyticsTracker.Economy(player, item.price, profile.Data.signalMarks, false, itemId)
	return { ok = true }
end

local function equip(player: Player, itemId: string, on: boolean)
	local item = Catalog.Items[itemId]
	local profile = DataService.Get(player)
	if not item or not profile or not profile.Data.inventory[itemId] then
		return { ok = false, reason = "error" }
	end
	DataService.Mutate(player, function(data)
		if item.kind == "set" then
			data.equipped.set = if on then itemId else nil
		elseif item.kind == "radioSkin" then
			data.equipped.radioSkin = if on then itemId else nil
		end
	end)
	return { ok = true }
end

local function grantGamePass(player: Player, passKey: string)
	local pass = Catalog.GamePasses[passKey]
	if pass and pass.grantsRadioSkin then
		DataService.Mutate(player, function(data)
			data.inventory[pass.grantsRadioSkin] = true
		end)
	end
end

function ShopService.Start()
	local limiter = RateLimiter.new(8, 2)
	Net.Function("ShopAction").OnServerInvoke = function(player: Player, action: any, itemId: any)
		if not limiter:Allow(player) or type(action) ~= "string" then
			return { ok = false, reason = "error" }
		end
		local result
		if action == "get" then
			return snapshot(player)
		elseif type(itemId) ~= "string" then
			return { ok = false, reason = "error" }
		elseif action == "buy" then
			result = buy(player, itemId)
		elseif action == "equip" then
			result = equip(player, itemId, true)
		elseif action == "unequip" then
			result = equip(player, itemId, false)
		else
			return { ok = false, reason = "error" }
		end
		ShopService.Publish(player)
		local snap = snapshot(player)
		snap.ok = result.ok
		snap.reason = result.reason
		return snap
	end

	DataService.ProfileLoaded:Connect(function(player)
		for key, pass in Catalog.GamePasses do
			if pass.id > 0 then
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
				if ok and owns then
					grantGamePass(player, key)
				end
			end
		end
		ShopService.Publish(player)
	end)

	for _, player in Players:GetPlayers() do
		if DataService.Get(player) then
			ShopService.Publish(player)
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in Catalog.GamePasses do
			if pass.id == passId then
				grantGamePass(player, key)
				ShopService.Publish(player)
			end
		end
	end)
end

return ShopService
