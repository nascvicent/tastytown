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
local TweenService = game:GetService("TweenService")

local InventoryService = require(script.Parent.InventoryService)
local TeleportTransition = require(script.Parent.TeleportTransition)
local ItemCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))

-- === EVENTOS ===
local EventsFolder = ReplicatedStorage:WaitForChild("Events")
local cameraEvent = EventsFolder:WaitForChild("SetCameraMode")
local cameraSyncEvent = EventsFolder:WaitForChild("CameraSyncRequest")
local exitHouseEvent = EventsFolder:WaitForChild("HouseEvents"):WaitForChild("ExitHouse")
local showSelectionEvent = EventsFolder:WaitForChild("SelectionEvents"):WaitForChild("ShowCharacterSelection")
local fecharPortaEvent = EventsFolder:WaitForChild("FecharPortaEvent") -- disparado pelo TeleportTransition

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
		-- Interior gerado (tools/interiors/CasaDeBiscoito.luau); o antigo fica de reserva
		Interior = function() return interiorModel("CasaDeBiscoitoInterior")() or starterInterior end,
	},
	["Candy Mansion"] = {
		Exterior = shopModel("CandyMansion"),
		Interior = interiorModel("CandyMansionInterior"),
		FrontYaw = 0,
	},
	["Cheese House"] = { Exterior = shopModel("CheeseHouse") },
	["Sushi House"] = {
		Exterior = shopModel("SushiHouse"),
		Interior = interiorModel("SushiHouseInterior"),
	},
}

local lotesOcupados = {}
local houses = {} -- [player] = { lote, exterior, interior, houseName, spawnInterior, exitTarget, focus }
local rebuildIfChanged -- definida mais abaixo

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

-- Direção da rua em cada lote: em vez de supor, posiciona a casa inicial (sem colocar no
-- mundo) e vê para onde aponta a porta dela. É o lado que o mapa foi pensado para a frente.
-- O pivô da casa inicial (que a vira para a rua) vem da PrimaryPart "Part". A referência
-- pode se perder quando o Rojo recria o modelo no Studio; sem ela a casa ficava de costas.
local function ensureStarterPrimaryPart(model)
	local base = model:FindFirstChild("Part")
	if not model.PrimaryPart and base and base:IsA("BasePart") and base.Anchored then
		model.PrimaryPart = base
	end
end

