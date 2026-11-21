-- The shared pool of psychological horror events (used by every mode).
-- Each entry: kind (performed by DirectorController), weight, cooldown, chance (rarity)
-- and a condition. The director never fires while a creature is chasing nearby and never
-- uses the real chase warning sound for a trick - danger always stays recognisable.

local Services = script.Parent.Parent.Services
local DirectorService = require(Services.DirectorService)
local CreatureService = require(Services.CreatureService)

local HorrorEvents = {}

local function noCreatureNear(position: Vector3, radius: number): boolean
	local model = CreatureService.Get()
	local root = model and model:FindFirstChild("HumanoidRootPart")
	return not root or ((root :: BasePart).Position - position).Magnitude > radius
end

local function inside(info): boolean
	return info.area ~= nil
end

function HorrorEvents.Pool(): { any }
	return {
		{ id = "ev_window", kind = "window", weight = 3, cooldown = 140, condition = function(_p, info)
			return DirectorService.NearTagged("FZ_Window", info.position, 6, 32)
		end },
		{ id = "ev_occupant", kind = "occupant", weight = 2, cooldown = 160, chance = 0.6, condition = function(_p, info)
			return info.area ~= nil and info.area ~= "HALL" and info.area ~= "CONTROL"
		end },
		{ id = "ev_speaker", kind = "speaker", weight = 3, cooldown = 100, condition = function(_p, info)
			return DirectorService.NearTagged("FZ_Speaker", info.position, 4, 40)
		end },
		{ id = "ev_neighbor_light", kind = "neighborlight", weight = 3, cooldown = 110, condition = function(_p, info)
			return inside(info)
		end },
		{ id = "ev_footsteps", kind = "footsteps", weight = 4, cooldown = 70, condition = function(_p, info)
			return info.alone and inside(info)
		end },
		{ id = "ev_shadow", kind = "shadow", weight = 2, cooldown = 150, condition = function(_p, info)
			return inside(info)
		end },
		-- Acoustic deception: creature sounds behind a wall although nothing is there.
		{ id = "ev_phantom", kind = "phantom", weight = 4, cooldown = 80, condition = function(_p, info)
			return inside(info) and noCreatureNear(info.position, 55)
		end },
		{ id = "ev_approach", kind = "approach", weight = 2, cooldown = 200, chance = 0.7, condition = function(_p, info)
			return info.area == "HALL" and noCreatureNear(info.position, 70)
		end },
		{ id = "ev_voices", kind = "voices", weight = 2, cooldown = 180, condition = function(_p, info)
			return inside(info) and info.alone
		end },
		-- Very rare: an object only YOU can see (another radio in your own colours...)
		{ id = "ev_object", kind = "object", weight = 1, cooldown = 600, chance = 0.35, condition = function(_p, info)
			return inside(info)
		end },
	}
end

-- Story beats first, then the pool (story beats keep their own conditions).
function HorrorEvents.With(storyBeats: { any }): { any }
	local list = table.clone(storyBeats)
	for _, beat in HorrorEvents.Pool() do
		table.insert(list, beat)
	end
	return list
end

return HorrorEvents
