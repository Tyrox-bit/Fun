-- InventoryController: the hotbar. Only visible when you carry something.
--   PC 1-4 = use slot directly · gamepad D-pad right = next slot, Y = use · touch: tap a slot

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local InputController = require(script.Parent.InputController)
local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)

local InventoryController = {}

-- Emoji glyphs render on every platform without uploading image assets.
local ICONS = { bandage = "🩹", medkit = "🧰", syringe = "💉" }

local player = Players.LocalPlayer
local bar: Frame
local selected = 1
local items: { string } = {}

local function use(slot: number)
	if items[slot] then
		Net.Event("UseItem"):FireServer(slot)
	end
end

local function render()
	for _, child in bar:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local raw = player:GetAttribute("FZ_Items")
	items = if type(raw) == "string" and raw ~= "" then string.split(raw, ",") else {}
	local slots = tonumber(player:GetAttribute("FZ_ItemSlots")) or Config.Inventory.Slots
	bar.Visible = #items > 0 and player:GetAttribute("FZ_InGame") == true
	selected = math.clamp(selected, 1, math.max(1, #items))
	local using = player:GetAttribute("FZ_UsingItem")
	for slot = 1, slots do
		local itemId = items[slot]
		local button = Instance.new("TextButton")
		button.Name = "Slot" .. slot
		button.AutoButtonColor = false
		button.AutoLocalize = false
		button.Text = ""
		button.Size = UDim2.fromOffset(68, 68)
		button.LayoutOrder = slot
		button.Selectable = false
		button.BackgroundColor3 = Theme.Colors.Panel
		button.BackgroundTransparency = if itemId then 0.15 else 0.6
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = if slot == selected and itemId then Theme.Colors.Relay else Theme.Colors.PanelLine
		stroke.Thickness = if slot == selected and itemId then 2 else 1
		stroke.Parent = button
		Components.Corner(button, 8)
		if slot == selected and itemId then
			local underline = Instance.new("Frame")
			underline.Name = "Selected"
			underline.BackgroundColor3 = Theme.Colors.Relay
			underline.BorderSizePixel = 0
			underline.AnchorPoint = Vector2.new(0.5, 1)
			underline.Position = UDim2.new(0.5, 0, 1, -4)
			underline.Size = UDim2.fromOffset(22, 2)
			underline.Parent = button
		end
		Components.Text({ Text = tostring(slot), Font = Theme.Fonts.Mono, TextSize = 11, Color = Theme.Colors.TextFaint, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(4, 2), Parent = button })
		if itemId then
			Components.Text({ Text = ICONS[itemId] or "◆", TextSize = 24, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 8), Parent = button })
			local name = Components.Text({ Key = Config.Items[itemId].name, Font = Theme.Fonts.Medium, TextSize = 11, Color = if using == itemId then Theme.Colors.Relay else Theme.Colors.TextBright, XAlign = Enum.TextXAlignment.Center, Wrapped = false, Size = UDim2.new(1, -6, 0, 14), Position = UDim2.fromOffset(3, 42), Parent = button })
			name.TextTruncate = Enum.TextTruncate.AtEnd
		end
		button.Activated:Connect(function()
			use(slot)
		end)
		button.Parent = bar
	end
end

function InventoryController.Init(hudGui: ScreenGui)
	bar = Instance.new("Frame")
	bar.Name = "Hotbar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -22)
	bar.Size = UDim2.fromOffset(4 * 76, 68)
	bar.Visible = false
	bar.Parent = hudGui
	local layout = Components.List(bar, 6, true)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	for _, attribute in { "FZ_Items", "FZ_ItemSlots", "FZ_UsingItem", "FZ_InGame" } do
		player:GetAttributeChangedSignal(attribute):Connect(render)
	end
	Localization.Changed:Connect(render)
	render()

	InputController.Action:Connect(function(name, pressed)
		if not pressed then
			return
		end
		local direct = string.match(name, "^Item(%d)$")
		if direct then
			use(tonumber(direct) :: number)
		elseif name == "ItemNext" and #items > 0 then
			selected = (selected % #items) + 1
			render()
		elseif name == "ItemUse" then
			use(selected)
		end
	end)
end

return InventoryController
