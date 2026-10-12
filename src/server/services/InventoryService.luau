--[[
    ╔══════════════════════════════════════════════════════════╗
    ║         TastyTown Inventory System - Server              ║
    ║         Handles DataStores & Equipped Items              ║
    ╚══════════════════════════════════════════════════════════╝
    
    DataStores usados:
    - TastyTown_Cars_v3       → Lista de carros que o player possui
    - TastyTown_Houses_v3     → Lista de casas que o player possui
    - TastyTown_Tags_v3       → Lista de tags que o player possui (placeholder)
    - TastyTown_Equipped_v1   → Itens equipados por categoria { Car = "...", House = "...", Tag = "..." }
]]

local InventoryModule = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ═══════════════════════════════════════════
-- DataStores
-- ═══════════════════════════════════════════
local CarsStore = DataStoreService:GetDataStore("TastyTown_Cars_v3")
local HousesStore = DataStoreService:GetDataStore("TastyTown_Houses_v3")
local TagsStore = DataStoreService:GetDataStore("TastyTown_Tags_v3")
local EquippedStore = DataStoreService:GetDataStore("TastyTown_Equipped_v1")

-- ═══════════════════════════════════════════
-- Instâncias de Remotes (Criadas ao fazer o require)
-- ═══════════════════════════════════════════
local InventoryFolder = Instance.new("Folder")
InventoryFolder.Name = "InventoryRemotes"
InventoryFolder.Parent = ReplicatedStorage

local GetInventoryData = Instance.new("RemoteFunction")
GetInventoryData.Name = "GetInventoryData"
GetInventoryData.Parent = InventoryFolder

local EquipItem = Instance.new("RemoteEvent")
EquipItem.Name = "EquipItem"
EquipItem.Parent = InventoryFolder

local InventoryUpdated = Instance.new("RemoteEvent")
InventoryUpdated.Name = "InventoryUpdated"
InventoryUpdated.Parent = InventoryFolder

-- Casa que todo jogador possui (não é gravada no DataStore; é adicionada ao carregar)
local ItemCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local STARTER_HOUSE = ItemCatalog.StarterHouse

-- Servidor: avisa quando um item é equipado -> (player, category, itemName)
local EquippedChanged = Instance.new("BindableEvent")
InventoryModule.EquippedChanged = EquippedChanged.Event

-- ═══════════════════════════════════════════
-- Cache local & Variáveis
-- ═══════════════════════════════════════════
local PlayerCache = {} -- [userId] = { Cars = {}, Houses = {}, Tags = {}, Equipped = {} }

local CATEGORIES = {
	Car = CarsStore,
	House = HousesStore,
	Tag = TagsStore,
}

local CATEGORY_ORDER = { "Car", "House", "Tag" }

-- ═══════════════════════════════════════════
-- Funções Auxiliares (Privadas)
-- ═══════════════════════════════════════════

-- Lê uma chave com algumas tentativas. Devolve (dados, ok): ok = false quando o DataStore
-- falhou (diferente de "jogador sem dados", que é ok = true com tabela vazia).
local LOAD_ATTEMPTS = 3

local function loadStoreData(store, userId)
	for attempt = 1, LOAD_ATTEMPTS do
		local success, data = pcall(function()
			return store:GetAsync(tostring(userId))
		end)

		if success then
			return (type(data) == "table" and data) or {}, true
		end

		warn("[TastyTown Inventory] Falha ao ler " .. store.Name .. " (tentativa " .. attempt .. "): " .. tostring(data))
		if attempt < LOAD_ATTEMPTS then task.wait(attempt) end
	end

	return {}, false
end

local function saveEquippedData(userId, equippedData)
	local success, err = pcall(function()
		EquippedStore:SetAsync(tostring(userId), equippedData)
	end)

	if not success then
		warn("[TastyTown Inventory] Erro ao salvar equipped data para userId " .. tostring(userId) .. ": " .. tostring(err))
	end

	return success
end

