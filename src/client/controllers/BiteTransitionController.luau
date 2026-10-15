local BiteTransitionController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService") -- Necessário para forçar a tela a atualizar

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configurações
local BITE_SOUND_ID = "rbxassetid://115878657073501" 
local BITE_INTERVAL = 0.3 
local REVERSE_INTERVAL = 0.25 
local HOLD_TIME = 1.5 
local FINAL_FADE_TIME = 0.5 

-- Variáveis locais
local BiteEffectEvent
local biteGui
local frameMain
local mordidas = {}

local function initialize()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events")
	local screenEvents = eventsFolder:WaitForChild("ScreenEvents")
	BiteEffectEvent = screenEvents:WaitForChild("BiteEffectEvent")

	-- A BiteAnim só chega ao PlayerGui quando o personagem nasce (CharacterAutoLoads
	-- desligado), o que pode passar de 10s; espera sem limite (Start roda em segundo plano).
	-- Com timeout math.huge o WaitForChild não solta o aviso de "Infinite yield".
	biteGui = playerGui:WaitForChild("BiteAnim", math.huge)

	frameMain = biteGui:WaitForChild("FrameMain", 5)
	if not frameMain then return false end

	mordidas = {
		frameMain:WaitForChild("PrimeiraMordida"),
		frameMain:WaitForChild("SegundaMordida"),
		frameMain:WaitForChild("TerceiraMordida"),
		frameMain:WaitForChild("QuartaMordida")
	}

	-- MUDANÇA 1: Mantemos a GUI ativada, escondemos apenas o Frame
	biteGui.IgnoreGuiInset = true
	biteGui.DisplayOrder = 100 -- Garante que fica na frente de tudo
	biteGui.ResetOnSpawn = false -- Evita que suma no teleporte
	biteGui.Enabled = true 

	frameMain.Visible = false
	for _, m in ipairs(mordidas) do m.Visible = false end

	print("✅ BiteAnim inicializado e pronto na memória")
	return true
end

local function playBiteSound()
	local success, err = pcall(function()
		local biteSound = Instance.new("Sound")
		biteSound.SoundId = BITE_SOUND_ID
		biteSound.Volume = 0.5 -- Aumentei um pouco
		biteSound.Parent = SoundService
		biteSound:Play()
		game:GetService("Debris"):AddItem(biteSound, 2)
	end)
end

local function playBiteAnimation()
	print("2. [Client] Iniciando animação...")

	-- Garante que o FrameMain apareça
	frameMain.Visible = true

	-- Pré-reset nas mordidas (garantia)
	for _, m in ipairs(mordidas) do m.Visible = false end

	-- FASE 1: Tela enchendo
	for i, mordida in ipairs(mordidas) do
		playBiteSound()
		mordida.Visible = true

		-- TRUQUE PARA MOBILE: Força o frame renderizar antes de continuar
		RunService.RenderStepped:Wait() 

		task.wait(BITE_INTERVAL)
	end

	print("2.5 [Client] Tela cheia. Solicitando teleporte...")

	-- Pequena pausa extra pra garantir que a tela está totalmente coberta antes do lag do teleporte
	task.wait(0.1) 

	if BiteEffectEvent then
		BiteEffectEvent:FireServer() 
	end

	-- FASE 2: Mantém a tela cheia
	task.wait(HOLD_TIME)

	-- FASE 3: Tela limpando (Reverse)
	for i = #mordidas, 1, -1 do
		playBiteSound()
		mordidas[i].Visible = false
		RunService.RenderStepped:Wait()
		task.wait(REVERSE_INTERVAL)
	end

	task.wait(FINAL_FADE_TIME)
	frameMain.Visible = false -- Esconde só o frame, mantém a GUI ligada
	print("✅ [Client] Animação finalizada")
end

function BiteTransitionController.Start()
	task.spawn(function()
		if not initialize() then
			warn("❌ Falha na inicialização do BiteTransitionController (BiteAnim sem FrameMain)")
			return
		end

		BiteEffectEvent.OnClientEvent:Connect(playBiteAnimation)
	end)
end

return BiteTransitionController