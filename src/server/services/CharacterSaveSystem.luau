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

RequestSelection.OnServerEvent:Connect(function(player)
	ShowSelectionEvent:FireClient(player)
end)

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

local function spawnCharacter(player, characterName)
	if not player.Parent then return end
	if respawning[player] then
		-- Em vez de descartar, guarda a escolha e aplica quando o spawn atual terminar
		escolhaPendente[player] = characterName
		return
	end
	respawning[player] = true

	local oldChar = player.Character

	-- Validação
	local model = CharactersFolder:FindFirstChild(characterName)
	if not model then
		ShowSelectionEvent:FireClient(player)
		respawning[player] = nil
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
		player:RequestStreamAroundAsync(casaInterior.SpawnInterior.Position)
		spawnLocation = casaInterior.SpawnInterior.CFrame + Vector3.new(0, 3, 0)
		nasceuDentroDeCasa = true
	elseif casaExterior then
		if casaExterior.PrimaryPart then player:RequestStreamAroundAsync(casaExterior.PrimaryPart.Position) end
		local spawnPoint = casaExterior:FindFirstChild("PortaEntrada") or casaExterior.PrimaryPart
		if spawnPoint then spawnLocation = spawnPoint.CFrame * CFrame.new(0, 3, -5) end
	else
		if spawnPadrao then player:RequestStreamAroundAsync(spawnPadrao.Position) end
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

local jogadoresIniciados = {}

local function onPlayerAdded(player)
	if jogadoresIniciados[player] then return end
	jogadoresIniciados[player] = true

	NameTagService.LoadTag(player)
	local success, savedCharacter = pcall(function()
		return CharacterStore:GetAsync(tostring(player.UserId))
	end)

	if success and savedCharacter and typeof(savedCharacter) == "string" then
		print(player.Name .. " tem dados salvos: " .. savedCharacter)
		spawnCharacter(player, savedCharacter)
	else
		if not success then
			warn("Falha ao carregar DataStore para " .. player.Name)
		elseif not savedCharacter then
			print(player.Name .. " é novo ou teve dados apagados.")
		end

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