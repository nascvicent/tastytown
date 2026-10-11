local HouseService = {}

-- === SERVIÇOS ===
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local playerDataStore = DataStoreService:GetDataStore("CasaPlayerData")

-- === EVENTOS ===
local EventsFolder = ReplicatedStorage:WaitForChild("Events")
local cameraEvent = EventsFolder:WaitForChild("SetCameraMode")
local cameraSyncEvent = EventsFolder:WaitForChild("CameraSyncRequest")

-- === REFERÊNCIAS ===
local casasFolder = workspace:WaitForChild("Casas")
local interioresFolder = workspace:WaitForChild("Interiores")
local lotesFolder = workspace:WaitForChild("Lotes")

local exteriorTemplate = ServerStorage:WaitForChild("CasaExterior")
local interiorTemplate = ServerStorage:WaitForChild("CasaInterior")

-- === CONFIGURAÇÕES ===
local ALTURA_INTERIOR = 5000
local MULTIPLICADOR_DISTANCIA = 12

-- Defina aqui o nome exato da Part dentro do Model onde a casa deve spawnar.
-- Se a part não tiver nome específico, deixe como nil e o script tentará achar automaticamente.
local NOME_PART_SPAWN = "Base" 

local lotesOcupados = {}

-- === FUNÇÕES AUXILIARES ===

-- Função para encontrar a Part de Spawn e o Union dentro do Model do Lote
local function getPartesDoLote(loteModel)
	local spawnPart = nil
	local limiteUnion = nil

	-- Tenta achar pelo nome configurado
	if NOME_PART_SPAWN then
		spawnPart = loteModel:FindFirstChild(NOME_PART_SPAWN)
	end

	-- Se não achou pelo nome (ou não tem nome), procura a primeira Part que NÃO é Union
	if not spawnPart then
		for _, child in ipairs(loteModel:GetChildren()) do
			if child:IsA("BasePart") and not child:IsA("UnionOperation") then
				spawnPart = child
				break
			end
		end
	end

	-- Procura o Union (Limites)
	limiteUnion = loteModel:FindFirstChildWhichIsA("UnionOperation")

	return spawnPart, limiteUnion
end

local function getLoteLivre()
	-- Itera pelos Models dentro da pasta Lotes
	for _, lote in ipairs(lotesFolder:GetChildren()) do
		if not lotesOcupados[lote] then
			return lote -- Retorna o Model do lote
		end
	end
	return nil
end

-- === LÓGICA DE TELEPORTE (MANTIDA IGUAL) ===
local function realizarTeleporte(player, destinoCFrame, modoCamera, focoCamera, localizacaoLoading)
	local char = player.Character
	if not char then return end

	if char:GetAttribute("Teleportando") then return end
	char:SetAttribute("Teleportando", true)

	pcall(function()
		player:RequestStreamAroundAsync(localizacaoLoading)
	end)

	char:PivotTo(destinoCFrame)
	task.wait(0.1)

	if modoCamera == "Isometrico" then
		char:SetAttribute("InsideHouse", true)
		cameraEvent:FireClient(player, "Isometrico", focoCamera)
		task.delay(0.2, function()
			if player.Parent then cameraEvent:FireClient(player, "Isometrico", focoCamera) end
		end)
	else
		char:SetAttribute("InsideHouse", false)
		cameraEvent:FireClient(player, "Normal")
		task.delay(0.2, function()
			if player.Parent then cameraEvent:FireClient(player, "Normal") end
		end)
	end

	task.wait(1)
	char:SetAttribute("Teleportando", false)
end