-- A mesma sonda dá a altura do chão: a base da casa inicial, que fica apoiada certinho
-- (o topo da Part "Base" do lote pode ficar acima da grama e fazia a casa flutuar).
local lotCache = {}
local function lotReference(spawnPart)
	local cached = lotCache[spawnPart]
	if cached then return cached.front, cached.groundY end
	local probe = starterExterior:Clone()
	ensureStarterPrimaryPart(probe)
	probe:PivotTo(spawnPart.CFrame)
	local center = probe:GetBoundingBox().Position
	local door = probe:FindFirstChild("PortaEntrada", true)
	local front = door and flat(door.Position - center)

	-- Base visível da casa inicial (ignora gatilhos invisíveis, que podem descer mais)
	local groundY = math.huge
	for _, part in ipairs(probe:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local cf, size = part.CFrame, part.Size
			local halfHeight = math.abs(cf.RightVector.Y) * size.X / 2 + math.abs(cf.UpVector.Y) * size.Y / 2 + math.abs(cf.LookVector.Y) * size.Z / 2
			groundY = math.min(groundY, cf.Position.Y - halfHeight)
		end
	end
	probe:Destroy()

	front = front or flat(spawnPart.CFrame.LookVector) or Vector3.new(0, 0, -1)
	if groundY == math.huge then groundY = spawnPart.Position.Y + spawnPart.Size.Y / 2 end
	lotCache[spawnPart] = { front = front, groundY = groundY }
	return front, groundY
end

-- Ângulo (em torno de Y) de uma direção no plano XZ: 0 = +Z, cresce em direção a +X.
-- CFrame.Angles(0, a, 0) soma "a" a esse ângulo.
local function heading(v)
	return math.atan2(v.X, v.Z)
end

-- Coloca no lote uma casa que não segue o padrão do exterior inicial e cria a entrada.
-- A porta da casa fica virada para a rua do lote (mesmo lado da porta da casa inicial).
-- Porta animada das casas da loja: Model "Porta" com a dobradiça "Hing" (ancorada, as
-- folhas soldadas nela) e o "Detector" (volume invisível que abre a porta).
local function findAnimatedDoor(exterior)
	local hinge = exterior:FindFirstChild("Hing", true)
	if not (hinge and hinge:IsA("BasePart")) then return nil end
	local detector = hinge.Parent:FindFirstChild("Detector")
	if not (detector and detector:IsA("BasePart")) then return nil end
	return hinge.Parent, hinge, detector
end

-- Y mais baixo das peças visíveis do modelo, fora as de "exclude" (nil se não houver)
local function visibleBottomY(model, exclude)
	local minY = math.huge
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 and not (exclude and part:IsDescendantOf(exclude)) then
			local cf, s = part.CFrame, part.Size
			local halfHeight = math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
			minY = math.min(minY, cf.Position.Y - halfHeight)
		end
	end
	return minY < math.huge and minY or nil
end

local function placeGenericExterior(exterior, spawnPart, config)
	-- Modelos de vitrine podem ter peças soltas: ancora tudo para a casa não desabar,
	-- menos as folhas da porta animada (presas na dobradiça, que é ancorada)
	local doorModel = findAnimatedDoor(exterior)
	for _, part in ipairs(exterior:GetDescendants()) do
		if part:IsA("BasePart") and not (doorModel and part:IsDescendantOf(doorModel) and not part.Anchored) then
			part.Anchored = true
		end
	end

	-- Pivô limpo, sem rotação: modelos importados (ex.: a Candy Mansion) trazem um
	-- PivotOffset inclinado na PrimaryPart (90° em X); usar esse pivô no PivotTo
	-- tombava a casa de lado. Sem PrimaryPart, o WorldPivot é só do modelo.
	exterior.PrimaryPart = nil
	exterior.WorldPivot = CFrame.new(exterior:GetBoundingBox().Position)

	-- Agora a caixa é medida nos eixos do mundo (Y = altura de verdade). A altura do
	-- pivô vem da base visível da casa: a porta (que nos modelos fica enterrada no chão)
	-- e os volumes invisíveis (Detector) desciam mais e deixavam a casa flutuando.
	local cf, size = exterior:GetBoundingBox()
	local center = cf.Position
	exterior.WorldPivot = CFrame.new(center.X, visibleBottomY(exterior, doorModel) or center.Y - size.Y / 2, center.Z)

	-- Lado da porta no modelo original: a "Porta" do modelo ou, sem ela, o -Z girado por FrontYaw
	local door = exterior:FindFirstChild("Porta", true)
	local doorPos = door and (door:IsA("Model") and door:GetPivot().Position or door:IsA("BasePart") and door.Position)
	local doorDir = (doorPos and flat(doorPos - center))
		or (CFrame.Angles(0, math.rad(config.FrontYaw or 0), 0) * Vector3.new(0, 0, -1))

	local front, groundY = lotReference(spawnPart)
	local yaw = heading(front) - heading(doorDir)
	-- Um pouquinho enterrada para não aparecer fresta entre a casa e a grama
	local groundTop = Vector3.new(spawnPart.Position.X, groundY - 0.2, spawnPart.Position.Z)
	exterior:PivotTo(CFrame.new(groundTop) * CFrame.Angles(0, yaw, 0))

	-- Entrada: na porta do modelo ou no meio da face da frente
	cf, size = exterior:GetBoundingBox()
	center = cf.Position
	local bottom = visibleBottomY(exterior, doorModel) or center.Y - size.Y / 2
	local entrancePos
	door = exterior:FindFirstChild("Porta", true)
	if door then
		-- No vão da porta: o "Enter" (painel da porta animada) ou a própria folha. O pivô do
		-- Model "Porta" fica deslocado (o Detector gigante entra na conta) e o gatilho
		-- ficava longe da porta, então encostar nela não fazia nada.
		local doorway = door:IsA("Model") and (door:FindFirstChild("Enter") or door:FindFirstChild("Porta"))
		local p = (doorway and doorway:IsA("BasePart") and doorway.Position)
			or (door:IsA("Model") and door:GetPivot().Position)
			or door.Position
		entrancePos = Vector3.new(p.X, bottom + 3, p.Z)
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

-- Ponto seguro no chão perto de "position" (raycast de cima para baixo, ignorando a casa
-- e os personagens). Evita mandar o jogador para dentro do morro ou para o vazio.
local function groundedSpot(position, facing, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { exclude }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(list, plr.Character) end
	end
	params.FilterDescendantsInstances = list
	params.RespectCanCollide = true -- ignora peças invisíveis sem colisão (ex.: limite do lote)

	local hit = workspace:Raycast(position + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	if not hit then return nil end
	local spot = hit.Position + Vector3.new(0, 3.5, 0)
	return CFrame.lookAt(spot, spot + facing), hit.Instance
end

-- Porta animada (Hing + peças soltas soldadas): garante as soldas antes de a casa ir
-- para o mundo. As WeldConstraints podem chegar sem Part0/Part1 (ex.: modelo recriado
-- pela sincronização do Rojo) e aí a porta despencava. Toda peça não ancorada da casa
-- pertence à porta, então é soldada direto na dobradiça.
local function repairDoorWelds(exterior)
	local hinge = exterior:FindFirstChild("Hing", true)
	if not hinge or not hinge:IsA("BasePart") then return end

	for _, weld in ipairs(exterior:GetDescendants()) do
		if weld:IsA("WeldConstraint") and (not weld.Part0 or not weld.Part1) then
			weld:Destroy()
		end
	end

	for _, part in ipairs(exterior:GetDescendants()) do
		if part:IsA("BasePart") and not part.Anchored and part ~= hinge then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "SoldaPorta"
			weld.Part0 = hinge
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

--[[
	Anima a porta das casas da loja (a casa inicial tem script próprio): abre quando um
	jogador entra no Detector, fecha quando não sobra ninguém nele ou no teleporte
	(FecharPortaEvent). O "Enter" (painel Neon na porta) só brilha com a porta aberta.
	Os scripts dos modelos da loja são removidos ao montar, então a lógica fica aqui.
]]
local DOOR_OPEN_ANGLE = math.rad(-90) -- mesmo giro do script da porta da casa inicial
local DOOR_TWEEN = TweenInfo.new(0.5)
local DOOR_CHECK_INTERVAL = 0.3

local function hasPlayerInside(detector, params)
	for _, part in ipairs(workspace:GetPartBoundsInBox(detector.CFrame, detector.Size, params)) do
		if Players:GetPlayerFromCharacter(part.Parent) then return true end
	end
	return false
end

local function setupAnimatedDoor(exterior)
	local doorModel, hinge, detector = findAnimatedDoor(exterior)
	if not doorModel then return end

	local glow = doorModel:FindFirstChild("Enter")
	local function setGlow(on)
		if not (glow and glow:IsA("BasePart")) then return end
		glow.Transparency = on and 0 or 1
		for _, light in ipairs(glow:GetDescendants()) do
			if light:IsA("Light") then light.Enabled = on end
		end
	end
	if glow and glow:IsA("BasePart") then
		glow.CanCollide = false -- é só o brilho; não pode barrar quem entra
	end
	setGlow(false)

	local closedCf = hinge.CFrame
	local tweenOpen = TweenService:Create(hinge, DOOR_TWEEN, { CFrame = closedCf * CFrame.Angles(0, DOOR_OPEN_ANGLE, 0) })
	local tweenClose = TweenService:Create(hinge, DOOR_TWEEN, { CFrame = closedCf })
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { exterior }

	local open = false
	local function close()
		if not open then return end
		open = false
		tweenClose:Play()
	end
	tweenClose.Completed:Connect(function()
		if not open then setGlow(false) end
	end)

	detector.Touched:Connect(function(hit)
		if open or not Players:GetPlayerFromCharacter(hit.Parent) then return end
		open = true
		setGlow(true)
		tweenOpen:Play()
		-- Fecha quando o último jogador sair do Detector (TouchEnded falha com vários membros)
		task.spawn(function()
			while open and detector.Parent do
				task.wait(DOOR_CHECK_INTERVAL)
				if open and not hasPlayerInside(detector, params) then close() end
			end
		end)
	end)

	local closeConn = fecharPortaEvent.Event:Connect(close)
	exterior.Destroying:Connect(function()
		open = false
		closeConn:Disconnect()
	end)
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
	prompt.Style = Enum.ProximityPromptStyle.Custom -- visual do jogo (PromptController no cliente)
	prompt.Parent = marker

	prompt.Triggered:Connect(function(who)
		if who == player then
			HouseService.ExitHouse(player)
		end
	end)
end

-- Guarda-roupa: prompt "Trocar sabor" no wardrobe/Click (mesmo visual do de sair, no lugar
-- do antigo botão flutuante) que abre a seleção de personagem
local function setupWardrobePrompt(player, interior)
	local wardrobe = interior:FindFirstChild("wardrobe")
	local marker = wardrobe and wardrobe:FindFirstChild("Click")
	if not marker or not marker:IsA("BasePart") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrocarSaborPrompt"
	prompt:SetAttribute("Som", "PopSound") -- tocado no cliente pelo PromptController
	prompt.ActionText = "Trocar sabor"
	prompt.ObjectText = "Guarda-roupa"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom -- visual do jogo (PromptController no cliente)
	prompt.Parent = marker

	prompt.Triggered:Connect(function(who)
		if who == player then
			showSelectionEvent:FireClient(player)
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

local function buildHouse(player, state, forcedName)
	local equipped = forcedName or InventoryService.GetEquipped(player, "House")
	local houseName = (equipped and HOUSES[equipped]) and equipped or ItemCatalog.StarterHouse
	local config = HOUSES[houseName]
	local spawnPart = state.spawnPart

	-- Interior primeiro (no céu, alinhado à rotação do lote): o CharacterSaveSystem faz o
	-- jogador nascer no primeiro que encontrar, e o interior é o lugar certo para nascer.
	local interiorTemplate = (config.Interior and config.Interior()) or starterInterior
	local interior = interiorTemplate:Clone()
	interior.Name = player.Name .. "_Interior"
	local posicao = Vector3.new(spawnPart.Position.X * MULTIPLICADOR_DISTANCIA, ALTURA_INTERIOR, spawnPart.Position.Z * MULTIPLICADOR_DISTANCIA)
	interior:PivotTo(CFrame.new(posicao) * spawnPart.CFrame.Rotation)
	interior.Parent = interioresFolder
	state.interior = interior -- já no estado: se algo abaixo falhar, o destroyHouse limpa

	local spawnInterior = interior:FindFirstChild("SpawnInterior", true) or interior:FindFirstChildWhichIsA("BasePart", true)
	interior.PrimaryPart = spawnInterior

	-- Exterior
	local exteriorTemplate = config.Exterior() or starterExterior
	local exterior = exteriorTemplate:Clone()
	exterior.Name = player.Name .. "_Exterior"
	state.exterior = exterior
	if exteriorTemplate ~= starterExterior then stripScripts(exterior) end

	if exterior:FindFirstChild("PortaEntrada", true) then
		ensureStarterPrimaryPart(exterior)
		exterior:PivotTo(spawnPart.CFrame) -- casa no padrão inicial: posiciona como sempre
	else
		placeGenericExterior(exterior, spawnPart, config)
	end
	repairDoorWelds(exterior)
	exterior:SetAttribute("OwnerId", player.UserId)
	exterior:SetAttribute("LoteOriginal", state.lote.Name)
	exterior:SetAttribute("Casa", houseName)
	exterior.Parent = casasFolder
	if exteriorTemplate ~= starterExterior then setupAnimatedDoor(exterior) end

	local portaEntrada = exterior:FindFirstChild("PortaEntrada", true)
	local frenteDaCasa = exterior:FindFirstChild("FrenteDaCasa", true)
	if not (portaEntrada and frenteDaCasa and spawnInterior) then
		warn("[HouseService] Casa '" .. houseName .. "' sem PortaEntrada/FrenteDaCasa/SpawnInterior")
	end

	state.exterior, state.interior, state.houseName = exterior, interior, houseName
	state.spawnInterior = spawnInterior and (spawnInterior.CFrame + Vector3.new(0, 3, 0))
	state.focus = spawnInterior
	if frenteDaCasa and portaEntrada then
		local outward = flat(portaEntrada.CFrame.LookVector) or Vector3.new(0, 0, -1)
		local wanted = frenteDaCasa.CFrame + portaEntrada.CFrame.LookVector * 5
		-- Confirma que há chão ali; senão tenta mais perto da porta e, por fim, o centro do lote
		local exitTarget, ground = groundedSpot(wanted.Position, outward, exterior)
		if not exitTarget then exitTarget, ground = groundedSpot(frenteDaCasa.Position, outward, exterior) end
		if not exitTarget then exitTarget, ground = groundedSpot(spawnPart.Position, outward, exterior) end
		state.exitTarget = exitTarget or wanted
		-- Diagnóstico: onde o jogador aparece ao sair (ajuda a achar "saiu dentro do chão")
		print(("[HouseService] Saída de %s: y=%.1f sobre %s"):format(player.Name, state.exitTarget.Position.Y,
			ground and ground:GetFullName() or "nada (sem chão encontrado)"))
	end

	-- Entrar: encostar na PortaEntrada ou no painel "Enter" da porta animada (casas da loja)
	-- dispara a transição de mordida e o teleporte para o interior
	local function onDoorTouched(hit)
		if Players:GetPlayerFromCharacter(hit.Parent) == player then
			enterHouse(player)
		end
	end
	if portaEntrada then
		portaEntrada.Touched:Connect(onDoorTouched)
	end
	local doorModel = exteriorTemplate ~= starterExterior and findAnimatedDoor(exterior)
	local doorPanel = doorModel and doorModel:FindFirstChild("Enter")
	if doorPanel and doorPanel:IsA("BasePart") and doorPanel ~= portaEntrada then
		doorPanel.CanTouch = true
		doorPanel.Touched:Connect(onDoorTouched)
	end
	setupExitPrompt(player, interior)
	setupWardrobePrompt(player, interior)

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

	-- Precisa saber qual casa está equipada. Se demorar, monta a inicial agora (o jogador
	-- nasce nela) e troca pela equipada quando os dados chegarem.
	local dataReady = InventoryService.WaitForData(player, 15)
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

	if not dataReady then
		warn("[HouseService] Inventário de " .. player.Name .. " atrasado; casa inicial montada provisoriamente")
		task.spawn(function()
			if InventoryService.WaitForData(player, 120) and houses[player] == state then
				rebuildIfChanged(player)
			end
		end)
	end
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

local function isAtInteriorHeight(position)
	return position.Y > ALTURA_INTERIOR - 500
end

-- Ponto dentro da caixa do modelo (com margem)
local function isNearModel(model, position, margin)
	local cf, size = model:GetBoundingBox()
	local p = cf:PointToObjectSpace(position)
	local half = size / 2 + Vector3.new(margin, margin, margin)
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

-- Equipou outra casa (ou os dados chegaram depois da montagem): reconstrói e leva para
-- dentro da nova se estava em casa (ou para a frente da porta se estava em cima do lote)
function rebuildIfChanged(player)
	local state = houses[player]
	if not state or not state.exterior then return end
	local equipped = InventoryService.GetEquipped(player, "House")
	local houseName = (equipped and HOUSES[equipped]) and equipped or ItemCatalog.StarterHouse
	if state.houseName == houseName then return end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local wasInside = root ~= nil and (character:GetAttribute("InsideHouse") == true or isAtInteriorHeight(root.Position))
	-- Parado durante a troca: dentro de casa, o chão (interior antigo) some na hora
	if root then root.Anchored = true end

	destroyHouse(state)
	local ok, err = pcall(buildHouse, player, state)
	if not ok then
		warn("[HouseService] Erro ao montar '" .. houseName .. "' para " .. player.Name .. ": " .. tostring(err) .. " — voltando para a casa inicial")
		destroyHouse(state)
		ok, err = pcall(buildHouse, player, state, ItemCatalog.StarterHouse)
		if not ok then warn("[HouseService] Erro ao montar a casa inicial: " .. tostring(err)) end
	end

	local moved = false
	if wasInside and state.spawnInterior then
		moved = TeleportTransition.Instant(player, state.spawnInterior, function(char)
			char:SetAttribute("InsideHouse", true)
			cameraEvent:FireClient(player, "Isometrico", state.focus)
		end)
	elseif root and state.exitTarget and state.exterior and isNearModel(state.exterior, root.Position, 4) then
		-- Do lado de fora em cima do lote: a casa nova (maior) nasceria em volta do jogador
		-- e a física o jogava para cima / para fora do lote. Leva para a frente da porta.
		moved = TeleportTransition.Instant(player, state.exitTarget)
	end
	if not moved and root and root.Parent then root.Anchored = false end
end

InventoryService.EquippedChanged:Connect(function(player, category)
	if category == "House" then rebuildIfChanged(player) end
end)

exitHouseEvent.OnServerEvent:Connect(function(player)
	HouseService.ExitHouse(player)
end)

-- === RESGATE DE LIMBO ===
-- Rede de segurança: quem cair do interior ou do mapa volta para casa em vez de ficar
-- caindo no vazio (troca de casa, streaming atrasado, buraco no mapa...)
local LIMBO_Y = -150     -- abaixo disso, do lado de fora, é queda para fora do mapa
local INTERIOR_FALL = 60 -- dentro de casa: tanto abaixo do piso do interior
task.spawn(function()
	while true do
		task.wait(1)
		for player, state in pairs(houses) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and not root.Anchored and not character:GetAttribute("Teleportando") then
				local y = root.Position.Y
				local inside = character:GetAttribute("InsideHouse") == true
				if inside and state.spawnInterior and y < state.spawnInterior.Y - INTERIOR_FALL then
					warn("[HouseService] " .. player.Name .. " caiu do interior (y=" .. math.floor(y) .. "); voltando ao spawn da casa")
					task.spawn(TeleportTransition.Instant, player, state.spawnInterior, function()
						cameraEvent:FireClient(player, "Isometrico", state.focus)
					end)
				elseif not inside and y < LIMBO_Y and state.exitTarget then
					warn("[HouseService] " .. player.Name .. " caiu do mapa (y=" .. math.floor(y) .. "); voltando para a frente da casa")
					task.spawn(TeleportTransition.Instant, player, state.exitTarget, function(char)
						char:SetAttribute("InsideHouse", false)
						cameraEvent:FireClient(player, "Normal")
					end)
				end
			end
		end
	end
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
