--[[
	Catálogo de itens (raridade, descrição e câmera do preview 3D).
	Espelha as tabelas do LocalShopScript; o Inventário lê daqui.
	Ao adicionar um item na loja, adicione aqui também.
]]

local ItemCatalog = {}

ItemCatalog.Car = {
	["Wafer Racer"] = {
		Rarity = "Common",
		ModelName = "Wafer Racer",
		Description = "Um carro simples e doce para começar suas aventuras!",
		Camera = { offsetY = 0, distanceMultiplier = 0.7, cameraHeight = 0.7, cameraAngleX = 0, lookAtOffsetY = 0 },
	},
	["Peppermint Blue"] = {
		Rarity = "Rare",
		ModelName = "Peppermint Blue",
		Description = "Carro refrescante com design único!",
		Camera = { offsetY = 0, distanceMultiplier = 0.7, cameraHeight = 0.7, cameraAngleX = 0, lookAtOffsetY = 0 },
	},
	["Sunburst"] = {
		Rarity = "Legendary",
		ModelName = "Sunburst",
		Description = "O carro dos sonhos! Brilho e poder!",
		Camera = { offsetY = 0, distanceMultiplier = 0.7, cameraHeight = 0.7, cameraAngleX = 0, lookAtOffsetY = 0 },
	},
}

ItemCatalog.House = {
	["Candy Mansion"] = {
		Rarity = "Legendary",
		ModelName = "CandyMansion",
		Description = "Mansão de doces dos sonhos!",
		Camera = { offsetY = -20, distanceMultiplier = 0.7, cameraHeight = 0.3, cameraAngleX = math.rad(10), lookAtOffsetY = -5 },
	},
	["Cheese House"] = {
		Rarity = "Common",
		ModelName = "CheeseHouse",
		Description = "Casa aconchegante de queijo.",
		Camera = { offsetY = 0, distanceMultiplier = 0.6, cameraHeight = 0.3, cameraAngleX = math.rad(-15), lookAtOffsetY = 0 },
	},
	["Sushi House"] = {
		Rarity = "Rare",
		ModelName = "SushiHouse",
		Description = "Casa estilo japonês moderna.",
		Camera = { offsetY = 0, distanceMultiplier = 0.4, cameraHeight = 0.7, cameraAngleX = math.rad(10), lookAtOffsetY = -5 },
	},
}

-- Tags não têm modelo 3D; o preview é a própria plaquinha
ItemCatalog.Tag = {}

function ItemCatalog.Get(category, itemName)
	local list = ItemCatalog[category]
	return (list and list[itemName]) or { Rarity = "Common" }
end

return ItemCatalog
