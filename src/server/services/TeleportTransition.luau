--[[
	TeleportTransition — teleporte com a transição de mordida do jogo.

	Fluxo (igual às portas originais):
	  servidor BiteEffectEvent:FireClient -> cliente anima as mordidas e, com a tela
	  coberta, responde BiteEffectEvent:FireServer -> servidor teleporta e dispara
	  FecharPortaEvent (BindableEvent escutado pelos scripts das portas).

	Uso:
	  TeleportTransition.Request(player, targetCFrame, {
	      onArrive = function(character) ... end, -- opcional: câmera, atributos etc.
	  })
]]

local TeleportTransition = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")
local BiteEffectEvent = Events:WaitForChild("ScreenEvents"):WaitForChild("BiteEffectEvent")
local FecharPortaEvent = Events:WaitForChild("FecharPortaEvent")

-- A animação leva ~1,3s para cobrir a tela + ~2,5s para descobrir
local COOLDOWN = 4
-- Se o cliente não responder (ex.: BiteAnim ausente), teleporta mesmo assim
local BITE_TIMEOUT = 3
-- Tempo máximo segurando o personagem ancorado esperando o chão do destino carregar
local STREAM_HOLD_TIMEOUT = 8

local lastUse = {}
local pending = {} -- [player] = { target, onArrive }

local holdToken = setmetatable({}, { __mode = "k" }) -- [character] = teleporte mais recente

-- Teleporta já; retorna true se o personagem foi movido
local function teleportNow(player, target, onArrive)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	-- Sai do carro antes (senão leva o veículo junto ou fica preso no assento)
	if humanoid.SeatPart then
		humanoid.Sit = false
		task.wait(0.15)
	end

	-- Ancorado do início ao fim: enquanto espera o streaming (o chão de onde ele está
	-- pode sumir, ex.: a casa sendo trocada) e no destino até o chão de lá chegar ao
	-- cliente (StreamingEnabled) — sem isso ele caía e ficava enterrado ou no vazio
	local token = {}
	holdToken[character] = token
	character:SetAttribute("Teleportando", true)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
	end
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 3)
	end)
	if not character.Parent then return false end
	character:PivotTo(target)

	if onArrive then
		task.spawn(onArrive, character)
	end
	FecharPortaEvent:Fire()

	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(target.Position, STREAM_HOLD_TIMEOUT)
		end)
		task.wait(0.2)
		if holdToken[character] ~= token then return end -- outro teleporte assumiu
		if root and root.Parent then root.Anchored = false end
		task.wait(0.8)
		if holdToken[character] == token and character.Parent then
			character:SetAttribute("Teleportando", false)
		end
	end)
	return true
end

-- Começa a transição; retorna false se o jogador não pode teleportar agora
function TeleportTransition.Request(player, target, opts)
	opts = opts or {}
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Teleportando") then return false end
	if pending[player] then return false end

	local now = os.clock()
	if lastUse[player] and now - lastUse[player] < COOLDOWN then return false end
	lastUse[player] = now

	local entry = { target = target, onArrive = opts.onArrive }
	pending[player] = entry
	BiteEffectEvent:FireClient(player)

	task.delay(BITE_TIMEOUT, function()
		if pending[player] == entry then
			pending[player] = nil
			teleportNow(player, entry.target, entry.onArrive)
		end
	end)
	return true
end

-- Teleporte imediato, sem animação (ex.: reconstrução da casa com o jogador dentro)
-- Retorna true se o personagem foi movido.
function TeleportTransition.Instant(player, target, onArrive)
	return teleportNow(player, target, onArrive)
end

BiteEffectEvent.OnServerEvent:Connect(function(player)
	local entry = pending[player]
	if entry then
		pending[player] = nil
		teleportNow(player, entry.target, entry.onArrive)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastUse[player] = nil
	pending[player] = nil
end)

return TeleportTransition
