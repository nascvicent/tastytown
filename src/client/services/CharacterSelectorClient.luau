-- ModuleScript: CharacterSelectorClient
local CharacterSelectorClient = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ContentProvider = game:GetService("ContentProvider") -- Serviço para carregar assets

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SelectionEvents"):WaitForChild("ShowCharacterSelection")


local function Unfreeze()
	local playerScripts = player:WaitForChild("PlayerScripts")
	local playerModule = require(playerScripts:WaitForChild("PlayerModule"))
	playerModule:GetControls():Enable()
end

-- Função segura para alterar a visibilidade das HUDs
local function ToggleHuds(estado)
	local hudFolder = playerGui:FindFirstChild("Hud")
	if hudFolder then
		if hudFolder:FindFirstChild("CoinGui") then hudFolder.CoinGui.Enabled = estado end
		if hudFolder:FindFirstChild("HudGui") then hudFolder.HudGui.Enabled = estado end
	end

	local casaGui = playerGui:FindFirstChild("CasaGui")
	if casaGui then casaGui.Enabled = estado end

	local lojasFolder = playerGui:FindFirstChild("Lojas")
	if lojasFolder and lojasFolder:FindFirstChild("ShopGui") then
		lojasFolder.ShopGui.Enabled = estado
	end
end

-- Função para obter a GUI de forma resiliente (funciona em net lenta)
local function GetGuiTemplate()
	-- 1. Tenta achar no próprio PlayerGui (O Roblox costuma colocar lá ao entrar)
	local existing = playerGui:FindFirstChild("CharacterSelectionGui")
	if existing then
		-- Se já existe, usamos ela mesma, mas resetamos o estado
		return existing
	end

	-- 2. Se não está no PlayerGui, tenta clonar do StarterGui com timeout alto
	local template = StarterGui:WaitForChild("CharacterSelectionGui", 30)
	if template then
		return template:Clone()
	end

	return nil
end

function CharacterSelectorClient.Start()

	-- [SEGURANÇA 1] Espera o jogo carregar totalmente antes de fazer qualquer coisa.
	-- Isso evita que o script rode enquanto a tela ainda está preta de loading no 4G.
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	print("Cliente carregado. Iniciando sistema de seleção...")

	local function ShowSelectionScreen()
		print("Abrindo tela de seleção...")

		local newGui = GetGuiTemplate()

		if not newGui then
			warn("ERRO CRÍTICO: Não foi possível carregar a GUI (Internet muito lenta ou asset faltando).")
			-- Tentativa de emergência: Tentar novamente em 2 segundos
			task.delay(2, function() 
				remote:FireServer("RequestUI") -- Opcional: Pedir ao server de novo
			end)
			return
		end

		-- Configura a GUI
		newGui.Parent = playerGui
		newGui.Enabled = true

		-- Garante que o Frame principal esteja visível
		local charFrame = newGui:FindFirstChild("CharacterFrame")
		if charFrame then charFrame.Visible = true end

		ToggleHuds(false)
		print("Seleção exibida.")
	end

	-- Conecta o evento do servidor
	remote.OnClientEvent:Connect(ShowSelectionScreen)

	-- [SEGURANÇA 2 - ANTI-LIMBO]
	-- Se o jogador entrou e não tem personagem, mas o evento não disparou em 3 segundos,
	-- pode ser que ele tenha perdido o evento por causa da internet lenta.
	task.spawn(function()
		task.wait(20) -- Espera um tempo prudente

		-- Verifica: Não tem personagem? A GUI não está aberta?
		local hasCharacter = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local isGuiOpen = playerGui:FindFirstChild("CharacterSelectionGui") and playerGui.CharacterSelectionGui.Enabled

		if not hasCharacter and not isGuiOpen then
			warn("ALERTA DE LIMBO: O evento do servidor parece ter sido perdido. Forçando abertura da UI.")
			ShowSelectionScreen()
		end
	end)

	-- 3. O RETORNO (Quando o personagem nasce)
	player.CharacterAdded:Connect(function()
		local selecaoAberta = playerGui:FindFirstChild("CharacterSelectionGui")

		-- Se a seleção NÃO está aberta, o player DEVE poder andar
		if not (selecaoAberta and selecaoAberta.Enabled) then
			Unfreeze() -- Garante que ele não nasça travado
			task.wait(0.5)
			ToggleHuds(true)
		end
	end)
end

return CharacterSelectorClient