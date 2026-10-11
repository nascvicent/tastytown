--[[
	Inventário (cliente) — monta a janela no mesmo estilo do Shop.

	Quem abre/fecha é o LocalScript do BackpackButton (HudGui): ele liga
	InventoryGui.Enabled, MainFrame.Visible e escuta MainFrame.CloseButton.
	Por isso os nomes "MainFrame" e "CloseButton" precisam ser mantidos.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local Colors = Theme.Colors

local gui = script.Parent

-- ═══════════════════════════════════════════
-- Remotes (criados pelo InventoryService no servidor)
-- ═══════════════════════════════════════════
local remotes = ReplicatedStorage:WaitForChild("InventoryRemotes", 30)
if not remotes then
	warn("[Inventory] InventoryRemotes não encontrado; o InventoryService está rodando?")
	return
end
local GetInventoryData = remotes:WaitForChild("GetInventoryData")
local EquipItem = remotes:WaitForChild("EquipItem")
local InventoryUpdated = remotes:WaitForChild("InventoryUpdated")

-- ═══════════════════════════════════════════
-- Janela
-- ═══════════════════════════════════════════
local CATEGORIES = {
	{ Id = "Car", Label = "Carros", Image = Theme.Images.Car, Empty = "Nenhum carro ainda!" },
	{ Id = "House", Label = "Casas", Image = Theme.Images.House, Empty = "Nenhuma casa ainda!" },
	{ Id = "Tag", Label = "Tags", Image = Theme.Images.Tag, Empty = "Nenhuma tag ainda!" },
}

local panel = Components.Panel({
	Parent = gui,
	Name = "MainFrame",
	Title = "INVENTÁRIO",
	HasTabs = true,
})
local mainFrame = panel.Frame
local grid = Components.Grid(panel.Page)

local function isOpen()
	return gui.Enabled and mainFrame.Visible
end

-- ═══════════════════════════════════════════
-- Estado
-- ═══════════════════════════════════════════
local inventoryData = nil
local selectedCategory = "Car"
local pendingEquip = nil -- { category, item } enquanto o servidor não confirma
local stale = true

local tabSetters = {}

-- ═══════════════════════════════════════════
-- Preview dos itens
-- ═══════════════════════════════════════════

-- Usa os mesmos modelos do Shop (câmeras ajustadas para eles); carros também existem em ReplicatedStorage.Cars
local function findModel(category, modelName)
	if not modelName then return nil end

	local lojas = playerGui:FindFirstChild("Lojas")
	local shopGui = lojas and lojas:FindFirstChild("ShopGui")
	local shopFrame = shopGui and shopGui:FindFirstChild("Frame")
	local folder = shopFrame and shopFrame:FindFirstChild(category == "Car" and "ModelosCarros" or "ModelosCasas")
	local model = folder and folder:FindFirstChild(modelName)
	if model then return model end

	if category == "Car" then
		local cars = ReplicatedStorage:FindFirstChild("Cars")
		return cars and cars:FindFirstChild(modelName)
	end
	return nil
end

local function createTagPreview(parent, tagText)
	local plate = Components.new("Frame", {
		Name = "TagPlate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.62),
		BackgroundColor3 = Colors.Header,
		BackgroundTransparency = 0.55,
		ZIndex = 2,
		Parent = parent,
	}, {
		Components.corner(10),
	})

	-- Imita a plaquinha que aparece sobre a cabeça (NameTagService)
	local nameLabel = Components.label({
		Position = UDim2.fromScale(0.05, 0.08),
		Size = UDim2.fromScale(0.9, 0.42),
		Text = player.DisplayName,
		ZIndex = 3,
		Parent = plate,
	})
	Components.stroke(Color3.fromRGB(80, 50, 20), 2, Enum.ApplyStrokeMode.Contextual).Parent = nameLabel

	local tagLabel = Components.label({
		Position = UDim2.fromScale(0.05, 0.52),
		Size = UDim2.fromScale(0.9, 0.38),
		Text = tagText,
		TextColor3 = Color3.fromRGB(255, 223, 150),
		ZIndex = 3,
		Parent = plate,
	})
	Components.stroke(Color3.fromRGB(80, 50, 20), 2, Enum.ApplyStrokeMode.Contextual).Parent = tagLabel
end

local function createIconPreview(parent, category)
	for _, cat in ipairs(CATEGORIES) do
		if cat.Id == category then
			Components.new("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.7, 0.7),
				BackgroundTransparency = 1,
				Image = cat.Image,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
				Parent = parent,
			})
		end
	end
end

-- ═══════════════════════════════════════════
-- Cards
-- ═══════════════════════════════════════════
local function clearGrid()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	-- O estado vazio fica na página (dentro da grade ele viraria uma célula do UIGridLayout)
	local empty = panel.Page:FindFirstChild("EmptyState")
	if empty then empty:Destroy() end
end

local function createItemCard(category, itemName, isEquipped, order)
	local info = ItemCatalog.Get(category, itemName)
	local card, _, stroke = Components.ItemCard(grid, {
		Name = itemName,
		Title = itemName,
		Rarity = info.Rarity,
		LayoutOrder = order,
	})
	if isEquipped then
		stroke.Thickness = 4
	end

	local preview = Components.CardPreview(card)
	if category == "Tag" then
		createTagPreview(preview, itemName)
	else
		local model = findModel(category, info.ModelName or itemName)
		if model and model:IsA("Model") then
			Components.Viewport(preview, model, info.Camera, isOpen)
		else
			createIconPreview(preview, category)
		end
	end

	local isPending = pendingEquip and pendingEquip.category == category and pendingEquip.item == itemName
	local button, setStyle = Components.ActionButton(card, { Name = "EquipButton" })
	if isEquipped then
		setStyle("✓ EQUIPADO", Colors.Blue, false)
	elseif isPending then
		setStyle("...", Colors.Gray, false)
	else
		setStyle("EQUIPAR", Colors.Green, true)
	end

	button.MouseButton1Click:Connect(function()
		if isEquipped or pendingEquip then return end
		pendingEquip = { category = category, item = itemName }
		setStyle("...", Colors.Gray, false)
		EquipItem:FireServer(category, itemName)

		-- Se o servidor não responder, libera o botão de novo
		task.delay(5, function()
			if pendingEquip and pendingEquip.item == itemName then
				pendingEquip = nil
				if button.Parent then setStyle("EQUIPAR", Colors.Green, true) end
			end
		end)
	end)
end

local function getCategoryData(categoryId)
	if not inventoryData or not inventoryData.categories then return nil end
	for _, cat in ipairs(inventoryData.categories) do
		if cat.id == categoryId then
			return cat
		end
	end
	return nil
end

local function refreshContent()
	clearGrid()
	grid.CanvasPosition = Vector2.zero

	if not inventoryData then
		Components.EmptyState(panel.Page, "Carregando...", "")
		return
	end

	local categoryData = getCategoryData(selectedCategory)
	local items = categoryData and categoryData.items or {}

	if #items == 0 then
		local emptyText = "Nada aqui ainda!"
		for _, cat in ipairs(CATEGORIES) do
			if cat.Id == selectedCategory then emptyText = cat.Empty end
		end
		Components.EmptyState(panel.Page, emptyText, "Visite o Shop para conseguir novos itens.")
		return
	end

	-- Equipado primeiro, depois da raridade mais alta para a mais baixa
	local sorted = table.clone(items)
	table.sort(sorted, function(a, b)
		local aEquipped = a == categoryData.equipped
		local bEquipped = b == categoryData.equipped
		if aEquipped ~= bEquipped then return aEquipped end
		local ra = Theme.GetRarity(ItemCatalog.Get(selectedCategory, a).Rarity).Order
		local rb = Theme.GetRarity(ItemCatalog.Get(selectedCategory, b).Rarity).Order
		if ra ~= rb then return ra > rb end
		return a < b
	end)

	for index, itemName in ipairs(sorted) do
		createItemCard(selectedCategory, itemName, itemName == categoryData.equipped, index)
	end
end

local function selectCategory(categoryId)
	selectedCategory = categoryId
	for id, setSelected in pairs(tabSetters) do
		setSelected(id == categoryId)
	end
	refreshContent()
end

for index, cat in ipairs(CATEGORIES) do
	local tile, setSelected = Components.TabTile(panel.Tabs, {
		Name = cat.Id .. "Tab",
		Label = cat.Label,
		Image = cat.Image,
		LayoutOrder = index,
	})
	tabSetters[cat.Id] = setSelected
	tile.MouseButton1Click:Connect(function()
		if selectedCategory ~= cat.Id then
			selectCategory(cat.Id)
		end
	end)
end

-- ═══════════════════════════════════════════
-- Dados
-- ═══════════════════════════════════════════
local loading = false

local function loadInventory()
	if loading then return end
	loading = true

	local ok, data = pcall(function()
		return GetInventoryData:InvokeServer()
	end)
	loading = false

	if ok and type(data) == "table" then
		inventoryData = data
		stale = false
		pendingEquip = nil
		selectCategory(selectedCategory)
	else
		warn("[Inventory] Erro ao carregar inventário:", data)
	end
end

InventoryUpdated.OnClientEvent:Connect(function()
	if isOpen() then
		loadInventory()
	else
		stale = true
	end
end)

-- ═══════════════════════════════════════════
-- Abertura (animação + recarregar se necessário)
-- ═══════════════════════════════════════════
local openScale = Components.new("UIScale", { Parent = mainFrame })

mainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if not mainFrame.Visible then return end
	openScale.Scale = 0.9
	TweenService:Create(openScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	if stale or not inventoryData then
		loadInventory()
	end
end)

selectCategory(selectedCategory)
