local CharacterSaveSystem = {}

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterStore = DataStoreService:GetDataStore("PlayerCharacterChoice")
local CharactersFolder = ReplicatedStorage:WaitForChild("Characters")

local ShowSelectionEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SelectionEvents"):WaitForChild("ShowCharacterSelection")
local CharacterChosenEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SelectionEvents"):WaitForChild("CharacterChosen")
local RequestSelection = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SelectionEvents"):WaitForChild("RequestCharacterSelection")

local respawning = {}

RequestSelection.OnServerEvent:Connect(function(player)
	print("chamou evento de trocar pelo armario")
	ShowSelectionEvent:FireClient(player)
end)

local function addCustomNameTag(character, player, subtitleText)
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	local partToAttach = head or root or character.PrimaryPart
	if not partToAttach then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CustomNameTag"
	billboard.Adornee = partToAttach
	billboard.Size = UDim2.new(0, 160, 0, 50)
	billboard.StudsOffset = Vector3.new(0, partToAttach == root and 3.5 or 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = character

	-- Container invisível
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = billboard

	-- Nome do jogador
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Font = Enum.Font.FredokaOne

	-- Ajuste de tamanho da fonte baseado no comprimento
	local length = string.len(player.Name)
	if length <= 8 then
		nameLabel.TextScaled = false
		nameLabel.TextSize = 22
	elseif length <= 12 then
		nameLabel.TextScaled = false
		nameLabel.TextSize = 18
	else
		nameLabel.TextScaled = false
		nameLabel.TextSize = 14
	end

	nameLabel.Parent = frame

	-- Subtítulo opcional (ex: classe do jogador)
	if subtitleText then
		local subtitle = Instance.new("TextLabel")
		subtitle.Size = UDim2.new(1, 0, 0.4, 0)
		subtitle.Position = UDim2.new(0, 0, 0.6, 0)
		subtitle.BackgroundTransparency = 1
		subtitle.Text = subtitleText
		subtitle.TextColor3 = Color3.fromRGB(200, 200, 255)
		subtitle.TextStrokeTransparency = 0.5
		subtitle.Font = Enum.Font.FredokaOne
		subtitle.TextScaled = true
		subtitle.Parent = frame
		
	end
end


-- Função para spawnar personagem
local function spawnCharacter(player, characterName)
	if respawning[player] then return end
	respawning[player] = true

	local model = CharactersFolder:FindFirstChild(characterName)
	if model then
		local clone = model:Clone()
		clone.Name = player.Name
		clone.Parent = workspace

		-- Definir PrimaryPart se não tiver
		if not clone.PrimaryPart then
			local root = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChildWhichIsA("BasePart")
			if root then
				clone.PrimaryPart = root
			else
				warn("Sem PrimaryPart válida para o personagem:", characterName)
			end
		end

		-- Mover para casa do jogador (se existir)
		local nomeCasa = player.Name .. "_Casa"
		local casasFolder = workspace:FindFirstChild("Casas")
		if casasFolder then
			local casaDoPlayer = casasFolder:FindFirstChild(nomeCasa)
			if casaDoPlayer then
				local spawn = casaDoPlayer:FindFirstChild("Spawn")
				if spawn then
					local spawnCFrame = spawn:IsA("BasePart") and spawn.CFrame
						or spawn.PrimaryPart and spawn.PrimaryPart.CFrame
						or CFrame.new(0, 10, 0)

					clone:SetPrimaryPartCFrame(spawnCFrame)
				end
			end
		end

		-- Adicionar Animator e corrigir script de animação
		local humanoid = clone:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			if not humanoid:FindFirstChild("Animator") then
				Instance.new("Animator", humanoid)
			end
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end

		local animate = clone:FindFirstChild("Animate")
		if animate and animate:IsA("LocalScript") then
			animate.Disabled = true
			task.delay(0.5, function()
				if animate then
					animate.Disabled = false
				end
			end)
		end

		-- Definir personagem do jogador (evitar conflito com CharacterAdded)
		task.defer(function()
			if player and player.Parent then
				player.Character = clone
			end
		end)

		-- Nome personalizado
		addCustomNameTag(clone, player, "CREATOR")
	else
		warn("Modelo de personagem não encontrado: " .. characterName)
	end

	-- Liberar debounce
	task.delay(1, function()
		respawning[player] = nil
	end)
end

-- Inicialização
function CharacterSaveSystem.Start()
	Players.PlayerAdded:Connect(function(player)
		local success, savedCharacter = pcall(function()
			return CharacterStore:GetAsync(player.UserId)
		end)

		if success and savedCharacter then
			spawnCharacter(player, savedCharacter)
		else
			ShowSelectionEvent:FireClient(player)
		end

		player.CharacterAdded:Connect(function()
			local success, savedCharacter = pcall(function()
				return CharacterStore:GetAsync(player.UserId)
			end)
			if success and savedCharacter then
				task.delay(0.1, function()
					spawnCharacter(player, savedCharacter)
				end)
			end
		end)
	end)

	CharacterChosenEvent.OnServerEvent:Connect(function(player, characterName)
		pcall(function()
			CharacterStore:SetAsync(player.UserId, characterName)
		end)
		spawnCharacter(player, characterName)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if player.Character and player.Character.Name then
			pcall(function()
				CharacterStore:SetAsync(player.UserId, player.Character.Name)
			end)
		end
	end)
end

return CharacterSaveSystem
