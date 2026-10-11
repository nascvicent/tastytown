local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local EntrouNaCasa = ReplicatedStorage:WaitForChild("EntrouNaCasa")

local WardrobeBillboardController = {}

-- Configurações
local NOME_GUI = "BotaoArmarioGui"
local DISTANCIA_MAXIMA = 30

-- Referência ao container principal (CasaGui)
local function getCasaGui()
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if not playerGui then return nil end
	return playerGui:FindFirstChild("CasaGui")
end

-- Ajusta o tamanho dinamicamente (mantido sua lógica)
local function ajustarTamanho(imageButton)
	local camera = Workspace.CurrentCamera
	if not imageButton or not camera then return end

	local resolution = camera.ViewportSize
	local largura = math.clamp(resolution.X * 0.08, 0, 100)
	local altura = math.clamp(resolution.Y * 0.12, 0, 100)

	imageButton.AnchorPoint = Vector2.new(0.5, 0.5)
	imageButton.Position = UDim2.new(0.5, 0, 0.4, 0)
	imageButton.Size = UDim2.new(0, largura, 0, altura)
end

-- Monitor de Vida: Cuida da visibilidade e remove se a casa sumir
local function criarMonitorDeVida(billboardGui, targetPart)
	local connection
	connection = RunService.Heartbeat:Connect(function()
		-- 1. Se o GUI ou a Parte alvo morreram, desconecta tudo
		if not billboardGui or not billboardGui.Parent or not targetPart or not targetPart.Parent then
			if billboardGui then billboardGui:Destroy() end
			connection:Disconnect()
			return
		end

		-- 2. Correção do Ponto 0,0,0 (Se perder o Adornee, ele vai pra origem)
		if billboardGui.Adornee ~= targetPart then
			-- Tenta reconectar antes de destruir
			billboardGui.Adornee = targetPart
		end

		-- 3. Verifica distância para mostrar/esconder
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")

		if rootPart then
			local dist = (rootPart.Position - targetPart.Position).Magnitude
			-- Só mostra se estiver perto E se a casa não estiver no 0,0,0 (loading)
			local casaCarregada = targetPart.Position.Y > -500 -- Assumindo que o limbo é muito baixo ou 0,0,0

			if dist <= DISTANCIA_MAXIMA and casaCarregada then
				billboardGui.Enabled = true

				-- Atualiza tamanho apenas quando visível
				local img = billboardGui:FindFirstChild("ImageButton")
				if img then ajustarTamanho(img) end
			else
				billboardGui.Enabled = false
			end
		else
			billboardGui.Enabled = false
		end
	end)
end

local function buscarEMontarBillboard()
	local interioresFolder = Workspace:FindFirstChild("Interiores")
	if not interioresFolder then return end

	local nomeInterior = player.Name .. "_Interior"
	local interiorModel = interioresFolder:FindFirstChild(nomeInterior)

	-- Se não achou a casa, não faz nada (espera o próximo loop)
	if not interiorModel then return end

	-- Verifica se a casa está na "Loading Area" (0,0,0)
	-- Se o Pivot for muito próximo de zero, a casa ainda não foi movida pro lote
	if interiorModel:GetPivot().Position.Magnitude < 10 then
		return 
	end

	local wardrobe = interiorModel:FindFirstChild("wardrobe")
	if not wardrobe then return end

	local armarioClick = wardrobe:FindFirstChild("Click")
	if not armarioClick then return end

	local casaGui = getCasaGui()
	if not casaGui then return end

	-- --- LÓGICA DE PROTEÇÃO (O PULO DO GATO) ---
	-- Verifica se JÁ existe um GUI válido conectado a este armário
	local guiExistente = casaGui:FindFirstChild(NOME_GUI)

	if guiExistente then
		if guiExistente.Adornee == armarioClick then
			-- O GUI já existe e está no lugar certo. SUCESSO!
			-- Não deleta, não recria. Apenas sai.
			return 
		else
			-- O GUI existe, mas está no lugar errado (casa antiga?). Deleta.
			guiExistente:Destroy()
		end
	end
	-- -------------------------------------------

	-- Se chegou aqui, é porque precisamos criar um NOVO
	local templateGui = ReplicatedStorage:FindFirstChild(NOME_GUI)
	if not templateGui then return end

	local guiClone = templateGui:Clone()
	guiClone.Name = NOME_GUI
	guiClone.Parent = casaGui -- Parent primeiro
	guiClone.Adornee = armarioClick -- Adornee depois
	guiClone.Enabled = false -- Começa invisível para evitar flicker no 0,0,0

	-- Inicia o monitor que vai ligar o Enabled quando estiver seguro
	criarMonitorDeVida(guiClone, armarioClick)

	print("WardrobeBillboard: Criado com sucesso para " .. player.Name)
end

function WardrobeBillboardController.Start()
	-- Loop de verificação passiva (menos agressivo)
	-- Ele roda para sempre, garantindo que se o player morrer ou resetar, o gui volta
	task.spawn(function()
		while true do
			task.wait(1) -- Verifica a cada 1 segundo
			buscarEMontarBillboard()
		end
	end)

	-- Gatilho extra quando entra na casa (para resposta rápida)
	EntrouNaCasa.Event:Connect(function()
		-- Pequeno delay para garantir que a casa saiu do 0,0,0
		task.wait(0.5) 
		buscarEMontarBillboard()
	end)

	-- Gatilho ao renascer
	player.CharacterAdded:Connect(function()
		task.wait(1)
		buscarEMontarBillboard()
	end)
end

return WardrobeBillboardController