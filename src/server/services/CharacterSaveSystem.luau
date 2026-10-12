local CharacterSaveSystem = {}

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- -- IMPORTANDO O NOVO MÓDULO --
local NameTagService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("services"):WaitForChild("NameTagService"))
-- ------------------------------

local CharacterStore = DataStoreService:GetDataStore("PlayerCharacterChoice")
local CharactersFolder = ReplicatedStorage:WaitForChild("Characters")

local ShowSelectionEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SelectionEvents"):WaitForChild("ShowCharacterSelection")
local CharacterChosenEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SelectionEvents"):WaitForChild("CharacterChosen")
local RequestSelection = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SelectionEvents"):WaitForChild("RequestCharacterSelection")
local PlayerLoadedEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ScreenEvents"):WaitForChild("PlayerLoaded")

local respawning = {}
local escolhaPendente = {} -- escolha feita enquanto um spawn ainda estava em andamento
Players.CharacterAutoLoads = false

-- Atributo "Spawning" no Player: o servidor ainda está preparando o personagem (lendo o
-- DataStore ou esperando a casa). O anti-limbo do cliente espera enquanto ele existir.
local function setSpawning(player, value)
	if player.Parent then player:SetAttribute("Spawning", value or nil) end
end

RequestSelection.OnServerEvent:Connect(function(player)
	-- Spawn em andamento: abrir a seleção agora só criaria uma escolha pendente
	if respawning[player] then return end
	setSpawning(player, false)
	ShowSelectionEvent:FireClient(player)
end)

-- RequestStreamAroundAsync pode falhar; sem pcall o erro deixava o spawn travado
local function streamAround(player, position)
	local ok, err = pcall(player.RequestStreamAroundAsync, player, position)
	if not ok then warn("RequestStreamAroundAsync falhou para " .. player.Name .. ": " .. tostring(err)) end
end

-- Funções auxiliares de Casa
local function encontrarCasaExterior(player)
	local casasFolder = workspace:FindFirstChild("Casas")
	if not casasFolder then return nil end
	local nomePadrao = player.Name .. "_Exterior"
	local casa = casasFolder:FindFirstChild(nomePadrao)
	if casa then return casa end
	for _, modelo in pairs(casasFolder:GetChildren()) do
		local ownerVal = modelo:FindFirstChild("Owner") or modelo:GetAttribute("Owner")
		if (typeof(ownerVal) == "Instance" and ownerVal.Value == player.Name) or
			(typeof(ownerVal) == "string" and ownerVal == player.Name) then
			return modelo
		end
	end
	return nil
end

local function encontrarCasaInterior(player)
	local interioresFolder = workspace:FindFirstChild("Interiores")
	if not interioresFolder then return nil end
	return interioresFolder:FindFirstChild(player.Name .. "_Interior")
end

local spawnCharacter

local function doSpawn(player, characterName)
	local oldChar = player.Character

	-- Validação
	local model = CharactersFolder:FindFirstChild(characterName)
	if not model then
		respawning[player] = nil
		setSpawning(player, false)
		ShowSelectionEvent:FireClient(player)
		PlayerLoadedEvent:FireClient(player)
		return
	end

	local clone = model:Clone()
	clone:SetAttribute("CharacterModel", characterName)
	clone.Name = player.Name

	local humanoid = clone:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		if not humanoid:FindFirstChild("Animator") then Instance.new("Animator", humanoid) end
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.Died:Connect(function()
			task.wait(3)
			-- Renasce com o mesmo personagem (sem consultar o DataStore a cada morte)
			if player.Parent and player.Character == clone then
				spawnCharacter(player, characterName)
			end
		end)
	end

	if not clone.PrimaryPart then
		local root = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChildWhichIsA("BasePart")
		if root then clone.PrimaryPart = root end
	end

	-- Lógica de Spawn
	local spawnLocation = CFrame.new(0, 10, 0)
	local spawnPadrao = workspace:FindFirstChild("SpawnLocation")
	if spawnPadrao then spawnLocation = spawnPadrao.CFrame + Vector3.new(0, 5, 0) end

	local casaExterior = nil
	local casaInterior = nil
	local start = tick()

	repeat
		if not casaExterior then casaExterior = encontrarCasaExterior(player) end
		if not casaInterior then casaInterior = encontrarCasaInterior(player) end
		if not (casaExterior or casaInterior) then task.wait(0.5) end
	until (casaExterior or casaInterior) or (tick() - start > 10)

	-- O jogador pode ter saído durante a espera pela casa
	if not player.Parent then
		clone:Destroy()
		respawning[player] = nil
		escolhaPendente[player] = nil
		return
	end

	local nasceuDentroDeCasa = false
	if casaInterior and casaInterior:FindFirstChild("SpawnInterior") then
		streamAround(player, casaInterior.SpawnInterior.Position)
		spawnLocation = casaInterior.SpawnInterior.CFrame + Vector3.new(0, 3, 0)
		nasceuDentroDeCasa = true
	elseif casaExterior then
		if casaExterior.PrimaryPart then streamAround(player, casaExterior.PrimaryPart.Position) end
		local spawnPoint = casaExterior:FindFirstChild("PortaEntrada") or casaExterior.PrimaryPart
		if spawnPoint then spawnLocation = spawnPoint.CFrame * CFrame.new(0, 3, -5) end
	else
		if spawnPadrao then streamAround(player, spawnPadrao.Position) end
	end

	-- O jogador pode ter saído durante o streaming
	if not player.Parent then
		clone:Destroy()
		respawning[player] = nil
		escolhaPendente[player] = nil
		return
	end

	-- Mantém o handshake de câmera do HouseService coerente com onde o jogador nasceu
	clone:SetAttribute("InsideHouse", nasceuDentroDeCasa)

	clone:PivotTo(spawnLocation)
	clone.Parent = workspace
	player.Character = clone

	local hrp = clone:WaitForChild("HumanoidRootPart", 5)
	if hrp then hrp.CFrame = spawnLocation end
	if oldChar and oldChar ~= clone and oldChar.Parent then oldChar:Destroy() end

	-- === APLICAR NAMETAG ===
	NameTagService.ApplyTag(player, clone)
	-- =======================

	setSpawning(player, false)
	task.delay(1, function()
		respawning[player] = nil
		local pendente = escolhaPendente[player]
		escolhaPendente[player] = nil
		if pendente and pendente ~= characterName then
			spawnCharacter(player, pendente)
		end
	end)
	PlayerLoadedEvent:FireClient(player)
