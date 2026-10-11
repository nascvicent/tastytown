--[[
	Tema visual compartilhado das janelas (Shop, Inventário, Mapa).
	Cores e fontes extraídas do ShopGui/UIUtils para manter a coesão visual.
]]

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
Theme.BodyFont = Enum.Font.GothamMedium

Theme.Colors = {
	White = Color3.fromRGB(255, 255, 255),
	Black = Color3.fromRGB(0, 0, 0),

	-- Janela
	Panel = Color3.fromRGB(255, 170, 127),      -- fundo do ShopGui.Frame
	PanelStroke = Color3.fromRGB(205, 120, 85),
	Header = Color3.fromRGB(163, 108, 81),      -- ShopLabel / Paginas
	HeaderSolid = Color3.fromRGB(195, 130, 97), -- Header a 65% sobre o Panel, já misturado
	Page = Color3.fromRGB(163, 108, 81),

	-- Abas laterais
	Tile = Color3.fromRGB(196, 128, 88),
	TileSelected = Color3.fromRGB(255, 205, 120),
	TileSelectedStroke = Color3.fromRGB(255, 240, 200),

	-- Texto
	Text = Color3.fromRGB(100, 50, 0),          -- PADRAO_TEXTO
	TextSoft = Color3.fromRGB(130, 85, 55),

	-- Botões (mesmos do UIUtils.CORES)
	Green = Color3.fromRGB(46, 204, 113),       -- COMPRAR / EQUIPAR / IR
	Blue = Color3.fromRGB(52, 152, 219),        -- POSSUI / EQUIPADO
	Gray = Color3.fromRGB(127, 140, 141),
	Red = Color3.fromRGB(231, 76, 60),

	-- Mapa
	MapGround = Color3.fromRGB(129, 201, 120),
	MapHome = Color3.fromRGB(52, 152, 219),
	MapYou = Color3.fromRGB(255, 105, 180),
}

Theme.Transparency = {
	Page = 0.6,
}

Theme.Radius = {
	Panel = 18,
	Page = 14,
	Card = 12,
	Button = 8,
	Tile = 16,
}

Theme.Images = {
	Close = "rbxassetid://130802021099174",
	Car = "rbxassetid://135898697956083",
	House = "rbxassetid://102142271940166",
	Tag = "rbxassetid://123008814312942",
	Vip = "rbxassetid://83695921970431", -- Golden Spatula
}

-- Mesmo sistema de raridade do UIUtils do Shop
Theme.Rarity = {
	Common = { Color = Color3.fromRGB(160, 160, 160), Title = "COMUM", Order = 1 },
	Rare = { Color = Color3.fromRGB(52, 152, 219), Title = "RARO", Order = 2 },
	Legendary = { Color = Color3.fromRGB(241, 196, 15), Title = "LENDÁRIO", Order = 3 },
}

function Theme.GetRarity(name)
	return Theme.Rarity[name] or Theme.Rarity.Common
end

-- Escurece uma cor (usado nas bordas dos botões)
function Theme.Darken(color, amount)
	return color:Lerp(Theme.Colors.Black, amount or 0.25)
end

return Theme
