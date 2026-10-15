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
-- Cada serviço na própria thread: um que trave esperando algo do mapa (WaitForChild de
-- uma peça que mudou de pasta) ou dê erro não impede os seguintes de iniciar. O
-- MusicZoneController travado no FruitGymDetector deixava o InventoryService e o
-- HouseService desligados: ninguém ganhava casa e o jogador nascia no limbo.
task.spawn(CharacterSaveSystem.Start)
task.spawn(MapService.Start)
task.spawn(InteriorService.Start)
task.spawn(CoinManager.start)
task.spawn(ShopService.Start)
task.spawn(MusicZoneController.Start)
task.spawn(RacePortalService.Start)

-- Inicializando o sistema de Inventário
task.spawn(InventoryService.Start)

-- Conexões pendentes
Players.PlayerAdded:Connect(HouseService.onPlayerAdded)
Players.PlayerRemoving:Connect(HouseService.onPlayerRemoving)

-- Jogadores que entraram antes do PlayerAdded ser conectado (comum no Play do Studio)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(HouseService.onPlayerAdded, player)
end