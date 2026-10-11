local ShopService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryModule = require(ServerScriptService:WaitForChild("Server"):WaitForChild("services"):WaitForChild("InventoryService"))


local CoinManager = require(ServerScriptService:WaitForChild("Server"):WaitForChild("controllers"):WaitForChild("CoinManager"))

-------------------------------------------------------------------------
-- CONFIGURA��ES
-------------------------------------------------------------------------

local KEYS = {
	Car = "TastyTown_Cars_v3",   
	House = "TastyTown_Houses_v3",
	Vip = "TastyTown_Vips_v3"
}

local DEFAULTS = {
	Car = {},
	House = {},
	Vip = {} -- <--- AJUSTADO: Agora come�a vazio (sem VIP inicial gratuito)
}

ShopService.Prices = {
	Car = {
		["Wafer Racer"] = 50,
		["Peppermint Blue"] = 500,
		["Sunburst"] = 15000
	},
	House = {
		["Cheese House"] = 5000,	
		["Candy Mansion"] = 25000,
		["Sushi House"] = 10000
	},
	Vip = {
		["Driver License VIP"] = 0, -- Se voc� quiser cobrar por este item agora, mude o pre�o aqui (ex: 100)
		["Gourmet Pass"] = 250,
		["Golden Spatula"] = 5000
	}
}

local VALID_CATEGORIES = { Car = true, House = true, Vip = true }

local sessionData = {}
local purchaseLocks = {}
local lastPurchaseTime = {}

-------------------------------------------------------------------------
-- SALVAMENTO ROBUSTO
-------------------------------------------------------------------------

local function mergeItemLists(oldItems, newItems)
	if not oldItems or type(oldItems) ~= "table" then
		return newItems
	end
	local set = {}
	local merged = {}
	for _, item in ipairs(oldItems) do
		if not set[item] then
			set[item] = true
			table.insert(merged, item)
		end
	end
	for _, item in ipairs(newItems) do
		if not set[item] then
			set[item] = true
			table.insert(merged, item)
		end
	end
	return merged
end

local function saveWithRetry(store, userId, dataToSave)
	local maxRetries = 3
	local attempt = 0
	local success = false
	local err

	repeat
		attempt += 1
		success, err = pcall(function()
			store:UpdateAsync(userId, function(oldData)
				return mergeItemLists(oldData, dataToSave)
			end)
		end)

		if not success then
			warn("Falha ao salvar (Tentativa " .. attempt .. "): " .. tostring(err))
			task.wait(2)
		end
	until success or attempt >= maxRetries

	return success
end

local function loadCategory(player, category, dataStoreKey)
	local store = DataStoreService:GetDataStore(dataStoreKey)
	local success, data = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)

	if success then
		return data
	else
		return nil
	end
end

local function setupPlayerData(player)
	-- Evita recarregar se j� estiver carregando
	if sessionData[player.UserId] then return end

	local tempData = {
		Car = {},
		House = {},
		Vip = {}
	}

	for category, key in pairs(KEYS) do
		local loadedItems = loadCategory(player, category, key)

		if loadedItems then
			tempData[category] = loadedItems
			print("?? " .. player.Name .. " - Carregou " .. category)
		else
			-- Se falhar ou for novo, usa padr�o vazio
			tempData[category] = table.clone(DEFAULTS[category] or {})
		end
	end

	sessionData[player.UserId] = tempData
end

local function savePlayerData(player)
	local pData = sessionData[player.UserId]
	if not pData then return end

	local remaining = 0
	local done = Instance.new("BindableEvent")

	for category, key in pairs(KEYS) do
		local itemsToSave = pData[category]
		local store = DataStoreService:GetDataStore(key)
		remaining += 1

		task.spawn(function()
			saveWithRetry(store, tostring(player.UserId), itemsToSave)
			remaining -= 1
			if remaining <= 0 then
				done:Fire()
			end
		end)
	end

	-- Wait for all saves to finish (max 10 seconds)
	if remaining > 0 then
		task.delay(10, function()
			done:Fire()
		end)
		done.Event:Wait()
	end

	done:Destroy()
end

-------------------------------------------------------------------------
-- L�GICA DE COMPRA
-------------------------------------------------------------------------

