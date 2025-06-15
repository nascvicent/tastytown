--[[
	ModuleScript: CoinManager
	Responsável por gerenciar os dados das moedas dos jogadores de forma segura e robusta.
	Inclui:
	- Carregamento e salvamento com sistema de retentativas (retry).
	- Salvamento automático (autosave) para prevenir perda de dados.
	- Salvamento final ao desligar o servidor (BindToClose).
	- Cache de dados no servidor para performance e segurança.
--]]

-- Serviços
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- Módulo
local CoinManager = {}

--============================================================================--
--                          CONFIGURAÇÕES                                    --
--============================================================================--

-- Usar um nome único evita conflitos com outros DataStores.
local coinDataStore = DataStoreService:GetDataStore("PlayerCoins_V3")

-- Cache para guardar os dados dos jogadores enquanto estão na sessão.
-- A "fonte da verdade" não será o IntValue, mas sim os dados neste cache.
local sessionData = {}

-- Configurações de segurança
local AUTOSAVE_INTERVAL = 60 -- Salva a cada 60 segundos.
local MAX_RETRIES = 3 -- Tenta salvar até 3 vezes em caso de erro.
local RETRY_DELAY = 2 -- Espera 2 segundos entre as tentativas.


--============================================================================--
--                          FUNÇÕES INTERNAS (PRIVADAS)                      --
--============================================================================--

-- Função para salvar dados com sistema de retentativas.
local function saveData(userId, data)
	for i = 1, MAX_RETRIES do
		local success, err = pcall(function()
			coinDataStore:SetAsync(userId, data)
		end)

		if success then
			print(`[DataStore] Dados salvos para userId {userId} na tentativa {i}.`)
			return true
		else
			warn(`[DataStore] Falha ao salvar para userId {userId} (tentativa {i}/{MAX_RETRIES}): {err}`)
			if i < MAX_RETRIES then
				task.wait(RETRY_DELAY)
			end
		end
	end
	
	warn(`[DataStore] ATENÇÃO: Todas as {MAX_RETRIES} tentativas de salvar para {userId} falharam.`)
	return false
end


-- Função executada quando um jogador entra no jogo.
local function onPlayerAdded(player)
	local userId = player.UserId
	
	-- Cria a estrutura de leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0 -- Começa em 0 enquanto carrega
	coins.Parent = leaderstats

	-- Carrega os dados do DataStore
	local data
	local success, err = pcall(function()
		data = coinDataStore:GetAsync(userId)
	end)

	if success then
		if data and type(data) == "number" then
			-- Dados carregados com sucesso, atualiza o cache e o leaderstats
			sessionData[userId] = data
			coins.Value = data
			print(`Moedas de {player.Name} carregadas: {data}`)
		else
			-- Novo jogador ou dados corrompidos
			sessionData[userId] = 0
			print(`Novo jogador {player.Name}, iniciando com 0 moedas.`)
		end
	else
		-- Falha na API, inicia com 0 como segurança
		sessionData[userId] = 0
		warn(`Erro ao carregar dados para {player.Name}: {err}. Iniciando com 0.`)
	end
	
	-- Inicia o salvamento automático (autosave) para este jogador
	coroutine.wrap(function()
		while player.Parent do -- Enquanto o jogador estiver no jogo
			task.wait(AUTOSAVE_INTERVAL)
			-- Salva apenas se os dados estiverem no cache (jogador ainda ativo)
			if sessionData[userId] then
				saveData(userId, sessionData[userId])
			end
		end
	end)()
end

-- Função para salvar os dados quando um jogador sai.
local function onPlayerRemoving(player)
	local userId = player.UserId

	-- Se o jogador tiver dados na sessão, salva-os uma última vez.
	if sessionData[userId] then
		saveData(userId, sessionData[userId])
		-- Limpa os dados do cache para liberar memória.
		sessionData[userId] = nil
	end
end

--============================================================================--
--                         FUNÇÕES PÚBLICAS                                --
--============================================================================--

-- Adiciona moedas. Agora, modifica o cache primeiro.
function CoinManager.addCoins(player, amount)
	if not (player and amount and type(amount) == "number" and amount > 0) then
		return false, "Argumentos inválidos."
	end

	local userId = player.UserId
	if sessionData[userId] then
		sessionData[userId] = sessionData[userId] + amount
		player.leaderstats.Coins.Value = sessionData[userId] -- Atualiza o visual
		return true
	end
	return false, "Jogador não encontrado na sessão."
end

-- Remove moedas. É bom ter uma função separada para validação.
function CoinManager.removeCoins(player, amount)
	if not (player and amount and type(amount) == "number" and amount > 0) then
		return false, "Argumentos inválidos."
	end
	
	local userId = player.UserId
	if sessionData[userId] then
		if sessionData[userId] >= amount then
			sessionData[userId] = sessionData[userId] - amount
			player.leaderstats.Coins.Value = sessionData[userId] -- Atualiza o visual
			return true
		else
			return false, "Moedas insuficientes."
		end
	end
	return false, "Jogador não encontrado na sessão."
end

-- Obtém o valor real de moedas do cache.
function CoinManager.getCoins(player)
	if player then
		return sessionData[player.UserId]
	end
	return nil
end


-- Função para iniciar o sistema
function CoinManager.start()
	-- Conecta as funções aos eventos dos jogadores
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Para jogadores que já podem estar no servidor quando o script rodar
	for _, player in ipairs(Players:GetPlayers()) do
		coroutine.wrap(onPlayerAdded)(player)
	end
	
	-- Salva os dados de todos antes do servidor desligar
	game:BindToClose(function()
		if RunService:IsStudio() then
			-- BindToClose pode ser instável no Studio. O autosave é nossa principal defesa aqui.
			task.wait(2)
			return
		end
		
		print("[BindToClose] Servidor desligando. Salvando dados de todos os jogadores...")
		for userId, data in pairs(sessionData) do
			saveData(userId, data)
		end
	end)
	
	print("Módulo CoinManager (Versão Segura) iniciado.")
end

return CoinManager