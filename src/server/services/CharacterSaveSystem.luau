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
	if respawning[player] then return end
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
			local success, saved = pcall(function() return CharacterStore:GetAsync(tostring(player.UserId)) end)
			spawnCharacter(player, saved or "Default")
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

	if casaInterior and casaInterior:FindFirstChild("SpawnInterior") then
		player:RequestStreamAroundAsync(casaInterior.SpawnInterior.Position)
		spawnLocation = casaInterior.SpawnInterior.CFrame + Vector3.new(0, 3, 0)
	elseif casaExterior then
		if casaExterior.PrimaryPart then player:RequestStreamAroundAsync(casaExterior.PrimaryPart.Position) end
		local spawnPoint = casaExterior:FindFirstChild("PortaEntrada") or casaExterior.PrimaryPart
		if spawnPoint then spawnLocation = spawnPoint.CFrame * CFrame.new(0, 3, -5) end
	else
		if spawnPadrao then player:RequestStreamAroundAsync(spawnPadrao.Position) end
	end

	clone:PivotTo(spawnLocation)
	clone.Parent = workspace
	player.Character = clone

	local hrp = clone:WaitForChild("HumanoidRootPart", 5)
	if hrp then hrp.CFrame = spawnLocation end
	if oldChar and oldChar ~= clone and oldChar.Parent then oldChar:Destroy() end

	-- === APLICAR NAMETAG ===
	NameTagService.ApplyTag(player, clone)
	-- =======================

	task.delay(1, function() respawning[player] = nil end)
	PlayerLoadedEvent:FireClient(player)
end

function CharacterSaveSystem.Start()
	Players.PlayerAdded:Connect(function(player)
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
	end)

	CharacterChosenEvent.OnServerEvent:Connect(function(player, characterName)
		if CharactersFolder:FindFirstChild(characterName) then
			pcall(function()
				CharacterStore:SetAsync(tostring(player.UserId), characterName)
			end)
			spawnCharacter(player, characterName)
		else
			warn(player.Name .. " tentou escolher um personagem inválido: " .. tostring(characterName))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
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