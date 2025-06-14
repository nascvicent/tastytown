local Players = game:GetService("Players")

Players.CharacterAutoLoads = true
local HouseService = require(script.services.HouseService)
local CharacterSaveSystem = require(script.services.CharacterSaveSystem)
local CoinManager = require(script.controllers.CoinManager)

CoinManager.start();
CharacterSaveSystem.Start()
Players.PlayerAdded:Connect(HouseService.onPlayerAdded)
Players.PlayerRemoving:Connect(HouseService.onPlayerRemoving)




-- Inicia o sistema de moedas (DataStore e leaderstats)
CoinManager.start()

