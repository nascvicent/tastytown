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

local function loadStoreData(store, userId)
	local success, data = pcall(function()
		return store:GetAsync(tostring(userId))
	end)

	if success and data then
		return data
	end

	return {}
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

local function loadAllPlayerData(userId)
	local cars = loadStoreData(CarsStore, userId)
	local houses = loadStoreData(HousesStore, userId)
	local tags = loadStoreData(TagsStore, userId)
	local equipped = loadStoreData(EquippedStore, userId)

	if not equipped or type(equipped) ~= "table" then
		equipped = {}
	end

	if (not equipped.Car or equipped.Car == "") and #cars > 0 then
		equipped.Car = cars[#cars]
	end

	if (not equipped.House or equipped.House == "") and #houses > 0 then
		equipped.House = houses[#houses]
	end

	if (not equipped.Tag or equipped.Tag == "") and #tags > 0 then
		equipped.Tag = tags[#tags]
	end

	return {
		Cars = cars,
		Houses = houses,
		Tags = tags,
		Equipped = equipped,
	}
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
			saveEquippedData(userId, cache.Equipped)
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
			saveEquippedData(userId, cache.Equipped)
		end
	end

	InventoryUpdated:FireClient(player, {
		action = "ItemRemoved",
		category = category,
		itemName = itemName,
	})

	return true
end

-- ═══════════════════════════════════════════
-- Método de Inicialização (Start)
-- ═══════════════════════════════════════════

function InventoryModule.Start()
	-- Conectar Eventos de Player
	Players.PlayerAdded:Connect(function(player)
		local userId = player.UserId
		local data = loadAllPlayerData(userId)
		PlayerCache[userId] = data

		saveEquippedData(userId, data.Equipped)
		print("[TastyTown Inventory] Dados carregados para " .. player.Name)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		local cache = PlayerCache[userId]

		if cache then
			saveEquippedData(userId, cache.Equipped)
			PlayerCache[userId] = nil
		end
		print("[TastyTown Inventory] Dados salvos para " .. player.Name)
	end)

	-- Conectar Remotes
	GetInventoryData.OnServerInvoke = function(player)
		local userId = player.UserId
		local cache = PlayerCache[userId]

		if not cache then
			cache = loadAllPlayerData(userId)
			PlayerCache[userId] = cache
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
		saveEquippedData(userId, cache.Equipped)

		InventoryUpdated:FireClient(player, {
			category = category,
			equippedItem = itemName,
		})

		print("[TastyTown Inventory] " .. player.Name .. " equipou " .. category .. ": " .. itemName)
	end)

	print("[TastyTown Inventory] Sistema de inventário inicializado (ModuleScript)!")
end

-- Suporte opcional para a convenção com letra minúscula caso acabe chamando ".start()"
InventoryModule.start = InventoryModule.Start

return InventoryModule