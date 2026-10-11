--[[
	HouseService — casa de cada jogador (exterior no lote + interior isométrico no céu).

	• A casa montada é a equipada no inventário (InventoryService); a inicial é a
	  "Casa de Biscoito" (ServerStorage.CasaExterior / CasaInterior).
	• Equipar outra casa reconstrói exterior e interior na hora (se o jogador estiver
	  dentro, ele é levado para o interior novo).
	• Entrar: tocar na PortaEntrada do exterior. Sair: botão "Sair de Casa" na HUD
	  (Events.HouseEvents.ExitHouse) ou o prompt no capacho de saída do interior.
	  Os dois usam a transição de mordida (TeleportTransition).
]]

local HouseService = {}

-- === SERVIÇOS ===
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local InventoryService = require(script.Parent.InventoryService)
local TeleportTransition = require(script.Parent.TeleportTransition)
local ItemCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))

-- === EVENTOS ===
local EventsFolder = ReplicatedStorage:WaitForChild("Events")
local cameraEvent = EventsFolder:WaitForChild("SetCameraMode")
local cameraSyncEvent = EventsFolder:WaitForChild("CameraSyncRequest")
local exitHouseEvent = EventsFolder:WaitForChild("HouseEvents"):WaitForChild("ExitHouse")

-- === REFERÊNCIAS ===
local casasFolder = workspace:WaitForChild("Casas")
local interioresFolder = workspace:WaitForChild("Interiores")
local lotesFolder = workspace:WaitForChild("Lotes")

local starterExterior = ServerStorage:WaitForChild("CasaExterior")
local starterInterior = ServerStorage:WaitForChild("CasaInterior")

-- === CONFIGURAÇÕES ===
local ALTURA_INTERIOR = 5000
local MULTIPLICADOR_DISTANCIA = 12
local NOME_PART_SPAWN = "Base" -- Part dentro do Model do lote onde a casa nasce

--[[
	Casas por nome do item. Exterior/Interior: função que devolve o modelo-modelo.
	Sem Interior próprio, usa o interior inicial.
	FrontYaw: giro extra (graus) se a frente da casa não ficar virada para a rua.
	A entrada é a PortaEntrada do modelo; sem ela, uma é criada na "Porta" do
	modelo ou no meio da face da frente (-Z do modelo).
]]
local function shopModel(name)
	return function()
		local shopModels = ReplicatedStorage:FindFirstChild("ShopModels")
		local folder = shopModels and shopModels:FindFirstChild("ModelosCasas")
		return folder and folder:FindFirstChild(name)
	end
end
local function interiorModel(name)
	return function()
		local folder = ServerStorage:FindFirstChild("Interiors")
		return folder and folder:FindFirstChild(name)
	end
end

local HOUSES = {
	[ItemCatalog.StarterHouse] = {
		Exterior = function() return starterExterior end,
		Interior = function() return starterInterior end,
	},
	["Candy Mansion"] = {
		Exterior = shopModel("CandyMansion"),
		Interior = interiorModel("CandyMansionInterior"),
		FrontYaw = 0,
	},
	["Cheese House"] = { Exterior = shopModel("CheeseHouse") },
	["Sushi House"] = { Exterior = shopModel("SushiHouse") },
}

local lotesOcupados = {}
local houses = {} -- [player] = { lote, exterior, interior, houseName, spawnInterior, exitTarget, focus }

-- === FUNÇÕES AUXILIARES ===

local function getPartesDoLote(loteModel)
	local spawnPart = NOME_PART_SPAWN and loteModel:FindFirstChild(NOME_PART_SPAWN)
	if not spawnPart then
		for _, child in ipairs(loteModel:GetChildren()) do
			if child:IsA("BasePart") and not child:IsA("UnionOperation") then
				spawnPart = child
				break
			end
		end
	end
	return spawnPart, loteModel:FindFirstChildWhichIsA("UnionOperation")
end

local function getLoteLivre()
	for _, lote in ipairs(lotesFolder:GetChildren()) do
		if not lotesOcupados[lote] then
			return lote
		end
	end
	return nil
end

local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-3 and f.Unit or nil
end