end

function spawnCharacter(player, characterName)
	if not player.Parent then return end
	if respawning[player] then
		-- Em vez de descartar, guarda a escolha e aplica quando o spawn atual terminar
		escolhaPendente[player] = characterName
		return
	end
	respawning[player] = true
	setSpawning(player, true)

	-- Qualquer erro no meio do spawn deixava respawning preso e o jogador no limbo para sempre
	local ok, err = pcall(doSpawn, player, characterName)
	if not ok then
		warn("Erro ao spawnar " .. tostring(characterName) .. " para " .. player.Name .. ": " .. tostring(err))
		respawning[player] = nil
		escolhaPendente[player] = nil
		setSpawning(player, false)
		if not player.Parent then return end
		local char = player.Character
		if not (char and char.Parent and char:FindFirstChild("HumanoidRootPart")) then
			ShowSelectionEvent:FireClient(player)
		end
		PlayerLoadedEvent:FireClient(player)
	end
end

local jogadoresIniciados = {}

local function onPlayerAdded(player)
	if jogadoresIniciados[player] then return end
	jogadoresIniciados[player] = true

	setSpawning(player, true)
	NameTagService.LoadTag(player)
	local success, savedCharacter
	for attempt = 1, 3 do
		success, savedCharacter = pcall(function()
			return CharacterStore:GetAsync(tostring(player.UserId))
		end)
		if success or not player.Parent then break end
		warn("Falha ao ler o personagem de " .. player.Name .. " (tentativa " .. attempt .. "): " .. tostring(savedCharacter))
		task.wait(attempt)
	end
	if not player.Parent then return end

	if success and savedCharacter and typeof(savedCharacter) == "string" then
		print(player.Name .. " tem dados salvos: " .. savedCharacter)
		spawnCharacter(player, savedCharacter)
	else
		if not success then
			warn("Falha ao carregar DataStore para " .. player.Name)
		elseif not savedCharacter then
			print(player.Name .. " é novo ou teve dados apagados.")
		end

		setSpawning(player, false)
		ShowSelectionEvent:FireClient(player)
	end
end

function CharacterSaveSystem.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)

	-- Jogadores que entraram antes do PlayerAdded ser conectado (comum no Play do Studio)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	CharacterChosenEvent.OnServerEvent:Connect(function(player, characterName)
		if typeof(characterName) == "string" and CharactersFolder:FindFirstChild(characterName) then
			pcall(function()
				CharacterStore:SetAsync(tostring(player.UserId), characterName)
			end)
			spawnCharacter(player, characterName)
		else
			warn(player.Name .. " tentou escolher um personagem inválido: " .. tostring(characterName))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		jogadoresIniciados[player] = nil
		respawning[player] = nil
		escolhaPendente[player] = nil

		local character = player.Character
		if character then
			NameTagService.SaveTag(player)
			NameTagService.Cleanup(player)
			local modelName = character:GetAttribute("CharacterModel")
			if modelName and CharactersFolder:FindFirstChild(modelName) then
				pcall(function()
					CharacterStore:SetAsync(tostring(player.UserId), modelName)
				end)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			NameTagService.SaveTag(player)
			local character = player.Character
			if character then
				local modelName = character:GetAttribute("CharacterModel")
				if modelName and CharactersFolder:FindFirstChild(modelName) then
					pcall(function()
						CharacterStore:SetAsync(tostring(player.UserId), modelName)
					end)
				end
			end
		end
	end)
end

return CharacterSaveSystem