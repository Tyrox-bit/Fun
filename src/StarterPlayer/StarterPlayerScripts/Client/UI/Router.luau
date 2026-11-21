-- Router: screen stack for menus with fades, gamepad focus and universal "back".
--
-- A screen module exposes .new(router, args) and returns:
--   { Root: GuiObject, Focus: GuiObject?, OnBack: (() -> boolean)?, Destroy: (() -> ())? }
-- OnBack returning true means "handled", otherwise the router pops the screen.
-- Back works with: gamepad B / Circle, keyboard Backspace, and the on-screen Back button.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))
local Theme = require(script.Parent.Theme)

local Router = {}
Router.__index = Router

function Router.new(container: GuiObject, input)
	local self = setmetatable({
		Container = container,
		Input = input,
		Stack = {},
		Changed = Signal.new(), -- fired with the number of open screens
		RootBackHandler = nil :: (() -> ())?, -- called when Back is pressed on the last screen
	}, Router)

	-- Modal button: frees the mouse in first person while any menu is open.
	local modal = Instance.new("TextButton")
	modal.Name = "MouseUnlock"
	modal.Modal = true
	modal.Text = ""
	modal.BackgroundTransparency = 1
	modal.Size = UDim2.fromOffset(0, 0)
	modal.Selectable = false
	modal.Visible = false
	modal.Parent = container
	self._modal = modal

	UserInputService.InputBegan:Connect(function(inputObject)
		if #self.Stack == 0 then
			return
		end
		local key = inputObject.KeyCode
		if self.ShouldIgnoreBack and self.ShouldIgnoreBack() then
			return -- e.g. a document is open on top of the menu: Back closes that first
		end
		if key == Enum.KeyCode.ButtonB or (key == Enum.KeyCode.Backspace and not UserInputService:GetFocusedTextBox()) then
			self:Back()
		end
	end)

	input.DeviceChanged:Connect(function()
		self:RefreshFocus()
	end)

	return self
end

function Router:Top()
	return self.Stack[#self.Stack]
end

function Router:IsOpen(): boolean
	return #self.Stack > 0
end

function Router:RefreshFocus()
	local top = self:Top()
	if top and self.Input.GetDevice() == "gamepad" then
		local current = GuiService.SelectedObject
		if not current or not current:IsDescendantOf(top.Root) then
			GuiService.SelectedObject = top.Focus
		end
	elseif not top then
		GuiService.SelectedObject = nil
	end
end

local function fadeIn(root: GuiObject)
	root.Visible = true
	if root:IsA("CanvasGroup") then
		root.GroupTransparency = 1
		TweenService:Create(root, Theme.Fade, { GroupTransparency = 0 }):Play()
	end
	local column = root:FindFirstChild("Column")
	if column and column:IsA("GuiObject") then
		local target = column:GetAttribute("FZ_Home") or column.Position
		column:SetAttribute("FZ_Home", target)
		column.Position = target + UDim2.fromOffset(-28, 0)
		TweenService:Create(column, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = target }):Play()
	end
end

function Router:_show(screen)
	screen.Root.Parent = self.Container
	fadeIn(screen.Root)
	self._modal.Visible = true
	self:RefreshFocus()
	self.Changed:Fire(#self.Stack)
end

function Router:Push(screenModule, args: any?)
	local previous = self:Top()
	if previous then
		previous.Root.Visible = false
	end
	local screen = screenModule.new(self, args)
	table.insert(self.Stack, screen)
	self:_show(screen)
	return screen
end

function Router:Pop()
	local screen = table.remove(self.Stack)
	if not screen then
		return
	end
	if screen.Destroy then
		screen.Destroy()
	end
	screen.Root:Destroy()
	local top = self:Top()
	if top then
		self:_show(top)
	else
		self._modal.Visible = false
		GuiService.SelectedObject = nil
		self.Changed:Fire(0)
	end
end

function Router:Replace(screenModule, args: any?)
	self:Clear(true)
	return self:Push(screenModule, args)
end

function Router:Clear(silent: boolean?)
	while #self.Stack > 0 do
		local screen = table.remove(self.Stack)
		if screen.Destroy then
			screen.Destroy()
		end
		screen.Root:Destroy()
	end
	self._modal.Visible = false
	GuiService.SelectedObject = nil
	if not silent then
		self.Changed:Fire(0)
	end
end

function Router:Back()
	local top = self:Top()
	if not top then
		return
	end
	if top.OnBack and top.OnBack() then
		return
	end
	if #self.Stack > 1 then
		self:Pop()
	elseif self.RootBackHandler then
		self.RootBackHandler()
	end
end

return Router
