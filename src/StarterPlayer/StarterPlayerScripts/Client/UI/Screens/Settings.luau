-- Settings. Every row works the same on every device:
--   mouse / touch: tap the row (next value) or the ‹ › arrows
--   gamepad: A = next value, D-pad left / right = previous / next
--   keyboard: click, or arrow keys while the row is focused
-- Changes apply immediately (no "apply" step) and are saved automatically.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Settings = {}

local function arrow(text: string, parent: Instance, position: UDim2, onActivated: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.AutoLocalize = false
	button.Text = text
	button.Font = Theme.Fonts.Medium
	button.TextSize = 24
	button.TextColor3 = Theme.Colors.TextDim
	button.BackgroundTransparency = 1
	button.Size = UDim2.new(0, 36, 1, 0)
	button.Position = position
	button.Selectable = false
	button.ZIndex = 3
	button.Parent = parent
	button.Activated:Connect(onActivated)
	return button
end

function Settings.new(router)
	local app = router.App
	local settings = app.Settings
	local root, column = Components.ScreenRoot("Settings")
	column.Size = UDim2.new(0, Theme.Sizes.ContentWidth + 60, 1, -48)
	Components.List(column, Theme.Sizes.Gap)

	Components.Heading(column, "SETTINGS_TITLE", 1)
	local tabsRow = Instance.new("Frame")
	tabsRow.BackgroundTransparency = 1
	tabsRow.Size = UDim2.new(1, 0, 0, 36)
	tabsRow.LayoutOrder = 2
	tabsRow.Parent = column
	Components.List(tabsRow, 4, true)
	local scroll = Components.ScrollColumn(column, UDim2.new(1, 0, 1, -150))
	scroll.LayoutOrder = 3
	local currentCategory = "general"
	local tabButtons = {}
	local rebuild: () -> ()

	local rows: { [GuiObject]: string } = {}
	local valueLabels: { [string]: TextLabel } = {}
	local focus = nil

	local function refreshValues()
		for key, label in valueLabels do
			label.Text = settings.Describe(key)
		end
	end

	local function step(key: string, delta: number, wrapInts: boolean?)
		if key == "language" then
			router:Push(require(script.Parent.LanguageSelect), { firstStart = false })
			return
		end
		local definition = Config.Settings[key]
		if wrapInts and definition.kind == "int" and settings.Get(key) >= definition.max then
			settings.Set(key, definition.min)
		else
			settings.Step(key, delta)
		end
	end

	local CONTROLS = {
		{ "CONTROL_INTERACT", "E", "X / Square", "TOUCH_TAP" },
		{ "CONTROL_SPRINT", "Shift", "L3", "TOUCH_SPRINT" },
		{ "CONTROL_LIGHT", "F", "R1 / RB", "TOUCH_LIGHT" },
		{ "CONTROL_RADIO", "R", "L1 / LB", "TOUCH_RADIO" },
		{ "CONTROL_MIC", "M", "PAD_LEFT", "TOUCH_MIC" },
		{ "CONTROL_NIGHT", "N", "PAD_UP", "TOUCH_NIGHT" },
		{ "CONTROL_ITEMS", "1 – 4", "PAD_RIGHT_Y", "TOUCH_TAP" },
		{ "CONTROL_MENU", "P", "View / Share", "II" },
		{ "CONTROL_BACK", "Backspace", "B / Circle", "MENU_BACK" },
	}

	local function controlsList(startOrder: number)
		local device = app.Input.GetDevice()
		local column = if device == "gamepad" then 3 elseif device == "touch" then 4 else 2
		Components.Text({ Key = "CONTROL_DEVICE_" .. string.upper(device), Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.Accent, LayoutOrder = startOrder, Parent = scroll })
		for index, row in CONTROLS do
			local binding = row[column]
			local line = Components.Text({ Key = row[1], TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.Text, LayoutOrder = startOrder + index, Parent = scroll })
			Components.Text({
				Text = if string.match(binding, "^[A-Z_]+$") and Localization.Has(binding) then Localization.T(binding) else binding,
				Font = Theme.Fonts.Mono,
				TextSize = Theme.Sizes.TextSmall + 1,
				Color = Theme.Colors.TextBright,
				XAlign = Enum.TextXAlignment.Right,
				Size = UDim2.fromScale(0.5, 1),
				Position = UDim2.fromScale(0.5, 0),
				Parent = line,
			})
		end
	end

	rebuild = function()
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(rows)
	table.clear(valueLabels)
	focus = nil
	for index, entry in Config.SettingsOrder do
		if entry.category ~= currentCategory then
			continue
		end
		local key = entry.key
		-- Row button and value area are siblings (value area on top), so a tap on an
		-- arrow is handled only by the arrow, never also by the row.
		local wrapper = Instance.new("Frame")
		wrapper.Name = key
		wrapper.BackgroundTransparency = 1
		wrapper.Size = UDim2.new(1, 0, 0, Theme.Sizes.Button)
		wrapper.LayoutOrder = index * 2
		wrapper.Parent = scroll

		local row = Components.Button({
			Key = entry.label,
			Parent = wrapper,
			OnActivated = function()
				step(key, 1, true)
			end,
		})
		row.Instance.Size = UDim2.fromScale(1, 1)
		row.Label.Size = UDim2.new(0.5, -16, 1, 0)
		;(row.Instance:FindFirstChild("Chevron") :: GuiObject).Visible = false
		rows[row.Instance] = key
		if not focus then
			focus = row.Instance
		end

		local valueArea = Instance.new("Frame")
		valueArea.Name = "Value"
		valueArea.BackgroundTransparency = 1
		valueArea.Active = false
		valueArea.ZIndex = 2
		valueArea.AnchorPoint = Vector2.new(1, 0)
		valueArea.Position = UDim2.fromScale(1, 0)
		valueArea.Size = UDim2.new(0.5, 0, 1, 0)
		valueArea.Parent = wrapper

		local value = Components.Text({
			Text = "",
			Font = Theme.Fonts.Mono,
			TextSize = Theme.Sizes.TextSmall + 1,
			Color = Theme.Colors.TextBright,
			XAlign = Enum.TextXAlignment.Center,
			Wrapped = false,
			Size = UDim2.new(1, -72, 1, 0),
			Position = UDim2.fromOffset(36, 0),
			Parent = valueArea,
		})
		value.TextTruncate = Enum.TextTruncate.AtEnd
		value.ZIndex = 2
		valueLabels[key] = value

		if key ~= "language" then
			arrow("‹", valueArea, UDim2.fromScale(0, 0), function()
				step(key, -1)
			end)
			arrow("›", valueArea, UDim2.new(1, -36, 0, 0), function()
				step(key, 1)
			end)
		end

		if entry.description then
			Components.Text({
				Key = entry.description,
				TextSize = Theme.Sizes.TextSmall,
				Color = Theme.Colors.TextDim,
				AutoY = true,
				Size = UDim2.fromScale(1, 0),
				LayoutOrder = index * 2 + 1,
				Parent = scroll,
			})
		end
	end

	if currentCategory == "controls" then
		controlsList(100)
	end
	-- D-pad left/right must change values instead of moving focus out of the row.
	for row in rows do
		row.NextSelectionLeft = row
		row.NextSelectionRight = row
	end
	refreshValues()
	end

	for index, category in Config.SettingsCategories do
		local tab = Components.Button({ Key = Config.SettingsCategoryLabels[category], Height = 36, Centered = true, LayoutOrder = index, Parent = tabsRow, OnActivated = function()
			currentCategory = category
			for c, b in tabButtons do
				b.SetFocused(c == category)
			end
			rebuild()
		end })
		tab.Instance.Size = UDim2.new(1 / #Config.SettingsCategories, -4, 1, 0)
		tab.Label.TextSize = Theme.Sizes.TextSmall
		tab.Label.TextTruncate = Enum.TextTruncate.AtEnd
		tabButtons[category] = tab
	end
	rebuild()
	tabButtons.general.SetFocused(true)

	local back = Components.Button({ Key = "MENU_BACK", LayoutOrder = 4, Parent = column, OnActivated = function()
		router:Pop()
	end })
	back.Instance.Size = UDim2.new(1, 0, 0, Theme.Sizes.Button)

	local connections = {
		app.Input.DeviceChanged:Connect(function()
			if currentCategory == "controls" then
				rebuild()
			end
		end),
		settings.Changed:Connect(refreshValues),
		Localization.Changed:Connect(refreshValues),
		UserInputService.InputBegan:Connect(function(input)
			local selected = GuiService.SelectedObject
			local key = selected and rows[selected]
			if not key or key == "language" then
				return
			end
			if input.KeyCode == Enum.KeyCode.DPadLeft or input.KeyCode == Enum.KeyCode.Left then
				step(key, -1)
			elseif input.KeyCode == Enum.KeyCode.DPadRight or input.KeyCode == Enum.KeyCode.Right then
				step(key, 1)
			end
		end),
	}

	return {
		Root = root,
		Focus = tabButtons.general.Instance,
		Destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end,
	}
end

return Settings
