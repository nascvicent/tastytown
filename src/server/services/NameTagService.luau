local NameTagService = {}

-- NameTagService (ModuleScript atualizado)
local DataStoreService = game:GetService("DataStoreService")
local TagStore = DataStoreService:GetDataStore("PlayerTags_v1")

local NameTagService = {}

local DEFAULT_TAG = "Fresh Snack 🥐"

-- Cache local: playerTags[player] = "tag string"
local playerTags = {}

-- Configurações Visuais
local TAG_SETTINGS = {
	Offset = Vector3.new(0, 3.5, 0),
	Size = UDim2.new(4, 0, 1, 0),
	Font = Enum.Font.FredokaOne,
	MaxDistance = 55,
	NameColor = Color3.fromRGB(255, 255, 255),
	TagColor = Color3.fromRGB(255, 223, 150),
	StrokeColor = Color3.fromRGB(80, 50, 20),
}

-- Carrega a tag do DataStore (chamar 1x no PlayerAdded)
function NameTagService.LoadTag(player)
	local success, tag = pcall(function()
		return TagStore:GetAsync(tostring(player.UserId))
	end)

	if success and tag then
		playerTags[player] = tag
	else
		playerTags[player] = DEFAULT_TAG
	end

	return playerTags[player]
end

-- Salva a tag no DataStore (chamar no PlayerRemoving / BindToClose)
function NameTagService.SaveTag(player)
	local tag = playerTags[player]
	if not tag then return end

	local success, err = pcall(function()
		TagStore:SetAsync(tostring(player.UserId), tag)
	end)

	if not success then
		warn("[NameTagService] Falha ao salvar tag de " .. player.Name .. ": " .. tostring(err))
	end
end

-- Muda a tag em runtime (pra uso futuro: GUI, comandos, etc.)
function NameTagService.SetTag(player, newTag)
	playerTags[player] = newTag or DEFAULT_TAG

	-- Atualiza visual se o personagem existir
	local character = player.Character
	if character then
		local headGui = character:FindFirstChild("HeadGui")
		if headGui then
			local container = headGui:FindFirstChild("Frame")
			if container then
				local rankLabel = container:FindFirstChild("PlayerRank")
				if rankLabel then
					rankLabel.Text = playerTags[player]
				end
			end
		end
	end
end

-- Retorna a tag atual do cache
function NameTagService.GetTag(player)
	return playerTags[player] or DEFAULT_TAG
end

-- Limpa o cache (chamar no PlayerRemoving, DEPOIS de salvar)
function NameTagService.Cleanup(player)
	playerTags[player] = nil
end

-- Aplica o nametag visual (usa o cache interno)
function NameTagService.ApplyTag(player, character)
	if character:FindFirstChild("HeadGui") then
		character.HeadGui:Destroy()
	end

	local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not head then return end

	local tag = playerTags[player] or DEFAULT_TAG

	local bb = Instance.new("BillboardGui")
	bb.Name = "HeadGui"
	bb.Adornee = head
	bb.Size = TAG_SETTINGS.Size
	bb.StudsOffset = TAG_SETTINGS.Offset
	bb.AlwaysOnTop = true
	bb.MaxDistance = TAG_SETTINGS.MaxDistance
	bb.Parent = character

	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Parent = bb

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.Font = TAG_SETTINGS.Font
	nameLabel.TextColor3 = TAG_SETTINGS.NameColor
	nameLabel.TextStrokeColor3 = TAG_SETTINGS.StrokeColor
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextScaled = true
	nameLabel.Parent = container

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "PlayerRank"
	titleLabel.Size = UDim2.new(1, 0, 0.4, 0)
	titleLabel.Position = UDim2.new(0, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = tag
	titleLabel.Font = TAG_SETTINGS.Font
	titleLabel.TextColor3 = TAG_SETTINGS.TagColor
	titleLabel.TextStrokeColor3 = TAG_SETTINGS.StrokeColor
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextScaled = true
	titleLabel.Parent = container
end

return NameTagService