local MusicZoneController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local remoteEvent
local playersInZone = {}
local zones = {} -- Tabela para armazenar múltiplas zonas

-- Zona -> nome da peça detectora. A peça é procurada em todo o Workspace (os prédios
-- ficam em pastas, ex.: Workspace.Predios), com limite de tempo.
local ZONE_DETECTORS = {
	CoffeeShop = "CoffeeDetector",
	FruitGym = "FruitGymDetector",
}
local FIND_TIMEOUT = 15

local function findDetector(name)
	local deadline = os.clock() + FIND_TIMEOUT
	repeat
		local found = workspace:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then return found end
		task.wait(0.5)
	until os.clock() > deadline
	return nil
end

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
	-- Em segundo plano: um detector que sumiu do mapa desliga só a zona dele
	-- (antes o WaitForChild sem limite travava o script do servidor inteiro)
	for zoneName, detectorName in pairs(ZONE_DETECTORS) do
		task.spawn(function()
			local part = findDetector(detectorName)
			if part then
				MusicZoneController.registerZone(zoneName, part)
			else
				warn(("⚠️ MusicZone: peça '%s' não encontrada no Workspace; zona %s desativada"):format(detectorName, zoneName))
			end
		end)
	end

	-- Novas zonas: adicionar em ZONE_DETECTORS (ex.: Beach = "BeachDetector")
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