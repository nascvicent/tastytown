local Players = game:GetService("Players")
local HouseService = require(script.services.HouseService)

Players.PlayerAdded:Connect(HouseService.onPlayerAdded)
Players.PlayerRemoving:Connect(HouseService.onPlayerRemoving)
