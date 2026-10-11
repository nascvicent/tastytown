--[[
	Shop (cliente) — reescrito com o kit Shared/UI.

	Quem abre/fecha é o LocalScript AcionarLoja do ShopButton (HudGui): ele usa
	Lojas.ShopGui.Frame (Visible) e Frame.CloseButton. Esses nomes precisam ficar.
	Itens, preços de exibição e descrições vêm do ItemCatalog; o preço real é do ShopService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local Colors = Theme.Colors

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuyFunction = Remotes:WaitForChild("BuyFunction")
local GetInventoryFunction = Remotes:WaitForChild("GetInventoryFunction")

local gui = script.Parent

local CATEGORIES = {
	{ Id = "Car", Label = "Carros", Image = Theme.Images.Car },
	{ Id = "House", Label = "Casas", Image = Theme.Images.House },
	{ Id = "Vip", Label = "VIP", Image = Theme.Images.Vip },
}

-- Mensagens do ShopService -> texto do botão
local FEEDBACK = {
	["Dinheiro insuficiente"] = { Text = "💰 SEM GRANA", Color = Colors.Red },
	["Aguarde"] = { Text = "⏳ AGUARDE", Color = Colors.Gray },
	["Processando"] = { Text = "⏳ AGUARDE", Color = Colors.Gray },
}

-- ═══════════════════════════════════════════
-- Janela
-- ═══════════════════════════════════════════
local panel = Components.Panel({
	Parent = gui,
	Name = "Frame",
	Title = "SHOP",
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
local selectedCategory = "Car"
local owned = { Car = {}, House = {}, Vip = {} }
local tabSetters = {}

local function formatPrice(price)
	if price <= 0 then return "GRÁTIS" end
	local text = tostring(math.floor(price))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return "$" .. formatted:gsub("^%.", "")
end

local function isOwned(category, itemName)
	for _, name in ipairs(owned[category] or {}) do
		if name == itemName then return true end
	end
	return false
end

local function loadOwned()
	local ok, result = pcall(function()
		return GetInventoryFunction:InvokeServer()
	end)
	if ok and type(result) == "table" then
		owned = {
			Car = result.Car or {},
			House = result.House or {},
			Vip = result.Vip or {},
		}
		return true
	end
	warn("[Shop] Erro ao carregar inventário:", result)
	return false
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
end

local function createBuyButton(card, category, item)
	local button, setStyle = Components.ActionButton(card, { Name = "BuyButton" })

	if isOwned(category, item.Name) then
		setStyle("✓ POSSUI", Colors.Blue, false)
		return button
	end
	setStyle("COMPRAR", Colors.Green, true)

	local buying = false
	button.MouseButton1Click:Connect(function()
		if buying or isOwned(category, item.Name) then return end
		buying = true
		setStyle("⏳...", Colors.Gray, false)

		local ok, result = pcall(function()
			return BuyFunction:InvokeServer(item.Name, category)
		end)

		if ok and (result == "Sucesso" or result == "Já possui") then
			table.insert(owned[category], item.Name)
			setStyle(result == "Sucesso" and "✓ COMPRADO!" or "✓ POSSUI", Colors.Blue, false)
			return
		end

		local feedback = (ok and FEEDBACK[result]) or { Text = ok and "❌ ERRO" or "🔌 ERRO", Color = Colors.Red }
		setStyle(feedback.Text, feedback.Color, false)
		task.wait(1.5)
		if button.Parent then
			setStyle("COMPRAR", Colors.Green, true)
		end
		buying = false
	end)

	return button
end

local function createItemCard(category, item, order)
	local card, color = Components.ItemCard(grid, {
		Name = item.Name,
		Title = item.Name,
		Subtitle = formatPrice(item.Price or 0),
		Rarity = item.Rarity,
		LayoutOrder = order,
	})

	Components.InfoButton(card, color).MouseButton1Click:Connect(function()
		Components.InfoPopup(mainFrame, {
			Title = item.Name,
			Description = item.Description,
			Color = color,
		})
	end)

	local preview = Components.CardPreview(card, true)
	if item.Image then
		Components.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			BackgroundTransparency = 1,
			Image = item.Image,
			ImageColor3 = item.Color or Colors.White,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
			Parent = preview,
		})
	else
		local model = ItemCatalog.FindModel(category, item)
		if model then
			Components.Viewport(preview, model, item.Camera, isOpen)
		else
			warn("[Shop] Modelo de vitrine não encontrado:", category, item.ModelName)
		end
	end

	local button = createBuyButton(card, category, item)
	if category == "Vip" then
		Components.Shine(button)
	end
end

local function refreshContent()
	clearGrid()
	grid.CanvasPosition = Vector2.zero

	for index, item in ipairs(ItemCatalog.Items[selectedCategory] or {}) do
		if not item.ShopHidden then
			createItemCard(selectedCategory, item, index)
		end
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
-- Abertura: animação + atualizar o que o jogador já possui
-- ═══════════════════════════════════════════
local openScale = Components.new("UIScale", { Parent = mainFrame })

mainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if not mainFrame.Visible then return end
	openScale.Scale = 0.9
	TweenService:Create(openScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	if loadOwned() then
		refreshContent()
	end
end)

loadOwned()
selectCategory(selectedCategory)
