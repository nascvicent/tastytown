local HouseService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local playerDataStore = DataStoreService:GetDataStore("CasaPlayerData")
local usedIndicesStore = DataStoreService:GetDataStore("UsedIndices")

local DISTANCIA_ENTRE_CASAS = 700
local casasFolder = workspace:WaitForChild("Casas")
local casaTemplate = game.ServerStorage:WaitForChild("CasaBase")

local function getNextAvailableIndex()
	local reservedIndex = nil

	local success, err = pcall(function()
		usedIndicesStore:UpdateAsync("Indices", function(current)
			current = current or {}
			local index = 1
			while current[tostring(index)] do
				index += 1
			end
			current[tostring(index)] = true
			reservedIndex = index
			return current
		end)
	end)

	if success and reservedIndex then
		return reservedIndex
	else
		warn("Erro ao reservar índice:", err)
		return nil
	end
end

local function criarCasaParaJogador(player, playerData)
	local casa = casaTemplate:Clone()
	casa.Name = player.Name .. "_Casa"
	casa:SetPrimaryPartCFrame(CFrame.new(playerData.PosIndex * DISTANCIA_ENTRE_CASAS, 0, 0))
	casa.Parent = casasFolder

	local function teleport()
		local spawn = casa:WaitForChild("Spawn")
		local character = player.Character or player.CharacterAdded:Wait()
		local hrp = character:WaitForChild("HumanoidRootPart")
		hrp.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	end

	if player.Character then
		teleport()
	else
		player.CharacterAdded:Connect(teleport)
	end
end

function HouseService.onPlayerAdded(player)
	local playerData
	local success = pcall(function()
		playerData = playerDataStore:GetAsync(player.UserId)
	end)

	if not success then
		warn("Erro ao carregar dados do jogador:", player.Name)
		return
	end

	if not playerData then
		local index = getNextAvailableIndex()
		if not index then
			warn("Não foi possível atribuir índice ao jogador", player.Name)
			return
		end

		playerData = {
			PosIndex = index,
			Piso = "Padrao",
			Parede = "Padrao",
			Fundo = "Padrao",
		}

		pcall(function()
			playerDataStore:SetAsync(player.UserId, playerData)
		end)
	end

	criarCasaParaJogador(player, playerData)
end

function HouseService.onPlayerRemoving(player)
	local casa = casasFolder:FindFirstChild(player.Name .. "_Casa")
	if casa then
		casa:Destroy()
	end
end

return HouseService
