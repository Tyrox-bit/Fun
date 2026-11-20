-- Shop: tabs (Equipment / Upgrades / Cosmetics) with large cards, Signal Mark balance,
-- confirmation before every unlock. Works with mouse, touch and gamepad (cards are
-- selectable buttons, tabs too). No Robux prompts in here except the clearly labelled,
-- purely cosmetic supporter pass (only shown when its id is configured).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Shop = {}

local RESULT = { funds = "SHOP_NOT_ENOUGH", error = "SHOP_ERROR", owned = "SHOP_OWNED" }

function Shop.new(router)
	local app = router.App
	local player = Players.LocalPlayer
	local root, column = Components.ScreenRoot("Shop")
	column.Size = UDim2.new(0, 640, 1, -48)
	local sizeLimit = column:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = Vector2.new(640, math.huge)
	end
	Components.List(column, Theme.Sizes.Gap)

	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 44)
	header.LayoutOrder = 1
	header.Parent = column
	Components.Heading(header, "MENU_SHOP")
	local balance = Components.Text({ Text = "", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.Radio, XAlign = Enum.TextXAlignment.Right, Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromScale(0.5, 0), Parent = header })

	local tabsRow = Instance.new("Frame")
	tabsRow.BackgroundTransparency = 1
	tabsRow.Size = UDim2.new(1, 0, 0, 40)
	tabsRow.LayoutOrder = 2
	tabsRow.Parent = column
	Components.List(tabsRow, 4, true)

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(1, 0, 1, -220)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 3
	grid.ScrollBarImageColor3 = Theme.Colors.TextFaint
	grid.Selectable = false
	grid.LayoutOrder = 3
	grid.Parent = column
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.5, -6, 0, 132)
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local status = Components.Text({ Key = "SHOP_FAIR", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 4, Parent = column })
	Components.Button({ Key = "MENU_BACK", LayoutOrder = 6, Parent = column, OnActivated = function()
		router:Pop()
	end })

	local data = { inventory = {}, equipped = {}, balance = 0 }
	local currentTab = "gear"
	local pendingConfirm: string? = nil
	local busy = false
	local firstCard: GuiObject? = nil
	local render: () -> ()

	local function setStatus(key: string, params: { [string]: any }?, positive: boolean?)
		status.TextColor3 = if positive then Theme.Colors.Relay else Theme.Colors.TextDim
		Localization.Bind(status, key, params)
	end

	local function call(action: string, itemId: string?)
		if busy then
			return
		end
		busy = true
		local ok, result = pcall(function()
			return Net.Function("ShopAction"):InvokeServer(action, itemId)
		end)
		busy = false
		if ok and type(result) == "table" and result.inventory then
			data = result
		end
		if not ok or type(result) ~= "table" or not result.ok then
			setStatus(RESULT[(type(result) == "table" and result.reason) or "error"] or "SHOP_ERROR")
		elseif action == "buy" then
			setStatus("SHOP_DONE", nil, true)
		elseif action == "equip" and Catalog.Items[itemId :: string].kind == "set" then
			setStatus("SHOP_ONE_SET")
		end
		render()
	end

	local function card(itemId: string, order: number)
		local item = Catalog.Items[itemId]
		local owned = data.inventory[itemId] == true
		local equipped = data.equipped.set == itemId or data.equipped.radioSkin == itemId
		local button = Instance.new("TextButton")
		button.Name = itemId
		button.AutoButtonColor = false
		button.Text = ""
		button.AutoLocalize = false
		button.BackgroundColor3 = Theme.Colors.Panel
		button.BackgroundTransparency = 0.05
		button.LayoutOrder = order
		button.Selectable = true
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = if equipped then Theme.Colors.Relay else Theme.Colors.PanelLine
		stroke.Thickness = if equipped then 2 else 1
		stroke.Parent = button
		local selection = Instance.new("Frame")
		selection.BackgroundTransparency = 1
		local selectionStroke = Instance.new("UIStroke")
		selectionStroke.Color = Theme.Colors.Accent
		selectionStroke.Thickness = 2
		selectionStroke.Parent = selection
		button.SelectionImageObject = selection
		button.Parent = grid
		Components.Padding(button, 12, 10)

		local icon = Instance.new("Frame")
		icon.Size = UDim2.fromOffset(56, 56)
		icon.BackgroundColor3 = item.color
		icon.BorderSizePixel = 0
		icon.Parent = button
		Components.Text({ Text = item.icon, Font = Theme.Fonts.Mono, TextSize = 14, Color = Theme.Colors.TextBright, XAlign = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = icon })

		Components.Text({ Key = item.name, Font = Theme.Fonts.Bold, TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.TextBright, Size = UDim2.new(1, -66, 0, 22), Position = UDim2.fromOffset(66, 0), Wrapped = false, Parent = button })
		local desc = Components.Text({ Key = item.description, TextSize = 13, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -66, 0, 54), Position = UDim2.fromOffset(66, 22), YAlign = Enum.TextYAlignment.Top, Parent = button })
		desc.TextTruncate = Enum.TextTruncate.AtEnd

		local actionKey, params
		if pendingConfirm == itemId then
			actionKey, params = "SHOP_CONFIRM_YES", nil
		elseif not owned then
			actionKey, params = "SHOP_BUY", { price = item.price }
		elseif equipped and item.kind ~= "upgrade" then
			actionKey = "SHOP_UNEQUIP"
		elseif item.kind == "upgrade" then
			actionKey = "SHOP_OWNED"
		else
			actionKey = "SHOP_EQUIP"
		end
		local action = Components.Text({ Key = actionKey, Params = params, Font = Theme.Fonts.Mono, TextSize = 14, Color = if pendingConfirm == itemId then Theme.Colors.Accent elseif owned then Theme.Colors.Relay else Theme.Colors.Radio, XAlign = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), Parent = button })
		action.Name = "Action"

		button.Activated:Connect(function()
			if not owned then
				if pendingConfirm == itemId then
					pendingConfirm = nil
					call("buy", itemId)
				else
					pendingConfirm = itemId
					setStatus("SHOP_CONFIRM", { price = item.price })
					render()
					GuiService.SelectedObject = grid:FindFirstChild(itemId) :: GuiObject?
				end
			elseif item.kind ~= "upgrade" then
				call(if equipped then "unequip" else "equip", itemId)
			end
		end)
		if not firstCard then
			firstCard = button
		end
	end

	local tabButtons = {}
	render = function()
		local selectedName = GuiService.SelectedObject and GuiService.SelectedObject.Name
		Localization.Bind(balance, "EXTRAS_BALANCE", { amount = data.balance or 0 })
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		firstCard = nil
		for index, itemId in Catalog.Order do
			if Catalog.Items[itemId].tab == currentTab then
				card(itemId, index)
			end
		end
		for tab, button in tabButtons do
			button.SetFocused(tab == currentTab)
		end
		if selectedName and app.Input.GetDevice() == "gamepad" then
			local again = grid:FindFirstChild(selectedName)
			if again then
				GuiService.SelectedObject = again :: GuiObject
			end
		end
	end

	for index, tab in Catalog.Tabs do
		local tabButton = Components.Button({ Key = Catalog.TabLabels[tab], Height = 40, LayoutOrder = index, Parent = tabsRow, OnActivated = function()
			currentTab = tab
			pendingConfirm = nil
			render()
		end })
		tabButton.Instance.Size = UDim2.new(1 / #Catalog.Tabs, -4, 1, 0)
		tabButton.Label.TextSize = Theme.Sizes.TextBody
		tabButtons[tab] = tabButton
	end

	-- Cosmetic supporter pass (Robux), only if configured
	for _, pass in Catalog.GamePasses do
		if pass.id > 0 then
			Components.Button({ Key = pass.name, TagKey = pass.description, LayoutOrder = 5, Parent = column, OnActivated = function()
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end })
		end
	end

	render()
	task.spawn(call, "get")

	return {
		Root = root,
		Focus = tabButtons.gear.Instance,
		OnBack = function()
			if pendingConfirm then
				pendingConfirm = nil
				render()
				return true
			end
			return false
		end,
	}
end

return Shop
