-- Visual language of every interface: quiet, cinematic, high contrast, one accent colour.

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(6, 8, 9),
	Panel = Color3.fromRGB(13, 17, 19),
	PanelLine = Color3.fromRGB(38, 44, 46),
	Text = Color3.fromRGB(206, 202, 192),
	TextBright = Color3.fromRGB(240, 236, 226),
	TextDim = Color3.fromRGB(128, 134, 131),
	TextFaint = Color3.fromRGB(78, 84, 82),
	Accent = Color3.fromRGB(201, 64, 48), -- "signal red": focus bar, warnings, live signal
	Radio = Color3.fromRGB(214, 184, 120), -- unknown voices on the radio (warm amber)
	Relay = Color3.fromRGB(146, 192, 188), -- the Relay voice (cold teal)
	World = Color3.fromRGB(180, 180, 172), -- sound captions
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
	Button = 48,
	Gap = 6,
	TextTitle = 30,
	TextHeading = 24,
	TextButton = 22,
	TextBody = 18,
	TextSmall = 15,
	Margin = 48,
	ContentWidth = 440,
}

Theme.Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Theme.Fade = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Theme.Slow = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

function Theme.Hex(color: Color3): string
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

return Theme
