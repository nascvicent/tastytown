local Players = game:GetService("Players")
Players.CharacterAutoLoads = true
local HouseService = require(script.services.HouseService)
local CharacterSaveSystem = require(script.services.CharacterSaveSystem)
CharacterSaveSystem.Start()

Players.PlayerAdded:Connect(HouseService.onPlayerAdded)
Players.PlayerRemoving:Connect(HouseService.onPlayerRemoving)
