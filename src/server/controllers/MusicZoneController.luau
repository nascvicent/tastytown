local MusicZoneController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local remoteEvent
local playersInZone = {}
local zones = {} -- Tabela para armazenar múltiplas zonas

-- Inicializa o serviço
function MusicZoneController.Start()
	-- Cria o RemoteEvent
	remoteEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild('MusicZoneEvent')
	if not remoteEvent then
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = "MusicZoneEvent"
		remoteEvent.Parent = ReplicatedStorage
	end

	-- Configura as zonas
	MusicZoneController.setupZones()

	-- Inicia o loop de detecção
	MusicZoneController.startDetection()

	print("✅ MusicZoneService iniciado")
end

-- Configura as zonas de música
function MusicZoneController.setupZones()
	-- Zona do Coffee Shop
	local coffeeShopPart = workspace:WaitForChild("CoffeeInside"):WaitForChild('CoffeeDetector') -- Ajuste o caminho
	if coffeeShopPart then
		MusicZoneController.registerZone("CoffeeShop", coffeeShopPart)
	end
	
	--local FruitGymDetector = workspace:WaitForChild("FruitGymInside"):WaitForChild('FruitGymDetector') 
	local FruitGymDetector = workspace:WaitForChild('FruitGymDetector')
	if FruitGymDetector then
		MusicZoneController.registerZone("FruitGym", FruitGymDetector)
	end
	

	-- Parte para adicionar novas zonas
	-- 
	-- MusicZoneService.registerZone("Beach", workspace.BeachZone)
end

-- Registra uma nova zona
function MusicZoneController.registerZone(zoneName, part)
	if not part then
		warn("⚠️ Part não encontrada para zona:", zoneName)
		return
	end

	zones[zoneName] = {
		Part = part,
		PlayersInside = {}
	}

	print("📍 Zona registrada:", zoneName)
end

-- Sistema de detecção contínua
function MusicZoneController.startDetection()
	RunService.Heartbeat:Connect(function()
		for _, player in pairs(Players:GetPlayers()) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				MusicZoneController.checkPlayerZones(player)
			end
		end
	end)
end

-- Verifica em qual zona o jogador está
function MusicZoneController.checkPlayerZones(player)
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Inicializa o estado do jogador se não existir
	if not playersInZone[player] then
		playersInZone[player] = {
			CurrentZone = nil
		}
	end

	local currentZone = nil

	-- Verifica cada zona
	for zoneName, zoneData in pairs(zones) do
		local part = zoneData.Part
		local distance = (hrp.Position - part.Position).Magnitude
		local maxDistance = (part.Size.Magnitude / 2) + 5

		if distance <= maxDistance then
			currentZone = zoneName
			break
		end
	end

	-- Se a zona mudou, notifica o cliente
	if playersInZone[player].CurrentZone ~= currentZone then
		local previousZone = playersInZone[player].CurrentZone
		playersInZone[player].CurrentZone = currentZone

		-- Envia evento para o cliente
		remoteEvent:FireClient(player, currentZone)

		-- Debug
		if currentZone then
			print(player.Name .. " entrou na zona:", currentZone)
		elseif previousZone then
			print(player.Name .. " saiu da zona:", previousZone)
		end
	end
end

-- Limpa dados quando jogador sai
Players.PlayerRemoving:Connect(function(player)
	playersInZone[player] = nil
end)

return MusicZoneController