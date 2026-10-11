-- ServerScriptService/services/RaceQueueService.lua
-- ESTE SCRIPT FICA NA CIDADE (Place principal), NÃO no Place de corrida!
-- Gerencia filas de corrida e teleporta jogadores juntos.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaceQueueService = {}

-- ========================================
-- CONFIGURAÇÃO DAS PISTAS
-- ========================================
-- PlaceId de cada pista de corrida
RaceQueueService.TRACKS = {
	DesertDash = {
		placeId = 104786234761653,  -- ALTERE para o PlaceId real do Place "Desert Dash"
		displayName = "Candy Rush",
		maxPlayers = 8,
		minPlayers = 2,
		queueTimeout = 30,  -- segundos máx esperando na fila
	},
	-- IceCreamCircuit = {
	-- 	placeId = 0,
	-- 	displayName = "Ice Cream Circuit",
	-- 	maxPlayers = 8,
	-- 	minPlayers = 2,
	-- 	queueTimeout = 30,
	-- },
}

-- Filas ativas: [trackKey] = { players = {player, ...}, startTime = tick() }
RaceQueueService._queues = {}

-- ========================================
-- REMOTES
-- ========================================
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

-- Client → Server: jogador quer entrar na fila
local joinQueueRemote = Instance.new("RemoteEvent")
joinQueueRemote.Name = "JoinRaceQueue"
joinQueueRemote.Parent = remotesFolder

-- Client → Server: jogador quer sair da fila
local leaveQueueRemote = Instance.new("RemoteEvent")
leaveQueueRemote.Name = "LeaveRaceQueue"
leaveQueueRemote.Parent = remotesFolder

-- Server → Client: atualização do status da fila
local queueUpdateRemote = Instance.new("RemoteEvent")
queueUpdateRemote.Name = "RaceQueueUpdate"
queueUpdateRemote.Parent = remotesFolder

-- ========================================
-- LÓGICA DA FILA
-- ========================================

