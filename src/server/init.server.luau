local Players = game:GetService("Players")

Players.CharacterAutoLoads = true
local HouseService = require(script.services.HouseService)
local CharacterSaveSystem = require(script.services.CharacterSaveSystem)
local CoinManager = require(script.controllers.CoinManager)


CharacterSaveSystem.Start()
CoinManager.start()

Players.PlayerAdded:Connect(HouseService.onPlayerAdded)
Players.PlayerRemoving:Connect(HouseService.onPlayerRemoving)