local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 1. Remove a tela de loading padrão
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- 2. Cria a GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CustomLoadingScreen"
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(255, 223, 240)
background.Parent = screenGui

local logo = Instance.new("TextLabel")
logo.Text = "Entering the tasty city..."
logo.Size = UDim2.new(1, 0, 0.1, 0)
logo.Position = UDim2.new(0, 0, 0.4, 0)
logo.BackgroundTransparency = 1
logo.TextColor3 = Color3.fromRGB(255, 105, 180)
logo.Font = Enum.Font.FredokaOne
logo.TextScaled = true
logo.Parent = background

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(0.6, 0, 0.05, 0)
barBg.Position = UDim2.new(0.2, 0, 0.6, 0)
barBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
barBg.Parent = background

local ui1 = Instance.new("UICorner")
ui1.Parent = barBg

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
barFill.Parent = barBg

local ui2 = Instance.new("UICorner")
ui2.Parent = barFill

-- 3. Congelar jogador
local function freezePlayer()
	local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	controls:Disable()
end

local function unfreezePlayer()
	local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	controls:Enable()
end

freezePlayer()

local loadingClosed = false

local function FecharLoadingScreen(shouldUnfreeze)
	if loadingClosed then return end
	loadingClosed = true

	if screenGui and screenGui.Parent then
		barFill:TweenSize(UDim2.new(1, 0, 1, 0), "Out", "Quad", 0.5)
		task.wait(0.6)
	end

	local tweenInfo = TweenInfo.new(1)
	local tween = TweenService:Create(background, tweenInfo, {BackgroundTransparency = 1})

	TweenService:Create(logo, tweenInfo, {TextTransparency = 1}):Play()
	TweenService:Create(barBg, tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(barFill, tweenInfo, {BackgroundTransparency = 1}):Play()
	tween:Play()

	tween.Completed:Wait()

	if screenGui then screenGui:Destroy() end

	if shouldUnfreeze then
		unfreezePlayer()
	end
end

-- Eventos
local EventsFolder = ReplicatedStorage:WaitForChild("Events")
local PlayerLoadedEvent = EventsFolder:WaitForChild("ScreenEvents"):WaitForChild("PlayerLoaded")
local ShowSelectionEvent = EventsFolder:WaitForChild("SelectionEvents"):WaitForChild("ShowCharacterSelection")

PlayerLoadedEvent.OnClientEvent:Connect(function()
	FecharLoadingScreen(true) 
end)

ShowSelectionEvent.OnClientEvent:Connect(function()
	FecharLoadingScreen(false)
end)

-- ==========================================================
-- ⭐ CARREGAMENTO DE ASSETS (OTIMIZADO)
-- ==========================================================

task.spawn(function()
	for i = 0, 0.8, 0.01 do
		if loadingClosed then break end
		barFill.Size = UDim2.new(i, 0, 1, 0)
		task.wait(0.05)
	end
end)

task.spawn(function()
	print("🔄 Iniciando pré-carregamento de assets...")

	local assets = {}

	-- 1. Assets pesados do mapa (Isso é o mais importante)
	local casas = game.Workspace:WaitForChild("Casas", 20)
	local characters = game.ReplicatedStorage:WaitForChild("Characters", 10)

	if casas then table.insert(assets, casas) end
	if characters then table.insert(assets, characters) end

	-- 2. SOM DA MORDIDA (O único asset real do sistema de mordida)
	-- Como Frames não precisam de download, removemos a busca por imagens aqui.
	-- Só precisamos garantir que o SOM esteja baixado.
	local BITE_SOUND_ID = "rbxassetid://115878657073501" 
	table.insert(assets, BITE_SOUND_ID)

	-- Carrega tudo
	local success, err = pcall(function()
		ContentProvider:PreloadAsync(assets)
	end)

	if success then
		print("✅ Assets carregados (Mapa + Som da Mordida)!")
	else
		warn("⚠️ Erro ao carregar assets:", err)
	end
end)