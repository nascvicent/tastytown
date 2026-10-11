--[[
	Configuração do Mapa de teleporte.

	Destinos são descobertos automaticamente pelo servidor (MapService):
	  • SpawnLocation do Workspace
	  • Cada filho da pasta Workspace.Predios (prédios novos entram sozinhos)
	  • "Extras" (ponte, rio) achados pelo nome, ou pelo Path se você definir
	  • Qualquer instância com a tag "MapDestination" (atributos opcionais: MapName, MapIcon)
	  • A casa do próprio jogador

	Ponto de pouso: se o destino tiver uma Part chamada "MapSpawn" (em qualquer
	nível), o jogador aparece em cima dela. Sem isso, o servidor calcula um ponto
	no chão em frente à "Porta" (ou ao redor do modelo), fora de água/leite.
]]

local MapConfig = {}

MapConfig.BuildingsFolder = "Predios"
MapConfig.Tag = "MapDestination"
MapConfig.TeleportCooldown = 3

-- Ajustes por nome da instância no Workspace
MapConfig.Overrides = {
	CineCorn = { Name = "CineCorn", Icon = "🍿", Description = "O cinema mais crocante da cidade." },
	CoffeShop = { Name = "Coffee Shop", Icon = "☕", Description = "Café quentinho e música ambiente." },
	FruitGym = { Name = "Fruit Gym", Icon = "🍎", Description = "Academia para frutas em forma." },
	-- Exemplo: Esconder um prédio do mapa
	-- PredioEmObras = { Hidden = true },
}

MapConfig.Spawn = {
	Name = "Praça Central",
	Icon = "⭐",
	Description = "O ponto de partida de todo mundo.",
}

MapConfig.Home = {
	Name = "Minha Casa",
	Icon = "🏠",
	Description = "Volte para a sua casa.",
}

-- Pontos especiais. Patterns: padrões Lua aplicados ao nome em minúsculas.
-- Se souber o caminho exato, use Path = { "Pasta", "Ponte" } (ignora Patterns).
MapConfig.Extras = {
	{
		Id = "ponte",
		Name = "Ponte",
		Icon = "🌉",
		Description = "A ponte sobre o Rio de Leite.",
		Patterns = { "^ponte", "^bridge" },
	},
	{
		Id = "rio",
		Name = "Rio de Leite",
		Icon = "🥛",
		Description = "As margens do famoso Rio de Leite.",
		Patterns = { "^rio", "leite", "milk", "^river" },
	},
}

-- Opcional: imagem de fundo do mapa (ex.: print da cidade vista de cima).
-- Ao usar, defina WorldBounds com as coordenadas do Workspace que a imagem cobre
-- (topo da imagem = MinZ, esquerda = MinX).
MapConfig.MapImage = ""
MapConfig.WorldBounds = nil -- { MinX = -500, MaxX = 500, MinZ = -500, MaxZ = 500 }

return MapConfig
