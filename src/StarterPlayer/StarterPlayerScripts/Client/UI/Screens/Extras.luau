-- Extras: transmission codes found in the world. The hidden maintenance entry appears
-- here only after the server confirmed authorization (see AdminService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Extras = {}

local RESULT_KEYS = {
	ok = "CODE_OK",
	invalid = "CODE_INVALID",
	used = "CODE_USED",
	rate_limited = "CODE_RATE_LIMITED",
	error = "CODE_ERROR",
	admin = "ADMIN_GRANTED",
}

function Extras.new(router)
	local player = Players.LocalPlayer
	local root, column = Components.ScreenRoot("Extras")
	local layout = Components.List(column, Theme.Sizes.Gap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	Components.Heading(column, "EXTRAS_TITLE", 1)
	local balance = Components.Text({ Text = "", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, LayoutOrder = 2, Parent = column })
	local function refreshBalance()
		Localization.Bind(balance, "EXTRAS_BALANCE", { amount = player:GetAttribute("FZ_SignalMarks") or 0 })
	end
	refreshBalance()

	Components.Spacer(column, 12, 3)
	Components.Text({ Key = "EXTRAS_CODE_TITLE", Font = Theme.Fonts.Medium, TextSize = Theme.Sizes.TextButton, Color = Theme.Colors.TextBright, LayoutOrder = 4, Parent = column })
	Components.Text({ Key = "EXTRAS_CODE_HINT", TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 5, Parent = column })

	local box = Instance.new("TextBox")
	box.Name = "CodeInput"
	box.AutoLocalize = false
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Font = Theme.Fonts.Mono
	box.TextSize = Theme.Sizes.TextButton
	box.TextColor3 = Theme.Colors.TextBright
	box.PlaceholderColor3 = Theme.Colors.TextFaint
	box.BackgroundColor3 = Theme.Colors.Panel
	box.BackgroundTransparency = 0.1
	box.BorderSizePixel = 0
	box.Size = UDim2.new(1, 0, 0, Theme.Sizes.Button)
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.LayoutOrder = 6
	box.Selectable = true
	Localization.Bind(box, "EXTRAS_CODE_PLACEHOLDER", nil, "PlaceholderText")
	Components.Padding(box, 16, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.PanelLine
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = box
	box.Parent = column
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > Config.Codes.MaxLength then
			box.Text = string.sub(box.Text, 1, Config.Codes.MaxLength)
		end
	end)
	box.SelectionGained:Connect(function()
		stroke.Color = Theme.Colors.Accent
	end)
	box.SelectionLost:Connect(function()
		stroke.Color = Theme.Colors.PanelLine
	end)

	local result = Components.Text({ Text = "", Font = Theme.Fonts.Mono, TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextBright, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 8, Parent = column })

	local maintenance
	local pending = false
	local redeemButton
	local function redeem()
		local text = box.Text
		if pending or #string.gsub(text, "%s", "") == 0 then
			return
		end
		pending = true
		redeemButton.SetDisabled(true)
		local ok, response = pcall(function()
			return Net.Function("RedeemCode"):InvokeServer(text)
		end)
		pending = false
		redeemButton.SetDisabled(false)
		local status = if ok and type(response) == "table" then response.status else "error"
		local key = RESULT_KEYS[status] or "CODE_ERROR"
		local positive = status == "ok" or status == "admin"
		result.TextColor3 = if positive then Theme.Colors.Relay else Theme.Colors.TextDim
		Localization.Bind(result, key, { amount = if ok and type(response) == "table" then response.amount or 0 else 0 })
		if positive then
			box.Text = ""
		end
		if status == "admin" then
			maintenance.Instance.Visible = true
		end
	end

	redeemButton = Components.Button({ Key = "EXTRAS_REDEEM", LayoutOrder = 7, Parent = column, OnActivated = redeem })
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)

	Components.Spacer(column, 10, 9)
	maintenance = Components.Button({ Key = "ADMIN_TITLE", LayoutOrder = 10, Parent = column, OnActivated = function()
		router:Push(require(script.Parent.Admin))
	end })
	maintenance.Instance.Visible = player:GetAttribute("FZ_Admin") == true

	Components.Button({ Key = "MENU_BACK", LayoutOrder = 11, Parent = column, OnActivated = function()
		router:Pop()
	end })

	local connections = {
		player:GetAttributeChangedSignal("FZ_SignalMarks"):Connect(refreshBalance),
	}

	return {
		Root = root,
		Focus = box,
		Destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end,
	}
end

return Extras