-- Só grava o equipado quando ele veio do DataStore (ou o jogador escolheu algo na sessão).
-- Com a leitura falhada, o cache tem só o padrão e gravar apagaria a escolha salva.
-- Sem a leitura, grava só as categorias escolhidas, por cima do que já está salvo.
local function saveEquippedIfTrusted(userId, cache)
	if cache.EquippedLoaded then
		return saveEquippedData(userId, cache.Equipped)
	end
	if not next(cache.EquippedChosen) then return false end

	local success, err = pcall(function()
		EquippedStore:UpdateAsync(tostring(userId), function(saved)
			saved = type(saved) == "table" and saved or {}
			for category in pairs(cache.EquippedChosen) do
				saved[category] = cache.Equipped[category]
			end
			return saved
		end)
	end)
	if not success then
		warn("[TastyTown Inventory] Erro ao salvar equipped data para userId " .. tostring(userId) .. ": " .. tostring(err))
	end
	return success
end

-- Completa os equipados vazios com o último item de cada lista
local function fillEquippedDefaults(data)
	local equipped = data.Equipped
	for _, category in ipairs(CATEGORY_ORDER) do
		local list = data[category .. "s"]
		if (not equipped[category] or equipped[category] == "") and #list > 0 then
			equipped[category] = list[#list]
		end
	end
end

local function loadAllPlayerData(userId)
	local cars, carsOk = loadStoreData(CarsStore, userId)
	local houses, housesOk = loadStoreData(HousesStore, userId)
	local tags, tagsOk = loadStoreData(TagsStore, userId)
	local equipped, equippedOk = loadStoreData(EquippedStore, userId)

	if STARTER_HOUSE and not table.find(houses, STARTER_HOUSE) then
		table.insert(houses, 1, STARTER_HOUSE)
	end

	local data = {
		Cars = cars,
		Houses = houses,
		Tags = tags,
		Equipped = equipped,
		EquippedLoaded = equippedOk,
		EquippedChosen = {}, -- [category] = true quando o jogador equipou algo nesta sessão
		Failed = { -- leituras que falharam, refeitas em segundo plano
			Car = not carsOk or nil,
			House = not housesOk or nil,
			Tag = not tagsOk or nil,
			Equipped = not equippedOk or nil,
		},
	}
	fillEquippedDefaults(data)
	return data
end

local function playerOwnsItem(userId, category, itemName)
	local cache = PlayerCache[userId]
	if not cache then return false end

	local listKey = category .. "s"
	local itemList = cache[listKey]

	if not itemList then return false end

	for _, item in ipairs(itemList) do
		if item == itemName then
			return true
		end
	end

	return false
end

-- ═══════════════════════════════════════════
-- Métodos Públicos do Módulo
-- ═══════════════════════════════════════════

function InventoryModule.AddItem(player, category, itemName)
	local userId = player.UserId
	local store = CATEGORIES[category]

	if not store then
		warn("[TastyTown Inventory] Categoria inválida: " .. tostring(category))
		return false
	end

	local success, err = pcall(function()
		store:UpdateAsync(tostring(userId), function(currentData)
			currentData = currentData or {}

			for _, item in ipairs(currentData) do
				if item == itemName then
					return currentData
				end
			end

			table.insert(currentData, itemName)
			return currentData
		end)
	end)

	if not success then
		warn("[TastyTown Inventory] Erro ao adicionar item: " .. tostring(err))
		return false
	end

	local cache = PlayerCache[userId]
	if cache then
		local listKey = category .. "s"
		if not cache[listKey] then
			cache[listKey] = {}
		end
		table.insert(cache[listKey], itemName)

		if #cache[listKey] == 1 then
			cache.Equipped[category] = itemName
			cache.EquippedChosen[category] = true
			saveEquippedIfTrusted(userId, cache)
		end
	end

	InventoryUpdated:FireClient(player, {
		action = "ItemAdded",
		category = category,
		itemName = itemName,
	})

	return true
end

function InventoryModule.RemoveItem(player, category, itemName)
	local userId = player.UserId
	local store = CATEGORIES[category]

	if not store then return false end

	local success, err = pcall(function()
		store:UpdateAsync(tostring(userId), function(currentData)
			currentData = currentData or {}

			for i, item in ipairs(currentData) do
				if item == itemName then
					table.remove(currentData, i)
					break
				end
			end

			return currentData
		end)
	end)

	if not success then
		warn("[TastyTown Inventory] Erro ao remover item: " .. tostring(err))
		return false
	end

	local cache = PlayerCache[userId]
	if cache then
		local listKey = category .. "s"
		for i, item in ipairs(cache[listKey] or {}) do
			if item == itemName then
				table.remove(cache[listKey], i)
				break
			end
		end

		if cache.Equipped[category] == itemName then
			local remaining = cache[listKey] or {}
			cache.Equipped[category] = #remaining > 0 and remaining[#remaining] or ""
			cache.EquippedChosen[category] = true
			saveEquippedIfTrusted(userId, cache)
		end
	end

	InventoryUpdated:FireClient(player, {
		action = "ItemRemoved",
		category = category,
		itemName = itemName,
	})

	return true
end

-- Item equipado na categoria (nil se os dados ainda não carregaram)
function InventoryModule.GetEquipped(player, category)
	local cache = PlayerCache[player.UserId]
	return cache and cache.Equipped[category] or nil
end

-- Espera os dados do jogador carregarem (até timeout segundos)
function InventoryModule.WaitForData(player, timeout)
	local start = os.clock()
	while not PlayerCache[player.UserId] and player.Parent and os.clock() - start < (timeout or 15) do
		task.wait(0.2)
	end
	return PlayerCache[player.UserId] ~= nil
end

-- Leituras que falharam na entrada: tenta de novo em segundo plano. O que chegar entra
-- no cache sem desfazer o que o jogador já equipou nesta sessão.
local RETRY_INTERVAL = 6
local RETRY_ROUNDS = 10

local function retryFailedLoads(player)
	local userId = player.UserId
	for _ = 1, RETRY_ROUNDS do
		task.wait(RETRY_INTERVAL)
		local cache = PlayerCache[userId]
		if not cache or not player.Parent or not next(cache.Failed) then return end

		for category, store in pairs(CATEGORIES) do
			if cache.Failed[category] then
				local list, ok = loadStoreData(store, userId)
				if ok then
					cache.Failed[category] = nil
					local listKey = category .. "s"
					if category == "House" and STARTER_HOUSE and not table.find(list, STARTER_HOUSE) then
						table.insert(list, 1, STARTER_HOUSE)
					end
					for _, item in ipairs(cache[listKey] or {}) do
						if not table.find(list, item) then table.insert(list, item) end
					end
					cache[listKey] = list
				end
			end
		end

		local changed = {}
		if cache.Failed.Equipped then
			local saved, ok = loadStoreData(EquippedStore, userId)
			if ok then
				cache.Failed.Equipped = nil
				cache.EquippedLoaded = true
				for _, category in ipairs(CATEGORY_ORDER) do
					local item = saved[category]
					if not cache.EquippedChosen[category] and type(item) == "string" and item ~= ""
						and item ~= cache.Equipped[category] then
						cache.Equipped[category] = item
						changed[category] = item
					end
				end
			end
		end
		fillEquippedDefaults(cache)

		if PlayerCache[userId] ~= cache or not player.Parent then return end
		InventoryUpdated:FireClient(player, { action = "Reloaded" })
		for category, item in pairs(changed) do
			EquippedChanged:Fire(player, category, item)
		end
		if not next(cache.Failed) then
			print("[TastyTown Inventory] Dados recuperados para " .. player.Name)
			return
		end
	end
	warn("[TastyTown Inventory] Não foi possível carregar todos os dados de " .. player.Name)
end

-- ═══════════════════════════════════════════
-- Método de Inicialização (Start)
-- ═══════════════════════════════════════════

function InventoryModule.Start()
	-- Conectar Eventos de Player
	local function onPlayerAdded(player)
		local userId = player.UserId
		if PlayerCache[userId] then return end
		local data = loadAllPlayerData(userId)
		if PlayerCache[userId] then return end -- o GetInventoryData pode ter carregado antes
		PlayerCache[userId] = data

		if next(data.Failed) then
			warn("[TastyTown Inventory] Dados de " .. player.Name .. " carregados com falhas; tentando de novo em segundo plano")
			task.spawn(retryFailedLoads, player)
		else
			saveEquippedData(userId, data.Equipped)
		end
		print("[TastyTown Inventory] Dados carregados para " .. player.Name)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Jogadores que entraram antes do PlayerAdded ser conectado (comum no Play do Studio)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		local cache = PlayerCache[userId]

		if cache then
			saveEquippedIfTrusted(userId, cache)
			PlayerCache[userId] = nil
		end
		print("[TastyTown Inventory] Dados salvos para " .. player.Name)
	end)

	-- Servidor fechando (inclui o Stop do Studio): o PlayerRemoving pode não dar tempo
	game:BindToClose(function()
		local pending = 0
		for userId, cache in pairs(PlayerCache) do
			pending += 1
			task.spawn(function()
				saveEquippedIfTrusted(userId, cache)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)

	-- Conectar Remotes
	GetInventoryData.OnServerInvoke = function(player)
		local userId = player.UserId
		local cache = PlayerCache[userId]

		-- O carregamento da entrada já está em andamento: espera ele em vez de ler de novo
		if not cache and InventoryModule.WaitForData(player, 20) then
			cache = PlayerCache[userId]
		end
		if not cache then
			cache = loadAllPlayerData(userId)
			if PlayerCache[userId] then
				cache = PlayerCache[userId]
			else
				PlayerCache[userId] = cache
				if next(cache.Failed) then task.spawn(retryFailedLoads, player) end
			end
		end

		return {
			categories = {
				{
					id = "Car",
					name = "Carros",
					icon = "rbxassetid://CAR_ICON_ID",
					items = cache.Cars or {},
					equipped = cache.Equipped.Car or "",
				},
				{
					id = "House",
					name = "Casas",
					icon = "rbxassetid://HOUSE_ICON_ID",
					items = cache.Houses or {},
					equipped = cache.Equipped.House or "",
				},
				{
					id = "Tag",
					name = "Tags",
					icon = "rbxassetid://TAG_ICON_ID",
					items = cache.Tags or {},
					equipped = cache.Equipped.Tag or "",
				},
			}
		}
	end

	EquipItem.OnServerEvent:Connect(function(player, category, itemName)
		local userId = player.UserId

		if type(category) ~= "string" or type(itemName) ~= "string" then
			warn("[TastyTown Inventory] Dados inválidos recebidos de " .. player.Name)
			return
		end

		if not CATEGORIES[category] then
			warn("[TastyTown Inventory] Categoria inválida: " .. category)
			return
		end

		if not playerOwnsItem(userId, category, itemName) then
			warn("[TastyTown Inventory] " .. player.Name .. " tentou equipar item que não possui: " .. itemName)
			return
		end

		local cache = PlayerCache[userId]
		if not cache then return end

		cache.Equipped[category] = itemName
		cache.EquippedChosen[category] = true
		saveEquippedIfTrusted(userId, cache)

		InventoryUpdated:FireClient(player, {
			category = category,
			equippedItem = itemName,
		})
		EquippedChanged:Fire(player, category, itemName)

		print("[TastyTown Inventory] " .. player.Name .. " equipou " .. category .. ": " .. itemName)
	end)

	print("[TastyTown Inventory] Sistema de inventário inicializado (ModuleScript)!")
end

-- Suporte opcional para a convenção com letra minúscula caso acabe chamando ".start()"
InventoryModule.start = InventoryModule.Start

return InventoryModule