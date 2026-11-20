-- Language selection. Used on the very first start (before the main menu, cannot be
-- skipped with Back) and from Settings -> Language. One click / one button press selects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Localization = require(Shared.Localization)

local Components = require(script.Parent.Parent.Components)
local Theme = require(script.Parent.Parent.Theme)

local LanguageSelect = {}

-- args: { firstStart: boolean, suggested: string?, onChosen: ((string) -> ())? }
function LanguageSelect.new(router, args)
	local app = router.App
	local firstStart = args and args.firstStart
	local suggested = args and args.suggested
	local current = if firstStart then suggested else app.Settings.Get("language")

	local root = Instance.new("CanvasGroup")
	root.Name = "LanguageSelect"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)

	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.5)
	column.Size = UDim2.new(0, 420, 1, -32)
	column.Parent = root
	local layout = Components.List(column, Theme.Sizes.Gap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	if firstStart then
		Components.Text({ Text = "FREQUENCY ZERO", Font = Theme.Fonts.Title, TextSize = 18, Color = Theme.Colors.TextDim, LayoutOrder = 1, Parent = column })
	end
	Components.Heading(column, "LANG_PROMPT", 2)
	if firstStart and Localization.GetLanguage() ~= Config.FallbackLanguage then
		-- Bilingual header on first start, in case the suggestion is wrong.
		Components.Text({
			Text = Localization.T("LANG_PROMPT", nil, Config.FallbackLanguage),
			Font = Theme.Fonts.Body,
			TextSize = Theme.Sizes.TextBody,
			Color = Theme.Colors.TextDim,
			LayoutOrder = 3,
			Parent = column,
		})
	end
	Components.Spacer(column, 8, 4)

	local focus = nil
	for index, code in Config.Languages do
		local button = Components.Button({
			Text = Config.LanguageNames[code],
			TagKey = if code == suggested and firstStart then "LANG_SUGGESTED" else nil,
			LayoutOrder = 10 + index,
			Parent = column,
			OnActivated = function()
				if firstStart and args.onChosen then
					args.onChosen(code)
				else
					app.Settings.Set("language", code)
					router:Pop()
				end
			end,
		})
		if code == current or (focus == nil and index == 1) then
			focus = button.Instance
		end
		if code == current and not firstStart then
			button.Tag.Visible = true
			button.Tag.Text = "●"
			button.Tag.TextColor3 = Theme.Colors.Accent
		end
	end

	Components.Spacer(column, 8, 20)
	Components.Text({ Key = "LANG_HINT", TextSize = Theme.Sizes.TextSmall, Color = Theme.Colors.TextDim, AutoY = true, Size = UDim2.fromScale(1, 0), LayoutOrder = 21, Parent = column })
	if not firstStart then
		Components.Button({ Key = "MENU_BACK", LayoutOrder = 30, Parent = column, OnActivated = function()
			router:Pop()
		end })
	end

	return {
		Root = root,
		Focus = focus,
		OnBack = function()
			return firstStart == true -- first start: a language must be chosen
		end,
	}
end

return LanguageSelect
