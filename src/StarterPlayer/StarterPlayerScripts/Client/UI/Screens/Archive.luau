-- DAS ARCHIV: the station's archive terminal.
-- Green monospace, file numbers, categories, locked files that do not reveal their content,
-- link progress for insights ("2/3 files"), a frequency input for hidden secrets, and the
-- player's earned titles. Opens documents and re-renders photographs on demand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared.Localization)
local Lore = require(Shared.Lore)
local Net = require(Shared.Net)
local Titles = require(Shared.Titles)
local Achievements = require(Shared.Achievements)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local Archive = {}

local GREEN = Color3.fromRGB(120, 230, 150)
local GREEN_DIM = Color3.fromRGB(60, 120, 80)
local CATEGORIES = { "all", "photo", "report", "tape", "observation", "radio", "confidential", "past", "insight", "achievements", "titles" }

local function terminalText(props)
	props.Font = Theme.Fonts.Mono
	props.Color = props.Color or GREEN
	local label = Components.Text(props)
	label.TextStrokeTransparency = 0.85
	return label
end

function Archive.new(router)
	local app = router.App
	local root = Instance.new("CanvasGroup")
	root.Name = "Archive"
	root.BackgroundColor3 = Color3.fromRGB(4, 10, 6)
	root.BackgroundTransparency = 0.08
	root.Size = UDim2.fromScale(1, 1)

	-- scanlines (static, no flicker)
	local scan = Instance.new("Frame")
	scan.BackgroundTransparency = 1
	scan.Size = UDim2.fromScale(1, 1)
	scan.ZIndex = 5
	scan.Parent = root
	local gradient = Instance.new("UIGradient")
	local points = {}
	for i = 0, 18 do
		table.insert(points, NumberSequenceKeypoint.new(i / 18, if i % 2 == 0 then 0.94 else 1))
	end
	gradient.Transparency = NumberSequence.new(points)
	gradient.Rotation = 90
	gradient.Parent = scan
	scan.BackgroundColor3 = Color3.new(0, 0, 0)
	scan.BackgroundTransparency = 0

	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.5)
	column.Size = UDim2.new(1, -48, 1, -32)
	column.Parent = root
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(760, math.huge)
	limit.Parent = column

	terminalText({ Text = "RELAY 07 · " .. Localization.T("ARCHIVE_TERMINAL") .. " · " .. Players.LocalPlayer.DisplayName, TextSize = 14, Color = GREEN_DIM, Size = UDim2.new(1, 0, 0, 20), Parent = column })
	terminalText({ Key = "ARCHIVE_TITLE", TextSize = 26, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 20), Parent = column })

	local tabs = Instance.new("ScrollingFrame")
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.Position = UDim2.fromOffset(0, 58)
	tabs.Size = UDim2.new(1, 0, 0, 38)
	tabs.CanvasSize = UDim2.new()
	tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabs.ScrollingDirection = Enum.ScrollingDirection.X
	tabs.ScrollBarThickness = 0
	tabs.Selectable = false
	tabs.Parent = column
	Components.List(tabs, 4, true)

	local list = Components.ScrollColumn(column, UDim2.new(1, 0, 1, -200), UDim2.fromOffset(0, 100))
	list.ScrollBarImageColor3 = GREEN_DIM

	-- frequency input (secrets)
	local inputRow = Instance.new("Frame")
	inputRow.BackgroundTransparency = 1
	inputRow.AnchorPoint = Vector2.new(0, 1)
	inputRow.Position = UDim2.new(0, 0, 1, -52)
	inputRow.Size = UDim2.new(1, 0, 0, 40)
	inputRow.Parent = column
	local box = Instance.new("TextBox")
	box.AutoLocalize = false
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Font = Theme.Fonts.Mono
	box.TextSize = 18
	box.TextColor3 = GREEN
	box.PlaceholderColor3 = GREEN_DIM
	box.BackgroundColor3 = Color3.fromRGB(8, 22, 12)
	box.BorderSizePixel = 0
	box.Size = UDim2.new(0.62, -6, 1, 0)
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Selectable = true
	Localization.Bind(box, "ARCHIVE_FREQ_PLACEHOLDER", nil, "PlaceholderText")
	Components.Padding(box, 10, 0)
	box.Parent = inputRow
	local status = terminalText({ Text = "", TextSize = 14, Color = GREEN_DIM, Size = UDim2.new(1, 0, 0, 18), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -96), Parent = column })

	local back = Components.Button({ Key = "MENU_BACK", Height = 44, Parent = column })
	back.Instance.AnchorPoint = Vector2.new(0, 1)
	back.Instance.Position = UDim2.fromScale(0, 1)
	back.Instance.Size = UDim2.new(1, 0, 0, 44)
	back.Instance.Activated:Connect(function()
		router:Pop()
	end)

	local data = { logs = {}, photos = {}, achievements = {} }
	local titlesEarned, equippedTitle = {}, nil
	local category = "all"
	local render: () -> ()

	local transmit = Components.Button({ Key = "ARCHIVE_FREQ_SEND", Height = 40, Parent = inputRow, OnActivated = function()
		local text = box.Text
		if #string.gsub(text, "%s", "") == 0 then
			return
		end
		local ok, result = pcall(function()
			return Net.Function("SolveSecret"):InvokeServer(text)
		end)
		local outcome = if ok and type(result) == "table" then result.status else "error"
		status.TextColor3 = if outcome == "ok" then GREEN else GREEN_DIM
		Localization.Bind(status, if outcome == "ok" then "SECRET_SOLVED" elseif outcome == "known" then "SECRET_KNOWN" elseif outcome == "rate" then "CODE_RATE_LIMITED" else "SECRET_NOTHING", { count = if ok and type(result) == "table" then result.solvers or 0 else 0 })
		if outcome == "ok" then
			box.Text = ""
			data.logs[result.unlock] = os.time()
			render()
		end
	end })
	transmit.Instance.AnchorPoint = Vector2.new(1, 0)
	transmit.Instance.Position = UDim2.fromScale(1, 0)
	transmit.Instance.Size = UDim2.new(0.38, 0, 1, 0)
	transmit.Label.TextSize = 15

	local function openEntry(item)
		local doc = { title = item.title, body = item.body }
		if item.photo then
			local saved = data.photos[item.id] or {}
			doc.photo = {
				id = item.id,
				kind = item.photo,
				area = saved.area or "HALL",
				date = saved.date,
				subjects = { Players.LocalPlayer.UserId }, -- others are never stored: silhouettes
				figureBehind = item.photo == "mate_dark",
			}
		end
		app.Hud.ShowDocument(doc)
	end

	render = function()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local order = 0
		if category == "achievements" then
			for _, achievement in Achievements do
				order += 1
				local done = data.achievements[achievement.id] ~= nil
				terminalText({ Text = (if done then "[OK]  " else "[  ]  ") .. Localization.T(achievement.name), TextSize = 16, Color = if done then GREEN else GREEN_DIM, LayoutOrder = order, Parent = list })
				order += 1
				terminalText({ Key = achievement.description, Params = { marks = achievement.marks }, TextSize = 13, Color = GREEN_DIM, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = order, Parent = list })
			end
			return
		end
		if category == "titles" then
			for _, title in Titles.List do
				order += 1
				if titlesEarned[title.id] then
					local button
					button = Components.Button({ Key = title.name, TagKey = if equippedTitle == title.id then "SHOP_EQUIPPED" else "SHOP_EQUIP", Height = 40, LayoutOrder = order, Parent = list, OnActivated = function()
						local wearing = equippedTitle == title.id
						pcall(function()
							Net.Function("ShopAction"):InvokeServer("title", if wearing then "" else title.id)
						end)
						equippedTitle = if wearing then nil else title.id
						render()
					end })
					button.Label.TextColor3 = GREEN
				else
					terminalText({ Key = title.hint, TextSize = 15, Color = GREEN_DIM, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = order, Parent = list })
				end
			end
			return
		end
		local found, total = 0, 0
		for index, item in Lore do
			if category == "all" or item.category == category then
				total += 1
				order += 1
				local number = string.format("07-%02d", index)
				if data.logs[item.id] then
					found += 1
					local button = Components.Button({
						Text = string.format("[%s]  %s", number, Localization.T(item.title)),
						TagKey = "ARCHIVE_CAT_" .. string.upper(item.category),
						Height = 40,
						LayoutOrder = order,
						Parent = list,
						OnActivated = function()
							openEntry(item)
						end,
					})
					button.Label.Font = Theme.Fonts.Mono
					button.Label.TextSize = 15
					button.Label.TextColor3 = GREEN
					button.Tag.TextColor3 = GREEN_DIM
				elseif item.links then
					local have = 0
					for _, link in item.links do
						if data.logs[link] then
							have += 1
						end
					end
					terminalText({ Key = "ARCHIVE_LINK_PROGRESS", Params = { number = number, have = have, need = #item.links }, TextSize = 15, Color = GREEN_DIM, LayoutOrder = order, Parent = list })
				else
					terminalText({ Key = "ARCHIVE_LOCKED", Params = { number = number }, TextSize = 15, Color = GREEN_DIM, LayoutOrder = order, Parent = list })
				end
			end
		end
		order += 1
		terminalText({ Key = "ARCHIVE_COUNT", Params = { found = found, total = total }, TextSize = 13, Color = GREEN_DIM, LayoutOrder = order, Parent = list })
	end

	local tabButtons = {}
	for index, name in CATEGORIES do
		local tab = Components.Button({ Key = "ARCHIVE_CAT_" .. string.upper(name), Height = 34, LayoutOrder = index, Parent = tabs, OnActivated = function()
			category = name
			for n, b in tabButtons do
				b.SetFocused(n == name)
			end
			render()
		end })
		tab.Instance.Size = UDim2.fromOffset(150, 34)
		tab.Instance.AutomaticSize = Enum.AutomaticSize.X
		tab.Label.Font = Theme.Fonts.Mono
		tab.Label.TextSize = 14
		tab.Label.TextColor3 = GREEN
		tabButtons[name] = tab
	end
	tabButtons.all.SetFocused(true)
	render()

	task.spawn(function()
		local okProfile, profile = pcall(function()
			return Net.Function("FetchProfile"):InvokeServer()
		end)
		local okShop, shop = pcall(function()
			return Net.Function("ShopAction"):InvokeServer("get")
		end)
		if not list.Parent then
			return
		end
		local secrets = (okProfile and type(profile) == "table" and profile.secrets) or app.Profile.secrets or {}
		data.logs = secrets.logs or {}
		data.photos = secrets.photos or {}
		data.achievements = (okProfile and type(profile) == "table" and profile.achievements) or {}
		if okShop and type(shop) == "table" then
			for _, id in shop.titles or {} do
				titlesEarned[id] = true
			end
			equippedTitle = shop.equipped and shop.equipped.title
		end
		render()
	end)

	return { Root = root, Focus = tabButtons.all.Instance }
end

return Archive
