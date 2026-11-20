-- Maintenance (owner/developer tools). The server re-checks authorization on every
-- action; this screen is only a convenience UI. World tools (creature spawning, monster
-- mode, teleports, story triggers) are added together with the creature and the map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Admin = {}

function Admin.new(router)
	local app = router.App
	local root, column = Components.ScreenRoot("Admin")
	local scroll = Components.ScrollColumn(column, UDim2.fromScale(1, 1))
	column = scroll :: any

	Components.Heading(column, "ADMIN_TITLE", 1)
	Components.Text({
		Text = string.format("input: %s | device: %s", if app.Input.IsUsingActionSystem() then "InputActionSystem" else "fallback", app.Input.GetDevice()),
		Font = Theme.Fonts.Mono,
		TextSize = 13,
		Color = Theme.Colors.TextFaint,
		LayoutOrder = 2,
		Parent = column,
	})
	Components.Spacer(column, 10, 3)

	local status = Components.Text({ Text = "", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, LayoutOrder = 20, Parent = column })

	local debugButton = Components.Button({ Key = "ADMIN_DEBUG", LayoutOrder = 10, Parent = column, OnActivated = function()
		app.Debug.Toggle()
	end })
	Components.Button({ Key = "ADMIN_GRANT_TEST", LayoutOrder = 11, Parent = column, OnActivated = function()
		local ok, response = pcall(function()
			return Net.Function("AdminAction"):InvokeServer("grant_test_marks")
		end)
		local success = ok and type(response) == "table" and response.ok
		Localization.Bind(status, if success then "ADMIN_DONE" else "ADMIN_DENIED")
	end })
	local function action(key: string, order: number, actionName: string)
		Components.Button({ Key = key, LayoutOrder = order, Height = 40, Parent = column, OnActivated = function()
			local ok, response = pcall(function()
				return Net.Function("AdminAction"):InvokeServer(actionName)
			end)
			local success = ok and type(response) == "table" and response.ok
			local reason = ok and type(response) == "table" and response.reason
			Localization.Bind(status, if success then "ADMIN_DONE" elseif reason == "public" then "ADMIN_PUBLIC_BLOCKED" else "ADMIN_DENIED")
			if success and (actionName == "play_creature" or actionName == "play_human" or actionName == "tp_core") then
				app.Play()
			end
		end })
	end
	action("ADMIN_SPAWN_CREATURE", 12, "spawn_creature")
	action("ADMIN_CREATURE_AI", 13, "toggle_ai")
	action("ADMIN_PLAY_CREATURE", 14, "play_creature")
	action("ADMIN_PLAY_HUMAN", 15, "play_human")
	action("ADMIN_TP_CORE", 16, "tp_core")
	action("ADMIN_SPEED", 17, "toggle_speed")
	action("ADMIN_RESET", 18, "reset")
	Components.Spacer(column, 10, 19)
	Components.Button({ Key = "MENU_BACK", LayoutOrder = 30, Parent = column, OnActivated = function()
		router:Pop()
	end })

	return { Root = root, Focus = debugButton.Instance }
end

return Admin
