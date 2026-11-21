-- DecisionPanel: the team vote UI. Big buttons, live vote counts, a time bar.
-- Mouse is freed while it is open (first person), gamepad focus jumps to the first option,
-- touch just taps. Movement keeps working - the world does not pause for a vote.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)

local DecisionPanel = {}

local root: Frame
local promptLabel: TextLabel
local optionsRow: Frame
local timeBar: Frame
local current: { [string]: any }? = nil
local myVote: number? = nil
local buttons: { any } = {}
local timer: RBXScriptConnection? = nil
local input = nil

local function close()
	current = nil
	myVote = nil
	root.Visible = false
	if timer then
		timer:Disconnect()
		timer = nil
	end
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root) then
		GuiService.SelectedObject = nil
	end
end

local function render(decision)
	local changed = not current or current.id ~= decision.id
	if changed then
		decision.total = math.max(1, decision.ends - workspace:GetServerTimeNow())
	else
		decision.total = (current :: any).total
	end
	current = decision
	root.Visible = true
	Localization.Bind(promptLabel, decision.prompt, decision.promptParams)
	if changed then
		myVote = nil
		for _, b in buttons do
			b.Instance:Destroy()
		end
		table.clear(buttons)
		for index, key in decision.options do
			local button = Components.Button({
				Key = key,
				TagKey = "DECISION_VOTES",
				TagParams = { count = 0 },
				LayoutOrder = index,
				Parent = optionsRow,
				OnActivated = function()
					if current and current.id == decision.id then
						myVote = index
						Net.Event("DecisionVote"):FireServer(decision.id, index)
						for i, b in buttons do
							b.SetFocused(i == index)
						end
					end
				end,
			})
			button.Instance.Size = UDim2.new(1 / #decision.options, -6, 1, 0)
			table.insert(buttons, button)
		end
		if input.GetDevice() == "gamepad" and buttons[1] then
			GuiService.SelectedObject = buttons[1].Instance
		end
	end
	for index, button in buttons do
		Localization.Bind(button.Tag, "DECISION_VOTES", { count = decision.counts[index] or 0 })
		button.Tag.Visible = true
	end
	if not timer then
		timer = RunService.Heartbeat:Connect(function()
			local d = current
			if not d then
				return
			end
			local remaining = math.max(0, d.ends - workspace:GetServerTimeNow())
			timeBar.Size = UDim2.new(math.clamp(remaining / (d.total or 20), 0, 1), 0, 0, 2)
		end)
	end
end

function DecisionPanel.Init(hudGui: ScreenGui, inputController)
	input = inputController
	root = Instance.new("Frame")
	root.Name = "Decision"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -150)
	root.Size = UDim2.fromOffset(560, 120)
	root.BackgroundColor3 = Theme.Colors.Panel
	root.BackgroundTransparency = 0.1
	root.BorderSizePixel = 0
	root.Visible = false
	root.ZIndex = 15
	root.Parent = hudGui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Relay
	stroke.Transparency = 0.4
	stroke.Parent = root
	Components.Padding(root, 14, 10)
	local unlock = Instance.new("TextButton")
	unlock.Modal = true
	unlock.Text = ""
	unlock.BackgroundTransparency = 1
	unlock.Size = UDim2.fromOffset(0, 0)
	unlock.Selectable = false
	unlock.Parent = root

	promptLabel = Components.Text({ Text = "", Font = Theme.Fonts.Medium, TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.TextBright, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 28), Parent = root })
	optionsRow = Instance.new("Frame")
	optionsRow.BackgroundTransparency = 1
	optionsRow.Position = UDim2.fromOffset(0, 36)
	optionsRow.Size = UDim2.new(1, 0, 0, Theme.Sizes.Button)
	optionsRow.Parent = root
	Components.List(optionsRow, 8, true)
	timeBar = Instance.new("Frame")
	timeBar.BackgroundColor3 = Theme.Colors.Relay
	timeBar.BorderSizePixel = 0
	timeBar.AnchorPoint = Vector2.new(0, 1)
	timeBar.Position = UDim2.fromScale(0, 1)
	timeBar.Size = UDim2.new(1, 0, 0, 2)
	timeBar.Parent = root

	Net.Event("Decision").OnClientEvent:Connect(function(decision)
		if type(decision) ~= "table" then
			close()
		else
			render(decision)
		end
	end)
end

return DecisionPanel
