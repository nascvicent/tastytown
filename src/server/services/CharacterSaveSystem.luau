local CharacterSaveSystem = {}

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterStore = DataStoreService:GetDataStore("PlayerCharacterChoice")
local CharactersFolder = ReplicatedStorage:WaitForChild("Characters")

local ShowSelectionEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ShowCharacterSelection")
local CharacterChosenEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("CharacterChosen")

local function spawnCharacter(player, characterName)
	local model = CharactersFolder:FindFirstChild(characterName)
	if model then
		
		local clone = model:Clone()
		clone.Name = player.Name
		clone.Parent = workspace
		player.Character = clone

		
		task.wait(0.1)


			local humanoid = clone:FindFirstChildWhichIsA("Humanoid")
		if humanoid and not humanoid:FindFirstChild("Animator") then
			Instance.new("Animator", humanoid)
		end

		local animate = clone:FindFirstChild("Animate")
		if animate and animate:IsA("LocalScript") then
			animate.Disabled = true
			task.delay(0.5, function()
				animate.Disabled = false
			end)
		else
			warn("Animate não encontrado ou não é LocalScript no personagem:", characterName)
		end
	

		if clone.PrimaryPart then
			local nomeCasa = player.Name .. "_Casa"
			local casasFolder = workspace:WaitForChild("Casas")
			local casaDoPlayer = casasFolder:FindFirstChild(nomeCasa)
			if casaDoPlayer then
				local spawn = casaDoPlayer:FindFirstChild("Spawn")
				if spawn then
					local spawnCFrame

					if spawn:IsA("BasePart") then
						spawnCFrame = spawn.CFrame
					elseif spawn.PrimaryPart then
						spawnCFrame = spawn.PrimaryPart.CFrame
					else
						warn("Spawn não possui PrimaryPart nem é BasePart para " .. nomeCasa)
						spawnCFrame = CFrame.new(0, 10, 0) -- fallback
					end

					clone:SetPrimaryPartCFrame(spawnCFrame)
					
				else
					warn("Spawn não encontrado em " .. nomeCasa)
				end
			else
				warn("Casa do jogador não encontrada: " .. nomeCasa)
			end
		else
			warn("PrimaryPart não definida no modelo " .. characterName)
		end
	else
		warn("Modelo de personagem não encontrado: " .. characterName)
	end
end

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