local function stripScripts(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
end

local function invisiblePart(name, size, cframe, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Parent = parent
	return p
end

-- Coloca no lote uma casa que não segue o padrão do exterior inicial e cria a entrada.
-- Convenção (igual à casa inicial): a frente da casa fica no -Z do lote (LookVector).
local function placeGenericExterior(exterior, spawnPart, config)
	local cf, size = exterior:GetBoundingBox()
	local center = cf.Position
	local door = exterior:FindFirstChild("Porta", true)
	local doorPos = door and (door:IsA("Model") and door:GetPivot().Position or door:IsA("BasePart") and door.Position)

	-- Giro que leva o lado da porta para o -Z. Sem "Porta" no modelo, FrontYaw diz
	-- quantos graus o lado da porta está girado em relação ao -Z do modelo.
	local yaw = -math.rad(config.FrontYaw or 0)
	local d = doorPos and flat(doorPos - center)
	if d then
		yaw = math.atan2(d.X, -d.Z)
	end

	-- Modelos de vitrine podem ter peças soltas: ancora tudo para a casa não desabar
	for _, d in ipairs(exterior:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end

	exterior.WorldPivot = CFrame.new(center.X, center.Y - size.Y / 2, center.Z)
	local ground = spawnPart.CFrame * CFrame.new(0, spawnPart.Size.Y / 2, 0)
	exterior:PivotTo(ground * CFrame.Angles(0, yaw, 0))

	-- Entrada: na porta do modelo ou no meio da face da frente
	cf, size = exterior:GetBoundingBox()
	center = cf.Position
	local bottom = center.Y - size.Y / 2
	local front = flat(ground.LookVector) or Vector3.new(0, 0, -1)
	local entrancePos
	door = exterior:FindFirstChild("Porta", true)
	if door then
		local p = door:IsA("Model") and door:GetPivot().Position or door.Position
		entrancePos = Vector3.new(p.X, bottom + 3, p.Z)
		front = flat(entrancePos - center) or front
	else
		-- Meia-extensão da caixa na direção da frente
		local extent = math.abs(cf.RightVector:Dot(front)) * size.X / 2 + math.abs(cf.LookVector:Dot(front)) * size.Z / 2
		entrancePos = Vector3.new(center.X, bottom + 3, center.Z) + front * extent
	end

	local porta = invisiblePart("PortaEntrada", Vector3.new(5, 6, 3), CFrame.lookAt(entrancePos, entrancePos + front), exterior)
	porta.CanTouch = true
	local frentePos = entrancePos + front * 7
	invisiblePart("FrenteDaCasa", Vector3.new(4, 1, 2), CFrame.lookAt(frentePos, frentePos + front), exterior)
end

-- Saída do interior: capacho com prompt (substitui a PortaSaida de encostar)
local function setupExitPrompt(player, interior)
	local marker = interior:FindFirstChild("SaidaCasa", true) or interior:FindFirstChild("PortaSaida", true)
	if not marker or not marker:IsA("BasePart") then return end

	if marker.Name == "PortaSaida" then
		-- Interior antigo: a peça cinza vira só a âncora invisível do prompt
		marker.Transparency = 1
		marker.CanCollide = false
	end
	marker.CanTouch = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SairPrompt"
	prompt.ActionText = "Sair de casa"
	prompt.ObjectText = "Porta"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = marker

	prompt.Triggered:Connect(function(who)
		if who == player then
			HouseService.ExitHouse(player)
		end
	end)
end

-- === MONTAGEM DA CASA ===

local function destroyHouse(state)
	if state.exterior then state.exterior:Destroy() end
	if state.interior then state.interior:Destroy() end
	state.exterior, state.interior = nil, nil
end

local function enterHouse(player)
	local state = houses[player]
	if not state or not state.spawnInterior then return end
	local character = player.Character
	if not character or character:GetAttribute("InsideHouse") then return end

	TeleportTransition.Request(player, state.spawnInterior, {
		onArrive = function(char)
			char:SetAttribute("InsideHouse", true)
			cameraEvent:FireClient(player, "Isometrico", state.focus)
			task.delay(0.2, function()
				if player.Parent then cameraEvent:FireClient(player, "Isometrico", state.focus) end
			end)
		end,
	})
end

local function buildHouse(player, state)
	local equipped = InventoryService.GetEquipped(player, "House")
	local houseName = (equipped and HOUSES[equipped]) and equipped or ItemCatalog.StarterHouse
	local config = HOUSES[houseName]
	local spawnPart = state.spawnPart

	-- Exterior
	local exteriorTemplate = config.Exterior() or starterExterior
	local exterior = exteriorTemplate:Clone()
	exterior.Name = player.Name .. "_Exterior"
	if exteriorTemplate ~= starterExterior then stripScripts(exterior) end

	if exterior:FindFirstChild("PortaEntrada", true) then
		exterior:PivotTo(spawnPart.CFrame) -- casa no padrão inicial: posiciona como sempre
	else
		placeGenericExterior(exterior, spawnPart, config)
	end
	exterior:SetAttribute("OwnerId", player.UserId)
	exterior:SetAttribute("LoteOriginal", state.lote.Name)
	exterior:SetAttribute("Casa", houseName)
	exterior.Parent = casasFolder

	-- Interior (no céu, alinhado à rotação do lote)
	local interiorTemplate = (config.Interior and config.Interior()) or starterInterior
	local interior = interiorTemplate:Clone()
	interior.Name = player.Name .. "_Interior"
	local posicao = Vector3.new(spawnPart.Position.X * MULTIPLICADOR_DISTANCIA, ALTURA_INTERIOR, spawnPart.Position.Z * MULTIPLICADOR_DISTANCIA)
	interior:PivotTo(CFrame.new(posicao) * spawnPart.CFrame.Rotation)
	interior.Parent = interioresFolder

	local spawnInterior = interior:FindFirstChild("SpawnInterior", true) or interior:FindFirstChildWhichIsA("BasePart", true)
	interior.PrimaryPart = spawnInterior

	local portaEntrada = exterior:FindFirstChild("PortaEntrada", true)
	local frenteDaCasa = exterior:FindFirstChild("FrenteDaCasa", true)
	if not (portaEntrada and frenteDaCasa and spawnInterior) then
		warn("[HouseService] Casa '" .. houseName .. "' sem PortaEntrada/FrenteDaCasa/SpawnInterior")
	end

	state.exterior, state.interior, state.houseName = exterior, interior, houseName
	state.spawnInterior = spawnInterior and (spawnInterior.CFrame + Vector3.new(0, 3, 0))
	state.focus = spawnInterior
	if frenteDaCasa and portaEntrada then
		state.exitTarget = frenteDaCasa.CFrame + portaEntrada.CFrame.LookVector * 5
	end

	if portaEntrada then
		portaEntrada.Touched:Connect(function(hit)
			if Players:GetPlayerFromCharacter(hit.Parent) == player then
				enterHouse(player)
			end
		end)
	end
	setupExitPrompt(player, interior)

	print("[HouseService] Casa '" .. houseName .. "' montada para", player.Name, "no", state.lote.Name)
end

-- === SAIR ===
function HouseService.ExitHouse(player)
	local state = houses[player]
	local character = player.Character
	if not state or not state.exitTarget or not character then return end
	if not character:GetAttribute("InsideHouse") then return end

	TeleportTransition.Request(player, state.exitTarget, {
		onArrive = function(char)
			char:SetAttribute("InsideHouse", false)
			cameraEvent:FireClient(player, "Normal")
			task.delay(0.2, function()
				if player.Parent then cameraEvent:FireClient(player, "Normal") end
			end)
		end,
	})
end

-- === CICLO DE VIDA DO JOGADOR ===
function HouseService.onPlayerAdded(player)
	if houses[player] then return end

	local loteModel = getLoteLivre()
	if not loteModel then
		warn("Servidor cheio! Nenhum lote disponível.")
		return
	end

	local spawnPart, limiteUnion = getPartesDoLote(loteModel)
	if not spawnPart then
		warn("ERRO CRÍTICO: O Lote " .. loteModel.Name .. " não tem uma Part válida para spawnar a casa.")
		return
	end

	lotesOcupados[loteModel] = player
	local state = { lote = loteModel, spawnPart = spawnPart }
	houses[player] = state

	-- Precisa saber qual casa está equipada
	InventoryService.WaitForData(player, 15)
	if not player.Parent then
		lotesOcupados[loteModel] = nil
		houses[player] = nil
		return
	end

	if limiteUnion then
		limiteUnion.Transparency = 1
		limiteUnion.CanCollide = false
	end

	buildHouse(player, state)
end

function HouseService.onPlayerRemoving(player)
	local state = houses[player]
	houses[player] = nil
	if not state then return end

	destroyHouse(state)
	lotesOcupados[state.lote] = nil
	local _, limiteUnion = getPartesDoLote(state.lote)
	if limiteUnion then
		limiteUnion.Transparency = 0
		limiteUnion.CanCollide = true
	end
end

-- Equipou outra casa: reconstrói (e leva para dentro da nova se estava em casa)
InventoryService.EquippedChanged:Connect(function(player, category, itemName)
	if category ~= "House" then return end
	local state = houses[player]
	if not state or not state.exterior or state.houseName == itemName then return end

	local character = player.Character
	local wasInside = character and character:GetAttribute("InsideHouse")
	destroyHouse(state)
	buildHouse(player, state)

	if wasInside and state.spawnInterior then
		TeleportTransition.Instant(player, state.spawnInterior, function(char)
			char:SetAttribute("InsideHouse", true)
			cameraEvent:FireClient(player, "Isometrico", state.focus)
		end)
	end
end)

exitHouseEvent.OnServerEvent:Connect(function(player)
	HouseService.ExitHouse(player)
end)

-- === HANDSHAKE DE CÂMERA ===
cameraSyncEvent.OnServerEvent:Connect(function(player)
	local char = player.Character
	local inside = char and char:GetAttribute("InsideHouse") == true

	if inside then
		local interior = interioresFolder:FindFirstChild(player.Name .. "_Interior")
		cameraEvent:FireClient(player, "Isometrico", interior and interior.PrimaryPart)
	else
		cameraEvent:FireClient(player, "Normal")
	end
end)

return HouseService
