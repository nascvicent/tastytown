--[[
	Configuração do Mapa de teleporte.

	O mapa é uma miniatura 3D da cidade (ViewportFrame) com etiquetas de UI.
	O servidor (MapService) monta essa miniatura em ReplicatedStorage.MapMiniature
	clonando os destinos e o cenário abaixo, sem scripts e sem colisão.

	Destinos descobertos automaticamente:
	  • SpawnLocation do Workspace
	  • Cada filho da pasta Workspace.Predios (prédios novos entram sozinhos)
	  • "Extras" (ponte, rio) achados pelo nome, ou pelo Path se você definir
	  • Qualquer instância com a tag "MapDestination" (atributos opcionais: MapName, MapDescription)
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
	CineCorn = { Name = "CineCorn", Description = "O cinema mais crocante da cidade." },
	CoffeShop = { Name = "Coffee Shop", Description = "Café quentinho e música ambiente." },
	FruitGym = { Name = "Fruit Gym", Description = "Academia para frutas em forma." },
	-- Exemplo: esconder um prédio do mapa
	-- PredioEmObras = { Hidden = true },
}

MapConfig.Spawn = {
	Name = "Praça Central",
	Description = "O ponto de partida de todo mundo.",
}

MapConfig.Home = {
	Name = "Minha Casa",
	Description = "Volte para a sua casa.",
}

-- Pontos especiais. Patterns: padrões Lua aplicados ao nome em minúsculas.
-- Se souber o caminho exato, use Path = { "Pasta", "Ponte" } (ignora Patterns).
MapConfig.Extras = {
	{
		Id = "ponte",
		Name = "Ponte",
		Description = "A ponte sobre o Rio de Leite.",
		Patterns = { "^ponte", "^bridge" },
	},
	{
		Id = "rio",
		Name = "Rio de Leite",
		Description = "As margens do famoso Rio de Leite.",
		Path = { "Ruas", "RioLeite" },
		Patterns = { "^rio", "leite", "milk", "^river" },
	},
}

-- Cenário da miniatura (além dos destinos). Tire ARVORES se pesar no celular.
MapConfig.Scenery = {
	{ "Ruas", "Pistas" },
	{ "Ruas", "RioLeite" },
	{ "Ruas", "ARVORES" },
}

-- Câmera da miniatura
MapConfig.Camera = {
	Yaw = 45,        -- graus em torno do eixo vertical
	Pitch = 55,      -- graus olhando para baixo
	FieldOfView = 30,
	FocusZoom = 0.38, -- fração da distância da visão geral ao focar um destino
}

-- Rótulo (como a "raridade" dos cards) por tipo de destino
MapConfig.KindLabels = {
	spawn = "INÍCIO",
	building = "PRÉDIO",
	extra = "PASSEIO",
	custom = "LOCAL",
	home = "SUA CASA",
}

return MapConfig
