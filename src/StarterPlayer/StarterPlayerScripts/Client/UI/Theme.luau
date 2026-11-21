-- Visual language of every interface: quiet, cinematic, high contrast, one accent colour.

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(5, 7, 10),
	Panel = Color3.fromRGB(12, 16, 21),
	PanelRaised = Color3.fromRGB(20, 26, 33),
	PanelLine = Color3.fromRGB(52, 62, 72),
	Text = Color3.fromRGB(212, 216, 220),
	TextBright = Color3.fromRGB(246, 246, 242),
	TextDim = Color3.fromRGB(136, 146, 156),
	TextFaint = Color3.fromRGB(82, 92, 102),
	Accent = Color3.fromRGB(232, 62, 50), -- "signal red": focus, warnings, live signal
	AccentDeep = Color3.fromRGB(120, 22, 18),
	Radio = Color3.fromRGB(226, 192, 124), -- unknown voices on the radio (warm amber)
	Relay = Color3.fromRGB(140, 214, 208), -- the Relay voice (cold teal)
	World = Color3.fromRGB(190, 192, 186), -- sound captions
	Good = Color3.fromRGB(120, 214, 150),
}

Theme.Fonts = {
	Title = Enum.Font.Michroma,
	Body = Enum.Font.BuilderSans,
	Medium = Enum.Font.BuilderSansMedium,
	Bold = Enum.Font.BuilderSansBold,
	Mono = Enum.Font.RobotoMono,
}

-- Logical sizes at UIScale 1 (UIScale adapts them to the device, see Components.AttachScale).
Theme.Sizes = {
	Button = 52,
	Gap = 6,
	TextTitle = 30,
	TextHeading = 24,
	TextButton = 22,
	TextBody = 18,
	TextSmall = 15,
	Margin = 48,
	ContentWidth = 460,
	Corner = 6,
}

Theme.Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Theme.Fade = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Theme.Slow = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

function Theme.Hex(color: Color3): string
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

return Theme
