local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local teleportEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ScreenEvents"):WaitForChild("TeleportRequest")

teleportEvent.OnServerEvent:Connect(function(player, placeId, spawnName)
	-- Descobre qual personagem o jogador está usando
	local currentCharacterName
	local originalNameValue = player.Character and player.Character:FindFirstChild("OriginalCharacterName")
	if originalNameValue and originalNameValue:IsA("StringValue") then
		currentCharacterName = originalNameValue.Value
	else
		-- fallback: pega do DataStore
		local DataStoreService = game:GetService("DataStoreService")
		local CharacterStore = DataStoreService:GetDataStore("PlayerCharacterChoice")
		local success, saved = pcall(function()
			return CharacterStore:GetAsync(tostring(player.UserId))
		end)
		if success and saved then
			currentCharacterName = saved
		end
	end

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		TargetSpawn = spawnName,
		CharacterName = currentCharacterName
	})

	local success, result = pcall(function()
		TeleportService:TeleportAsync(placeId, {player}, options)
	end)

	if not success then
		warn("Erro ao teleportar " .. player.Name .. ":", result)
	end
end)