--- Jogador entra na fila de uma pista
function RaceQueueService.JoinQueue(player, trackKey)
	local trackConfig = RaceQueueService.TRACKS[trackKey]
	if not trackConfig then
		warn("[RaceQueue] Pista não encontrada:", trackKey)
		return
	end

	-- Remove de qualquer fila anterior
	RaceQueueService.LeaveAllQueues(player)

	-- Cria fila se não existe
	if not RaceQueueService._queues[trackKey] then
		RaceQueueService._queues[trackKey] = {
			players = {},
			startTime = tick(),
		}
	end

	local queue = RaceQueueService._queues[trackKey]

	-- Checa se já está cheio
	if #queue.players >= trackConfig.maxPlayers then
		queueUpdateRemote:FireClient(player, {
			status = "full",
			trackKey = trackKey,
			message = "Fila cheia! Tente novamente em breve.",
		})
		return
	end

	-- Adiciona à fila
	table.insert(queue.players, player)
	print("[RaceQueue]", player.Name, "entrou na fila:", trackConfig.displayName, "(" .. #queue.players .. "/" .. trackConfig.maxPlayers .. ")")

	-- Notifica todos na fila
	RaceQueueService._notifyQueue(trackKey)

	-- Se atingiu o máximo, teleporta imediatamente
	if #queue.players >= trackConfig.maxPlayers then
		RaceQueueService._launchRace(trackKey)
	end
end

--- Jogador sai da fila
function RaceQueueService.LeaveQueue(player, trackKey)
	local queue = RaceQueueService._queues[trackKey]
	if not queue then return end

	for i, p in ipairs(queue.players) do
		if p == player then
			table.remove(queue.players, i)
			print("[RaceQueue]", player.Name, "saiu da fila:", trackKey)
			break
		end
	end

	-- Notifica o jogador
	queueUpdateRemote:FireClient(player, {
		status = "left",
		trackKey = trackKey,
	})

	-- Notifica o resto da fila
	RaceQueueService._notifyQueue(trackKey)

	-- Se fila ficou vazia, limpa
	if #queue.players == 0 then
		RaceQueueService._queues[trackKey] = nil
	end
end

--- Remove jogador de todas as filas
function RaceQueueService.LeaveAllQueues(player)
	for trackKey, queue in pairs(RaceQueueService._queues) do
		for i, p in ipairs(queue.players) do
			if p == player then
				table.remove(queue.players, i)
				RaceQueueService._notifyQueue(trackKey)
				if #queue.players == 0 then
					RaceQueueService._queues[trackKey] = nil
				end
				break
			end
		end
	end
end

--- Notifica todos na fila com status atualizado
function RaceQueueService._notifyQueue(trackKey)
	local trackConfig = RaceQueueService.TRACKS[trackKey]
	local queue = RaceQueueService._queues[trackKey]
	if not queue or not trackConfig then return end

	for _, player in ipairs(queue.players) do
		if player and player.Parent then
			queueUpdateRemote:FireClient(player, {
				status = "waiting",
				trackKey = trackKey,
				displayName = trackConfig.displayName,
				playerCount = #queue.players,
				maxPlayers = trackConfig.maxPlayers,
				minPlayers = trackConfig.minPlayers,
			})
		end
	end
end

--- Teleporta todos da fila pro Place de corrida
function RaceQueueService._launchRace(trackKey)
	local trackConfig = RaceQueueService.TRACKS[trackKey]
	local queue = RaceQueueService._queues[trackKey]
	if not queue or not trackConfig then return end

	local playersToTeleport = queue.players
	RaceQueueService._queues[trackKey] = nil -- Limpa a fila

	if #playersToTeleport < 1 then return end

	print("[RaceQueue] Lançando corrida:", trackConfig.displayName, "com", #playersToTeleport, "jogadores")

	-- Notifica que vai teleportar
	for _, player in ipairs(playersToTeleport) do
		if player and player.Parent then
			queueUpdateRemote:FireClient(player, {
				status = "teleporting",
				trackKey = trackKey,
				displayName = trackConfig.displayName,
			})
		end
	end

	task.wait(1) -- Pequeno delay pra UI mostrar

	-- Monta o TeleportData
	local teleportData = {
		ExpectedPlayers = #playersToTeleport,
	}

	-- Também inclui o CharacterName de cada jogador (pra preservar o personagem)
	-- Cada jogador pode ter um personagem diferente
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ShouldReserveServer = true -- Servidor privado pra essa corrida

	-- Seta TeleportData (compartilhado entre todos)
	teleportOptions:SetTeleportData(teleportData)

	-- Teleporta o grupo junto
	local success, result = pcall(function()
		return TeleportService:TeleportAsync(
			trackConfig.placeId,
			playersToTeleport,
			teleportOptions
		)
	end)

	if not success then
		warn("[RaceQueue] Erro no teleporte:", result)
		-- Notifica os jogadores do erro
		for _, player in ipairs(playersToTeleport) do
			if player and player.Parent then
				queueUpdateRemote:FireClient(player, {
					status = "error",
					message = "Erro ao iniciar corrida. Tente novamente.",
				})
			end
		end
	else
		print("[RaceQueue] Teleporte iniciado com sucesso!")
	end
end

-- ========================================
-- LISTENERS
-- ========================================

-- Jogador quer entrar na fila
joinQueueRemote.OnServerEvent:Connect(function(player, trackKey)
	if type(trackKey) == "string" then
		RaceQueueService.JoinQueue(player, trackKey)
	end
end)

-- Jogador quer sair da fila
leaveQueueRemote.OnServerEvent:Connect(function(player, trackKey)
	if type(trackKey) == "string" then
		RaceQueueService.LeaveQueue(player, trackKey)
	else
		RaceQueueService.LeaveAllQueues(player)
	end
end)

-- Jogador saiu do jogo → remove das filas
Players.PlayerRemoving:Connect(function(player)
	RaceQueueService.LeaveAllQueues(player)
end)

-- ========================================
-- LOOP DE TIMEOUT DAS FILAS
-- ========================================
task.spawn(function()
	while true do
		task.wait(1)

		for trackKey, queue in pairs(RaceQueueService._queues) do
			local trackConfig = RaceQueueService.TRACKS[trackKey]
			if not trackConfig then continue end

			local elapsed = tick() - queue.startTime

			-- Se tem o mínimo e o timeout passou, lança mesmo sem estar cheio
			if #queue.players >= trackConfig.minPlayers and elapsed >= trackConfig.queueTimeout then
				print("[RaceQueue] Timeout da fila, lançando com", #queue.players, "jogadores")
				RaceQueueService._launchRace(trackKey)
			end
		end
	end
end)

return RaceQueueService