local function configurarTeleporte(player, exterior, interior)
	local portaEntrada = exterior:WaitForChild("PortaEntrada", 5)
	local portaSaida = interior:WaitForChild("PortaSaida", 5)
	local spawnInterior = interior:WaitForChild("SpawnInterior", 5)
	local frenteDaCasa = exterior:WaitForChild("FrenteDaCasa", 5)

	if not (portaEntrada and portaSaida and spawnInterior and frenteDaCasa) then
		warn("CRÍTICO: Faltam partes na casa de " .. player.Name)
		return
	end

	if not interior.PrimaryPart then
		interior.PrimaryPart = spawnInterior
	end

	local function conectarGatilho(partGatilho, destinoCFrame, modoCam, foco, posLoading)
		partGatilho.Touched:Connect(function(hit)
			local char = hit.Parent
			local plr = Players:GetPlayerFromCharacter(char)
			if plr then
				realizarTeleporte(plr, destinoCFrame, modoCam, foco, posLoading)
			end
		end)
	end

	local destinoEntrada = spawnInterior.CFrame + Vector3.new(0, 3, 0)
	conectarGatilho(portaEntrada, destinoEntrada, "Isometrico", interior.PrimaryPart, destinoEntrada.Position)

	local destinoSaida = frenteDaCasa.CFrame + (portaEntrada.CFrame.LookVector * 5)
	conectarGatilho(portaSaida, destinoSaida, "Normal", nil, destinoSaida.Position)
end

-- === CICLO DE VIDA DO JOGADOR ===
function HouseService.onPlayerAdded(player)
	local loteModel = getLoteLivre()

	if not loteModel then
		warn("Servidor cheio! Nenhum lote disponível.")
		return
	end

	-- Pega as referências dentro do Model do Lote
	local spawnPart, limiteUnion = getPartesDoLote(loteModel)

	if not spawnPart then
		warn("ERRO CRÍTICO: O Lote " .. loteModel.Name .. " não tem uma Part válida para spawnar a casa.")
		return
	end

	lotesOcupados[loteModel] = player

	pcall(function()
		playerDataStore:GetAsync(player.UserId)
	end)

	if not player.Parent then
		lotesOcupados[loteModel] = nil
		return
	end

	-- 1. Spawnar Exterior
	local exterior = exteriorTemplate:Clone()
	exterior.Name = player.Name .. "_Exterior"
	exterior:PivotTo(spawnPart.CFrame) -- Usa o CFrame da Part interna, não do Model
	exterior.Parent = casasFolder

	-- 2. Alterar o visual do Union (Limites)
	if limiteUnion then
		limiteUnion.Transparency = 1
		limiteUnion.CanCollide = false -- Opcional: Desativa colisão se necessário
	end

	-- 3. Spawnar Interior
	local interior = interiorTemplate:Clone()
	interior.Name = player.Name .. "_Interior"
	interior.Parent = interioresFolder

	-- Cálculo da posição baseado na Part interna para manter consistência
	local posX = spawnPart.Position.X * MULTIPLICADOR_DISTANCIA
	local posZ = spawnPart.Position.Z * MULTIPLICADOR_DISTANCIA

	local novaPosicao = Vector3.new(posX, ALTURA_INTERIOR, posZ)
	local posicaoCeu = CFrame.new(novaPosicao) * spawnPart.CFrame.Rotation
	interior:PivotTo(posicaoCeu)

	local spawnInterior = interior:FindFirstChild("SpawnInterior") or interior:FindFirstChildWhichIsA("BasePart")
	if spawnInterior then
		interior.PrimaryPart = spawnInterior
	end

	-- Salva atributos importantes
	exterior:SetAttribute("OwnerId", player.UserId)
	exterior:SetAttribute("LoteOriginal", loteModel.Name)

	configurarTeleporte(player, exterior, interior)
	print("Casa configurada para:", player.Name, "no", loteModel.Name)
end

function HouseService.onPlayerRemoving(player)
	local exterior = casasFolder:FindFirstChild(player.Name .. "_Exterior")
	local interior = interioresFolder:FindFirstChild(player.Name .. "_Interior")

	if exterior then
		local nomeLote = exterior:GetAttribute("LoteOriginal")

		if nomeLote then
			local loteModel = lotesFolder:FindFirstChild(nomeLote)

			if loteModel then
				-- Libera o lote na tabela lógica
				lotesOcupados[loteModel] = nil

				-- Restaura o Union (Limites) para ficar visível novamente
				local _, limiteUnion = getPartesDoLote(loteModel)
				if limiteUnion then
					limiteUnion.Transparency = 0 -- Ou o valor original (ex: 0.5)
					limiteUnion.CanCollide = true -- Se você desativou antes
				end
			end
		end
		exterior:Destroy()
	end

	if interior then
		interior:Destroy()
	end
end

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