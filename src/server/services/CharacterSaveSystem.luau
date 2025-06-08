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
Players.CharacterAutoLoads = false

RequestSelection.OnServerEvent:Connect(function(player)
    print("Chamou evento de trocar pelo armário")
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

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = billboard

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.Font = Enum.Font.FredokaOne
    
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

    if player.Character then
        player.Character:Destroy()
    end

    local model = CharactersFolder:FindFirstChild(characterName)
    if not model then
        warn("Modelo de personagem não encontrado: " .. tostring(characterName))
        ShowSelectionEvent:FireClient(player)
        respawning[player] = nil
        return
    end
    
    local clone = model:Clone()
    clone.Name = player.Name
    
    local humanoid = clone:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        if not humanoid:FindFirstChild("Animator") then
            Instance.new("Animator", humanoid)
        end
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

        humanoid.Died:Connect(function()
            task.wait(3)
            local success, savedCharacter = pcall(function()
                return CharacterStore:GetAsync(tostring(player.UserId))
            end)
            if success and savedCharacter then
                spawnCharacter(player, savedCharacter)
            else
                ShowSelectionEvent:FireClient(player)
            end
        end)
    end

    if not clone.PrimaryPart then
        local root = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChildWhichIsA("BasePart")
        if root then
            clone.PrimaryPart = root
        else
            warn("Sem PrimaryPart válida para o personagem:", characterName)
        end
    end

    local nomeCasa = player.Name .. "_Casa"
    local casasFolder = workspace:FindFirstChild("Casas")
    local spawnLocation = CFrame.new(0, 10, 0)
    if casasFolder then
        local casaDoPlayer = casasFolder:FindFirstChild(nomeCasa)
        if casaDoPlayer then
            local spawnPoint = casaDoPlayer:FindFirstChild("Spawn")
            if spawnPoint and spawnPoint:IsA("BasePart") then
                spawnLocation = spawnPoint.CFrame
            end
        end
    end
    clone:SetPrimaryPartCFrame(spawnLocation)

    clone.Parent = workspace
    player.Character = clone

    addCustomNameTag(clone, player, "CREATOR")

    task.delay(1, function()
        respawning[player] = nil
    end)
end

function CharacterSaveSystem.Start()
    Players.PlayerAdded:Connect(function(player)
        -- 1. Tenta carregar os dados do jogador
        local success, savedCharacter = pcall(function()
            return CharacterStore:GetAsync(tostring(player.UserId))
        end)

        -- 2. Decide o que fazer com base nos dados
        if success and savedCharacter then
            -- Se tinha dados, cria o personagem
            spawnCharacter(player, savedCharacter)
        else
            -- Se não tinha dados (ou deu erro), mostra a tela de seleção
            if not success then
                warn("Erro ao carregar dados do jogador:", savedCharacter)
            end
            ShowSelectionEvent:FireClient(player)
        end

    end)

    CharacterChosenEvent.OnServerEvent:Connect(function(player, characterName)
        pcall(function()
            CharacterStore:SetAsync(tostring(player.UserId), characterName)
        end)
        spawnCharacter(player, characterName)
    end)

    Players.PlayerRemoving:Connect(function(player)
        -- Este bloco continua útil como uma segurança final para salvar os dados.
        if player.Character then
            local modelInFolder = CharactersFolder:FindFirstChild(player.Character.Name)
            if modelInFolder then
                 pcall(function()
                    CharacterStore:SetAsync(tostring(player.UserId), player.Character.Name)
                end)
            end
        end
    end)
end

return CharacterSaveSystem