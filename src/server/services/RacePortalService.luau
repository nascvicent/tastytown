-- services/RacePortalService.lua
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local RacePortalService = {}

local LOBBY_PLACE_ID = 139403404752525 -- Lembre-se de ALTERAR para o PlaceId do Lobby de corrida

-- Cooldown pra evitar teleporte duplo
local teleportCooldowns = {}

function RacePortalService.Start()
	-- Espera o portal carregar no mapa
	local portal = workspace:WaitForChild("RacePortal")

	portal.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- Verifica Cooldown de 5s
		if teleportCooldowns[player.UserId] then return end
		teleportCooldowns[player.UserId] = true

		task.delay(5, function()
			teleportCooldowns[player.UserId] = nil
		end)

		-- Monta TeleportData com info do personagem
		local characterName = "LittlePizza"
		local originalNameValue = character:FindFirstChild("OriginalCharacterName")

		if originalNameValue then
			characterName = originalNameValue.Value
		end

		local teleportOptions = Instance.new("TeleportOptions")
		teleportOptions:SetTeleportData({
			CharacterName = characterName,
			FromCity = true,
		})

		-- Executa o teleporte com tratamento de erro
		local success, errorMessage = pcall(function()
			TeleportService:TeleportAsync(LOBBY_PLACE_ID, {player}, teleportOptions)
		end)

		if not success then
			warn("Erro ao teleportar o jogador para a corrida: " .. tostring(errorMessage))
			-- Se o teleporte falhar, removemos o cooldown na hora pra ele poder tentar de novo
			teleportCooldowns[player.UserId] = nil 
		end
	end)
end

return RacePortalService