function ShopService.ProcessPurchase(player, itemName, category)
	-- Fix #1: Input validation
	if type(itemName) ~= "string" or type(category) ~= "string" then
		return "Entrada inválida"
	end
	if not VALID_CATEGORIES[category] then
		return "Categoria inválida"
	end

	-- Fix #6: Rate limiting
	local userId = player.UserId
	local now = tick()
	if lastPurchaseTime[userId] and (now - lastPurchaseTime[userId]) < 1 then
		return "Aguarde"
	end
	lastPurchaseTime[userId] = now

	-- Fix #2: Purchase lock to prevent duplicate purchases
	local lockKey = tostring(userId) .. "_" .. category .. "_" .. itemName
	if purchaseLocks[lockKey] then return "Processando" end
	purchaseLocks[lockKey] = true

	local pData = sessionData[userId]
	if not pData then
		purchaseLocks[lockKey] = nil
		return "Erro de Dados"
	end

	local categoryItems = pData[category]
	local price = ShopService.Prices[category] and ShopService.Prices[category][itemName]

	if not price then
		purchaseLocks[lockKey] = nil
		return "Item não existe"
	end

	if table.find(categoryItems, itemName) then
		purchaseLocks[lockKey] = nil
		return "Já possui"
	end

	if price > 0 then
		local success = CoinManager.removeCoins(player, price)
		if not success then
			purchaseLocks[lockKey] = nil
			return "Dinheiro insuficiente"
		end
	end

	local added = InventoryModule.AddItem(player, category, itemName)

	if added then
		-- Atualiza também o sessionData do ShopService pra manter consistência
		table.insert(categoryItems, itemName)
		print("Compra realizada: " .. itemName)
		purchaseLocks[lockKey] = nil
		return "Sucesso"
	else
		-- Se falhou no InventoryModule, devolve as moedas
		if price > 0 then
			CoinManager.addCoins(player, price)
		end
		purchaseLocks[lockKey] = nil
		return "Erro ao salvar"
	end
end

function ShopService.GetOwnedItems(player)
	local startTime = tick()

	-- Espera at� 10 segundos (antes era 3) pelos dados carregarem
	while not sessionData[player.UserId] do
		if (tick() - startTime) > 10 then
			warn("?? TIMEOUT CR�TICO: Dados de " .. player.Name .. " demoraram demais!")
			break
		end
		task.wait(0.5)
	end

	-- Se ainda n�o tiver dados (falha grave), tenta carregar na hora
	if not sessionData[player.UserId] then
		print("?? Tentando carregamento de emerg�ncia para " .. player.Name)
		setupPlayerData(player)
	end

	-- Retorna os dados ou o padr�o vazio se tudo falhar
	local finalData = sessionData[player.UserId] or DEFAULTS

	return finalData
end
-------------------------------------------------------------------------
-- INICIALIZA��O
-------------------------------------------------------------------------
 
function ShopService.Start()
	print("?? ShopService Iniciado (v3 - Sem VIP Inicial)")

	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder", ReplicatedStorage)
	remotes.Name = "Remotes"

	local buyFunc = remotes:FindFirstChild("BuyFunction") or Instance.new("RemoteFunction", remotes)
	buyFunc.Name = "BuyFunction"

	local getInvFunc = remotes:FindFirstChild("GetInventoryFunction") or Instance.new("RemoteFunction", remotes)
	getInvFunc.Name = "GetInventoryFunction"

	buyFunc.OnServerInvoke = function(player, itemName, category)
		return ShopService.ProcessPurchase(player, itemName, category)
	end

	getInvFunc.OnServerInvoke = function(player)
		return ShopService.GetOwnedItems(player)
	end

	Players.PlayerAdded:Connect(setupPlayerData)

	Players.PlayerRemoving:Connect(function(player)
		savePlayerData(player)
		sessionData[player.UserId] = nil

		local prefix = tostring(player.UserId) .. "_"
		for lockKey, _ in pairs(purchaseLocks) do
			if type(lockKey) == "string" and string.sub(lockKey, 1, #prefix) == prefix then
				purchaseLocks[lockKey] = nil
			end
		end

		lastPurchaseTime[player.UserId] = nil
	end)

	game:BindToClose(function()
		local threads = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local t = task.spawn(function()
				savePlayerData(player)
			end)
			table.insert(threads, t)
		end
		-- savePlayerData already waits up to 10s per player;
		-- BindToClose allows ~30s total
		task.wait(15)
	end)
end

return ShopService