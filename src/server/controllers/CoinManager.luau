--[[
	ModuleScript: CoinManager (Refatorado e Seguro)
--]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local CoinManager = {}

-- CONFIGURAÇÕES
local coinDataStore = DataStoreService:GetDataStore("PlayerCoins_V3")
local sessionData = {} -- Cache (Fonte da verdade)

local AUTOSAVE_INTERVAL = 60
local MAX_RETRIES = 3

--============================================================================--
--                              FUNÇÕES INTERNAS                              --
--============================================================================--

-- Usa UpdateAsync para garantir integridade se houver conflito de servidores
local function saveData(userId, currentValue)
	local success, err = pcall(function()
		coinDataStore:UpdateAsync(userId, function(oldValue)
			-- Lógica de verificação (opcional):
			-- Se oldValue for muito maior que currentValue, algo estranho aconteceu.
			-- Por enquanto, apenas retornamos o valor novo.
			return currentValue
		end)
	end)

	if success then
		print(`[CoinManager] Salvo: {userId} -> {currentValue}`)
	else
		warn(`[CoinManager] Erro ao salvar {userId}: {err}`)
	end
	return success
end

local function onPlayerAdded(player)
	local userId = player.UserId

	-- Leaderstats (apenas visual)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Donuts"
	coins.Parent = leaderstats

	-- Tenta carregar com retries
	local data = nil
	local success = false
	local err = nil

	for i = 1, MAX_RETRIES do
		success, err = pcall(function()
			data = coinDataStore:GetAsync(userId)
		end)
		if success then break end
		task.wait(2)
	end

	if success then
		if data then
			sessionData[userId] = data
			coins.Value = data
			print(`[CoinManager] Carregado para {player.Name}: {data}`)
		else
			-- Retornou nil = Jogador realmente novo
			sessionData[userId] = 0
			coins.Value = 0
			print(`[CoinManager] Novo jogador: {player.Name}`)
		end

		-- Só inicia o loop de autosave se os dados carregaram corretamente!
		task.spawn(function()
			while player.Parent and sessionData[userId] do
				task.wait(AUTOSAVE_INTERVAL)
				saveData(userId, sessionData[userId])
			end
		end)

	else
		-- === PROTEÇÃO CONTRA PERDA DE DADOS ===
		-- Se falhou todas as tentativas, kicka o jogador.
		-- Nunca inicie com 0 se o erro for de conexão.
		warn(`[CoinManager] CRÍTICO: Falha ao carregar dados de {player.Name}: {err}`)
		player:Kick("Houve uma falha ao carregar seus dados. Por favor, reconecte para evitar perda de progresso.")
	end
end

local function onPlayerRemoving(player)
	local userId = player.UserId
	if sessionData[userId] then
		saveData(userId, sessionData[userId])
		sessionData[userId] = nil -- Limpa cache
	end
end

--============================================================================--
--                              FUNÇÕES PÚBLICAS                              --
--============================================================================--

function CoinManager.addCoins(player, amount)
	if not player or not sessionData[player.UserId] then return end

	sessionData[player.UserId] += amount

	-- Atualiza visual
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Donuts") then
		leaderstats.Coins.Value = sessionData[player.UserId]
	end
end

function CoinManager.removeCoins(player, amount)
	if not player or not sessionData[player.UserId] then return false end

	if sessionData[player.UserId] >= amount then
		sessionData[player.UserId] -= amount

		-- Atualiza visual
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats and leaderstats:FindFirstChild("Donuts") then
			leaderstats.Donuts.Value = sessionData[player.UserId]
		end
		return true
	end
	return false
end

function CoinManager.getCoins(player)
	return sessionData[player.UserId] or 0
end

function CoinManager.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end

	game:BindToClose(function()
		if RunService:IsStudio() then task.wait(1) return end

		-- Salva dados usando task.spawn para ser mais rápido
		-- BindToClose tem limite de 30s. Serializar (um por um) pode estourar o tempo.
		local thread = coroutine.running()
		local pending = 0

		for userId, data in pairs(sessionData) do
			pending += 1
			task.spawn(function()
				saveData(userId, data)
				pending -= 1
				if pending == 0 then
					coroutine.resume(thread)
				end
			end)
		end

		if pending > 0 then
			coroutine.yield() -- Espera todos salvarem
		end
	end)
end

return CoinManager