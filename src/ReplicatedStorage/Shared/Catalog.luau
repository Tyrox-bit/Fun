-- Shop catalog. Prices are in Signal Marks (earned in-game only).
-- Fair-play rule: equipment that changes gameplay can ONLY be earned with Signal Marks.
-- Robux products are cosmetic only and there is no Robux -> Signal Marks conversion.

local Catalog = {}

Catalog.Tabs = { "gear", "upgrades", "cosmetic" }
Catalog.TabLabels = { gear = "SHOP_TAB_GEAR", upgrades = "SHOP_TAB_UPGRADES", cosmetic = "SHOP_TAB_COSMETIC" }

Catalog.Items = {
	set_technician = {
		tab = "gear",
		kind = "set",
		price = 1800,
		name = "ITEM_TECH_NAME",
		description = "ITEM_TECH_DESC",
		icon = "TECH",
		color = Color3.fromRGB(150, 110, 70),
		effects = { interactHoldMultiplier = 0.6 },
	},
	set_observer = {
		tab = "gear",
		kind = "set",
		price = 2400,
		name = "ITEM_OBSERVER_NAME",
		description = "ITEM_OBSERVER_DESC",
		icon = "OBS",
		color = Color3.fromRGB(90, 150, 100),
		effects = { nightVision = true, footprints = true },
	},
	set_medic = {
		tab = "gear",
		kind = "set",
		price = 1600,
		name = "ITEM_MEDIC_NAME",
		description = "ITEM_MEDIC_DESC",
		icon = "MED",
		color = Color3.fromRGB(170, 70, 64),
		effects = { reviveMultiplier = 0.5, reviveHealth = 60, regenCap = 70, scareDampening = true },
	},
	flashlight_upgrade = {
		tab = "upgrades",
		kind = "upgrade",
		price = 900,
		name = "ITEM_FLASHLIGHT_NAME",
		description = "ITEM_FLASHLIGHT_DESC",
		icon = "LUX",
		color = Color3.fromRGB(230, 214, 170),
		effects = { flashlightRange = 1.35, blindCooldown = 0.7 },
	},
	radio_olive = {
		tab = "cosmetic",
		kind = "radioSkin",
		price = 500,
		name = "ITEM_SKIN_OLIVE_NAME",
		description = "ITEM_SKIN_DESC",
		icon = "CH",
		color = Color3.fromRGB(86, 96, 62),
	},
	radio_rust = {
		tab = "cosmetic",
		kind = "radioSkin",
		price = 500,
		name = "ITEM_SKIN_RUST_NAME",
		description = "ITEM_SKIN_DESC",
		icon = "CH",
		color = Color3.fromRGB(122, 66, 44),
	},
	radio_signal = {
		tab = "cosmetic",
		kind = "radioSkin",
		price = 1200,
		name = "ITEM_SKIN_SIGNAL_NAME",
		description = "ITEM_SKIN_DESC",
		icon = "CH",
		color = Color3.fromRGB(176, 52, 40),
	},
}

Catalog.Order = { "set_technician", "set_observer", "set_medic", "flashlight_upgrade", "radio_olive", "radio_rust", "radio_signal" }

Catalog.DefaultRadioColor = Color3.fromRGB(46, 48, 50)

-- Robux (cosmetic only). Fill in the ids from the Creator Hub; 0 = product hidden.
Catalog.GamePasses = {
	supporter = { id = 0, name = "ITEM_SUPPORTER_NAME", description = "ITEM_SUPPORTER_DESC", grantsRadioSkin = "radio_signal" },
}

-- Combined effects of everything the player owns and has equipped.
function Catalog.Effects(inventory: { [string]: any }?, equipped: { [string]: any }?): { [string]: any }
	local result = {}
	local function merge(itemId)
		local item = Catalog.Items[itemId]
		if item and item.effects then
			for key, value in item.effects do
				result[key] = value
			end
		end
	end
	if equipped and equipped.set then
		merge(equipped.set)
	end
	if inventory and inventory.flashlight_upgrade then
		merge("flashlight_upgrade")
	end
	return result
end

return Catalog
