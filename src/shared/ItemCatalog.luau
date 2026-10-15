--[[
	Catálogo de itens — fonte única para o Shop e o Inventário.

	O preço aqui é só para exibir; quem cobra é o ShopService (ShopService.Prices).
	Ao adicionar um item, atualize os dois lugares.

	Campos:
		Name, Price, Rarity ("Common" | "Rare" | "Legendary"), Description
		ModelName: modelo em ReplicatedStorage.ShopModels (carros e casas)
		Camera: enquadramento do preview 3D
		Image / Color: ícone (itens VIP)
]]

local ItemCatalog = {}

-- Casa que todo jogador já possui e usa por padrão
ItemCatalog.StarterHouse = "Casa de Biscoito"

local DEFAULT_CAMERA ={ offsetY = 0, distanceMultiplier = 0.7, cameraHeight = 0.7, cameraAngleX = 0, lookAtOffsetY = 0 }

-- Pastas em ReplicatedStorage.ShopModels com os modelos de vitrine
ItemCatalog.ModelFolders = {
	Car = "ModelosCarros",
	House = "ModelosCasas",
}

ItemCatalog.Items = {
	Car = {
		{
			Name = "Wafer Racer",
			Price = 50,
			Rarity = "Common",
			ModelName = "Wafer Racer",
			Camera = DEFAULT_CAMERA,
			Description = "🍪 Um carro simples e doce para começar suas aventuras!\n\n• Velocidade: Baixa\n• Estilo: Casual",
		},
		{
			Name = "Peppermint Blue",
			Price = 500,
			Rarity = "Rare",
			ModelName = "Peppermint Blue",
			Camera = DEFAULT_CAMERA,
			Description = "🍬 Carro refrescante com design único!\n\n• Velocidade: Média\n• Estilo: Elegante\n• Bonus: +10% XP",
		},
		{
			Name = "Sunburst",
			Price = 15000,
			Rarity = "Legendary",
			ModelName = "Sunburst",
			Camera = DEFAULT_CAMERA,
			Description = "☀️ O carro dos sonhos! Brilho e poder!\n\n• Velocidade: MÁXIMA\n• Estilo: Luxuoso\n• Bonus: +25% XP\n• Efeito: Partículas Douradas",
		},
	},

	House = {
		-- Casa inicial: todo jogador possui (InventoryService), não aparece no Shop
		{
			Name = "Casa de Biscoito",
			Price = 0,
			Rarity = "Common",
			ModelName = "CasaDeBiscoito",
			ShopHidden = true,
			Camera = { offsetY = 0, distanceMultiplier = 0.6, cameraHeight = 0.45, cameraAngleX = 0, lookAtOffsetY = 0 },
			Description = "🍪 Casinha de crackers e biscoito recheado\n\n• A primeira casa de todo morador\n• Aconchegante e crocante!",
		},
		{
			Name = "Cheese House",
			Price = 5000,
			Rarity = "Common",
			ModelName = "CheeseHouse",
			Camera = { offsetY = 0, distanceMultiplier = 0.6, cameraHeight = 0.3, cameraAngleX = math.rad(-15), lookAtOffsetY = 0 },
			Description = "🧀 Casa aconchegante de queijo\n\n• 1 andar\n• Garagem para 1 carro\n• Perfeita para começar!",
		},
		{
			Name = "Sushi House",
			Price = 10000,
			Rarity = "Legendary",
			ModelName = "SushiHouse",
			Camera = { offsetY = 0, distanceMultiplier = 0.45, cameraHeight = 0.6, cameraAngleX = 0, lookAtOffsetY = 0 },
			Description = "🍣 Casa estilo japonês moderna\n\n• 2 andares\n• Jardim zen\n• Garagem para 2 carros\n\n🎌 Design único!",
		},
		{
			Name = "Candy Mansion",
			Price = 25000,
			Rarity = "Legendary",
			ModelName = "CandyMansion",
			Camera = { offsetY = 0, distanceMultiplier = 0.6, cameraHeight = 0.45, cameraAngleX = 0, lookAtOffsetY = 0 },
			Description = "🏰 Mansão de doces dos sonhos!\n\n• 3 andares\n• Piscina de chocolate\n• Garagem para 5 carros\n\n✨ Status MÁXIMO!",
		},
	},

	Vip = {
		{
			Name = "Driver License VIP",
			Price = 0,
			Rarity = "Common",
			Image = "rbxassetid://7202697837",
			Color = Color3.fromRGB(200, 200, 200),
			Description = "🎫 Licença básica de motorista\n\n✓ Acesso a todos os carros COMUNS\n✓ Sem benefícios extras\n\n💡 Perfeito para iniciantes!",
		},
		{
			Name = "Gourmet Pass",
			Price = 250,
			Rarity = "Rare",
			Image = "rbxassetid://135911879582619",
			Color = Color3.fromRGB(255, 215, 0),
			Description = "🌟 Passe para verdadeiros gourmets!\n\n✓ Todos os itens COMUNS\n✓ Todos os itens RAROS\n✓ +15% de dinheiro em missões\n✓ Acesso a áreas VIP\n\n💎 Recomendado!",
		},
		{
			Name = "Golden Spatula",
			Price = 5000,
			Rarity = "Legendary",
			Image = "rbxassetid://83695921970431",
			Color = Color3.fromRGB(255, 255, 255),
			Description = "👑 A ESPÁTULA LENDÁRIA!\n\n✓ TODOS os itens do jogo desbloqueados!\n✓ Carros, Casas e Itens LENDÁRIOS\n✓ +50% dinheiro e XP\n✓ Partículas Douradas exclusivas\n✓ Chat colorido especial\n✓ Acesso prioritário a updates\n\n🔥 ULTIMATE POWER!",
		},
	},

	-- Tags não têm modelo 3D; o preview é a própria plaquinha
	Tag = {},
}

-- Índice por nome para buscas rápidas: ItemCatalog.Get("Car", "Sunburst")
local index = {}
for category, list in pairs(ItemCatalog.Items) do
	index[category] = {}
	for _, item in ipairs(list) do
		index[category][item.Name] = item
	end
end

function ItemCatalog.Get(category, itemName)
	local byName = index[category]
	return (byName and byName[itemName]) or { Name = itemName, Rarity = "Common" }
end

-- Modelo de vitrine (sem scripts) para o preview 3D, ou nil
function ItemCatalog.FindModel(category, item)
	local folderName = ItemCatalog.ModelFolders[category]
	if not folderName or not item.ModelName then return nil end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local shopModels = ReplicatedStorage:FindFirstChild("ShopModels")
	local folder = shopModels and shopModels:FindFirstChild(folderName)
	local model = folder and folder:FindFirstChild(item.ModelName)
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

return ItemCatalog
