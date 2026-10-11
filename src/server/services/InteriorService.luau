--[[
	InteriorService — interiores de prédios (gerados em tools/interiors com o Lune).

	Para cada interior:
	  • clona ServerStorage.Interiors.<Model> para Workspace.InterioresPredios na posição configurada
	  • tocar na porta do prédio (Porta/Entrar) leva para o SpawnInterior
	  • tocar na Saida do interior leva de volta para a frente da porta

	Transição: mesmo fluxo das outras portas do jogo —
	  servidor BiteEffectEvent:FireClient -> cliente anima as mordidas e, com a tela
	  coberta, responde BiteEffectEvent:FireServer -> servidor teleporta e fecha a porta
	  (FecharPortaEvent, BindableEvent escutado pelos scripts das portas).
]]

local InteriorService = {}

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")
local cameraEvent = Events:WaitForChild("SetCameraMode")
local BiteEffectEvent = Events:WaitForChild("ScreenEvents"):WaitForChild("BiteEffectEvent")
local FecharPortaEvent = Events:WaitForChild("FecharPortaEvent")

-- Abaixo de 4000 de altura para o HouseController não ligar a câmera isométrica de casa
local INTERIORS = {
	{
		Name = "CineCorn",
		Model = "CineCornInterior",
		Building = { "Predios", "CineCorn" },
		Position = Vector3.new(0, 2500, -3000),
	},
}

-- A animação de mordida leva ~1,3s para cobrir a tela + ~2,5s para descobrir
local COOLDOWN = 4
-- Se o cliente não responder (ex.: BiteAnim ausente), teleporta mesmo assim
local BITE_TIMEOUT = 3
local lastUse = {}
local pending = {} -- [player] = CFrame de destino aguardando a tela ficar coberta

local function resolve(path)
	local current = workspace
	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function firstPart(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function teleport(player, target)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	if humanoid.SeatPart then
		humanoid.Sit = false
		task.wait(0.15)
	end

	character:SetAttribute("Teleportando", true)
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 3)
	end)
	character:PivotTo(target)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then root.AssemblyLinearVelocity = Vector3.zero end

	-- Garante câmera normal (caso viesse de dentro de casa)
	if character:GetAttribute("InsideHouse") then
		character:SetAttribute("InsideHouse", false)
		cameraEvent:FireClient(player, "Normal")
	end

	task.delay(1, function()
		if character.Parent then character:SetAttribute("Teleportando", false) end
	end)
	FecharPortaEvent:Fire()
end

-- Inicia a transição de mordida; o teleporte acontece quando o cliente avisa que cobriu a tela
local function requestTeleport(player, target)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Teleportando") then return end
	if pending[player] then return end

	local now = os.clock()
	if lastUse[player] and now - lastUse[player] < COOLDOWN then return end
	lastUse[player] = now

	pending[player] = target
	BiteEffectEvent:FireClient(player)

	task.delay(BITE_TIMEOUT, function()
		if pending[player] == target then
			pending[player] = nil
			teleport(player, target)
		end
	end)
end

BiteEffectEvent.OnServerEvent:Connect(function(player)
	local target = pending[player]
	if target then
		pending[player] = nil
		teleport(player, target)
	end
end)

local function onTouch(part, callback)
	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then callback(player) end
	end)
end

-- Ponto em frente à porta, do lado de fora do prédio
local function outsideOf(building, doorPart)
	local center = building:GetPivot().Position
	if building:IsA("Model") then
		center = building:GetBoundingBox().Position
	end
	local outward = Vector3.new(doorPart.Position.X - center.X, 0, doorPart.Position.Z - center.Z)
	outward = outward.Magnitude > 0.1 and outward.Unit or -doorPart.CFrame.LookVector
	local spot = doorPart.Position + outward * 9
	spot = Vector3.new(spot.X, doorPart.Position.Y - doorPart.Size.Y / 2 + 3.5, spot.Z)
	return CFrame.lookAt(spot, spot + outward)
end

local function setup(config, container)
	local template = ServerStorage:FindFirstChild("Interiors") and ServerStorage.Interiors:FindFirstChild(config.Model)
	if not template then
		warn("[InteriorService] Modelo não encontrado: ServerStorage.Interiors." .. config.Model)
		return
	end

	local building = resolve(config.Building)
	local door = building and building:FindFirstChild("Porta", true)
	local entrance = door and firstPart(door:FindFirstChild("Entrar") or door)
	if not entrance then
		warn("[InteriorService] Porta de " .. config.Name .. " não encontrada em Workspace." .. table.concat(config.Building, "."))
		return
	end

	-- Scripts antigos de teleporte na porta brigariam com este; desliga e avisa
	for _, d in ipairs(entrance.Parent:GetDescendants()) do
		if d:IsA("Script") and d.Enabled and (d.Parent == entrance or d.Parent.Name == "Entrar") then
			d.Enabled = false
			warn("[InteriorService] Script antigo desativado em " .. d:GetFullName() .. " (pode apagar no Studio)")
		end
	end

	local interior = template:Clone()
	interior:PivotTo(CFrame.new(config.Position))
	interior.Parent = container

	local spawnPart = interior:FindFirstChild("SpawnInterior", true)
	local exitPart = interior:FindFirstChild("Saida", true)
	if not (spawnPart and exitPart) then
		warn("[InteriorService] " .. config.Model .. " sem SpawnInterior/Saida")
		return
	end

	local inside = spawnPart.CFrame + Vector3.new(0, 3, 0)
	local outside = outsideOf(building, entrance)

	onTouch(entrance, function(player)
		requestTeleport(player, inside)
	end)
	onTouch(exitPart, function(player)
		requestTeleport(player, outside)
	end)

	print("[InteriorService] Interior pronto:", config.Name)
end

function InteriorService.Start()
	local container = workspace:FindFirstChild("InterioresPredios") or Instance.new("Folder")
	container.Name = "InterioresPredios"
	container.Parent = workspace

	for _, config in ipairs(INTERIORS) do
		task.spawn(setup, config, container)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
		pending[player] = nil
	end)
end

return InteriorService
