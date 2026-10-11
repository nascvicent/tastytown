local Players = game:GetService("Players")

local HouseService = require(script.services.HouseService)
local CharacterSaveSystem = require(script.services.CharacterSaveSystem)
local CoinManager = require(script.controllers.CoinManager)
local ShopService = require(script.services.ShopService)
local MusicZoneController = require(script.controllers.MusicZoneController)
local RacePortalService = require(script.services.RacePortalService)
local MapService = require(script.services.MapService)
local InteriorService = require(script.services.InteriorService)

-- Requisitando o novo módulo de inventário
local InventoryService = require(script.services.InventoryService) -- Ajuste o caminho conforme necessário

-- Inicialização
CharacterSaveSystem.Start()
MapService.Start()
InteriorService.Start()
CoinManager.start()
ShopService.Start()
MusicZoneController.Start()
RacePortalService.Start()

-- Inicializando o sistema de Inventário
InventoryService.Start() 

-- Conexões pendentes
Players.PlayerAdded:Connect(HouseService.onPlayerAdded)
Players.PlayerRemoving:Connect(HouseService.onPlayerRemoving)

-- Jogadores que entraram antes do PlayerAdded ser conectado (comum no Play do Studio)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(HouseService.onPlayerAdded, player)
end