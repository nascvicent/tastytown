--[[
	Atualiza o script da porta da casa inicial (ServerStorage/CasaExterior.rbxm)
	para a versão polida das portas do jogo: fecha com o FecharPortaEvent ao teleportar e
	acende a PortaEntrada (Neon) enquanto a porta está aberta.

	  lune run tools/houses/set_starter_door_script.luau
]]

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

local PATH = "src/ServerStorage/CasaExterior.rbxm"

local SOURCE = [==[
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local portaModelo = script.Parent
local entrada = portaModelo:WaitForChild("PortaEntrada") -- brilho Neon do "portal" quando a porta abre
local hinge = portaModelo:WaitForChild("Hing")
local detector = portaModelo:WaitForChild("Detector")

-- Disparado pelo servidor ao teleportar (TeleportTransition) para a porta fechar
local FecharPortaEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("FecharPortaEvent")

local aberta = false

-- --- Configuração das Animações ---
local cframeFechada = hinge.CFrame
local cframeAberta = cframeFechada * CFrame.Angles(0, math.rad(-90), 0)
local tweenInfo = TweenInfo.new(0.5)

local tweenOpen = TweenService:Create(hinge, tweenInfo, {CFrame = cframeAberta})
local tweenClose = TweenService:Create(hinge, tweenInfo, {CFrame = cframeFechada})

-- --- Funções Auxiliares ---
local function fecharPorta()
	if aberta then
		aberta = false
		tweenClose:Play()
	end
end

-- Apaga o brilho só quando a porta termina de fechar (e continua fechada)
tweenClose.Completed:Connect(function()
	if not aberta then
		entrada.Transparency = 1
	end
end)

local function abrirPorta()
	if not aberta then
		aberta = true
		tweenOpen:Play()
		entrada.Transparency = 0
	end
end

-- --- Lógica de Gatilho ---

-- 1. Tocou no detector (Abre)
detector.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if player then
		abrirPorta()
	end
end)

-- 2. Saiu do detector (Fecha - Método Normal)
detector.TouchEnded:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if player then
		fecharPorta()
	end
end)

-- 3. Recebeu sinal do Teleporte (Fecha Forçado)
FecharPortaEvent.Event:Connect(function()
	fecharPorta()
end)
]==]

local model = roblox.deserializeModel(fs.readFile(PATH))[1]
local script = model:FindFirstChild("Script")
assert(script and script:IsA("Script"), "CasaExterior sem Script")
script.Source = SOURCE

fs.writeFile(PATH, roblox.serializeModel({ model }, false))
print("script da porta atualizado em " .. PATH)
