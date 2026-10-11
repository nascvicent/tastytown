--[[
	MapService — destinos do mapa e teleporte dentro do place.

	O cliente só envia o Id do destino; posição de pouso, cooldown e
	validações ficam todos aqui no servidor.
]]

local MapService = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig"))

local Events = ReplicatedStorage:WaitForChild("Events")
local MapEvents = Events:WaitForChild("MapEvents")
local GetDestinations = MapEvents:WaitForChild("GetDestinations")
local TeleportTo = MapEvents:WaitForChild("TeleportTo")
local cameraEvent = Events:WaitForChild("SetCameraMode")

-- Pastas do Workspace que nunca são destino nem chão de pouso válido para busca por nome
local IGNORED_ROOTS = { Casas = true, Interiores = true, Lotes = true }

-- Superfícies onde não queremos pousar (rio de leite, água)
local WATER_PATTERNS = { "^rio", "leite", "milk", "water", "^agua", "^água", "river" }

local lastTeleport = {}
local warnedMissing = {}

-- ═══════════════════════════════════════════
-- Helpers
-- ═══════════════════════════════════════════
local function matchesAny(name, patterns)
	local lower = string.lower(name)
	for _, pattern in ipairs(patterns) do
		if string.find(lower, pattern) then
			return true
		end
	end
	return false
end

-- "FruitGym" -> "Fruit Gym"
local function prettify(name)
	return (string.gsub(name, "(%l)(%u)", "%1 %2"))
end

local function boundsOf(inst)
	if inst:IsA("Model") then
		return inst:GetBoundingBox()
	elseif inst:IsA("BasePart") then
		return inst.CFrame, inst.Size
	end

	-- Folder: caixa alinhada aos eixos de todas as Parts
	local minV, maxV = nil, nil
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			local half = d.Size / 2
			local p = d.Position
			minV = minV and minV:Min(p - half) or (p - half)
			maxV = maxV and maxV:Max(p + half) or (p + half)
		end
	end
	if not minV then return nil end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end

local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then return nil end
	return f.Unit
end

local function isWaterLike(result)
	if result.Material == Enum.Material.Water then return true end
	local current = result.Instance
	while current and current ~= workspace do
		if matchesAny(current.Name, WATER_PATTERNS) then return true end
		current = current.Parent
	end
	return false
end

local function charactersExclude(extra)
	local list = { extra }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(list, plr.Character) end
	end
	return list
end

local function groundAt(position, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false
	return workspace:Raycast(position + Vector3.new(0, 80, 0), Vector3.new(0, -250, 0), params)
end

local function findDoor(inst)
	for _, d in ipairs(inst:GetDescendants()) do
		if string.find(string.lower(d.Name), "^porta") then
			if d:IsA("BasePart") then return d.Position end
			if d:IsA("Model") then return d:GetPivot().Position end
		end
	end
	return nil
end

-- Calcula onde o jogador aparece ao ir para um destino
local function landingFor(inst)
	local marker = inst:FindFirstChild("MapSpawn", true)
	if marker and marker:IsA("BasePart") then
		return marker.CFrame + Vector3.new(0, 3.5, 0)
	end

	local cf, size = boundsOf(inst)
	if not cf then return nil end
	local center = cf.Position
	local exclude = charactersExclude(inst)

	local candidates = {}

	-- Preferência: em frente à porta (centro -> porta aponta para fora do prédio)
	local door = findDoor(inst)
	if door then
		local outward = flat(door - center)
		if outward then
			table.insert(candidates, door + outward * 10)
		end
	end

	-- Depois: ao redor da caixa do modelo
	local look = flat(cf.LookVector) or Vector3.new(0, 0, -1)
	local right = flat(cf.RightVector) or Vector3.new(1, 0, 0)
	local hx, hz = size.X / 2 + 8, size.Z / 2 + 8
	for _, offset in ipairs({ -look * hz, look * hz, right * hx, -right * hx }) do
		table.insert(candidates, center + offset)
	end

	for _, candidate in ipairs(candidates) do
		local hit = groundAt(candidate, exclude)
		if hit and not isWaterLike(hit) then
			local pos = hit.Position + Vector3.new(0, 3.5, 0)
			return CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
		end
	end

	-- Último recurso: em cima do modelo
	return CFrame.new(center + Vector3.new(0, size.Y / 2 + 4, 0))
end

local function getHomeExterior(player)
	local casas = workspace:FindFirstChild("Casas")
	return casas and casas:FindFirstChild(player.Name .. "_Exterior")
end

-- Mesmo ponto usado pelo HouseService ao sair de casa
local function homeLanding(player)
	local exterior = getHomeExterior(player)
	if not exterior then return nil end

	local frente = exterior:FindFirstChild("FrenteDaCasa")
	local porta = exterior:FindFirstChild("PortaEntrada")
	if frente and porta then
		return frente.CFrame + porta.CFrame.LookVector * 5
	end
	return landingFor(exterior)
end

-- ═══════════════════════════════════════════
-- Descoberta de destinos
-- ═══════════════════════════════════════════
local function resolvePath(path)
	local current = workspace
	for _, name in ipairs(path) do
		current = current:FindFirstChild(name)
		if not current then return nil end
	end
	return current
end

-- Procura por nome no Workspace (topo e um nível dentro de pastas/modelos)
local function searchByName(patterns)
	for _, child in ipairs(workspace:GetChildren()) do
		if not IGNORED_ROOTS[child.Name] and child.Name ~= MapConfig.BuildingsFolder then
			if matchesAny(child.Name, patterns) and not child:IsA("Terrain") and not child:IsA("Camera") then
				return child
			end
		end
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if not IGNORED_ROOTS[child.Name] and child.Name ~= MapConfig.BuildingsFolder
			and (child:IsA("Folder") or child:IsA("Model")) then
			for _, grandchild in ipairs(child:GetChildren()) do
				if matchesAny(grandchild.Name, patterns) then
					return grandchild
				end
			end
		end
	end
	return nil
end

local function discover()
	local list = {}
	local seen = {}

	local function add(id, inst, defaults)
		if seen[inst] then return end
		local override = MapConfig.Overrides[inst.Name] or {}
		if override.Hidden then return end
		seen[inst] = true
		table.insert(list, {
			Id = id,
			Instance = inst,
			Name = override.Name or defaults.Name or prettify(inst.Name),
			Icon = override.Icon or defaults.Icon or "📍",
			Description = override.Description or defaults.Description or "",
			Kind = defaults.Kind,
			Order = override.Order or defaults.Order or 50,
		})
	end

	local spawnLocation = workspace:FindFirstChild("SpawnLocation")
	if spawnLocation then
		add("spawn", spawnLocation, {
			Name = MapConfig.Spawn.Name,
			Icon = MapConfig.Spawn.Icon,
			Description = MapConfig.Spawn.Description,
			Kind = "spawn",
			Order = 0,
		})
	end

	local buildings = workspace:FindFirstChild(MapConfig.BuildingsFolder)
	if buildings then
		for _, child in ipairs(buildings:GetChildren()) do
			if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Folder") then
				add("predio:" .. child.Name, child, { Kind = "building", Order = 10 })
			end
		end
	end

	for _, extra in ipairs(MapConfig.Extras) do
		local inst = extra.Path and resolvePath(extra.Path) or searchByName(extra.Patterns or {})
		if inst then
			add("extra:" .. extra.Id, inst, {
				Name = extra.Name,
				Icon = extra.Icon,
				Description = extra.Description,
				Kind = "extra",
				Order = 20,
			})
		elseif not warnedMissing[extra.Id] then
			warnedMissing[extra.Id] = true
			local names = {}
			for _, child in ipairs(workspace:GetChildren()) do
				table.insert(names, child.Name)
			end
			warn(("[MapService] Destino '%s' não encontrado. Defina Path no MapConfig. Filhos do Workspace: %s")
				:format(extra.Name, table.concat(names, ", ")))
		end
	end

	for _, inst in ipairs(CollectionService:GetTagged(MapConfig.Tag)) do
		if inst:IsDescendantOf(workspace) then
			add("tag:" .. inst:GetFullName(), inst, {
				Name = inst:GetAttribute("MapName"),
				Icon = inst:GetAttribute("MapIcon"),
				Description = inst:GetAttribute("MapDescription"),
				Kind = "custom",
				Order = 30,
			})
		end
	end

	table.sort(list, function(a, b)
		if a.Order ~= b.Order then return a.Order < b.Order end
		return a.Name < b.Name
	end)
	return list
end

local function findDestination(id)
	for _, dest in ipairs(discover()) do
		if dest.Id == id then return dest end
	end
	return nil
end

-- ═══════════════════════════════════════════
-- Teleporte
-- ═══════════════════════════════════════════
local function teleportCharacter(player, character, humanoid, target)
	-- Sai do carro antes (senão o personagem leva o veículo junto ou fica preso no assento)
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
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end

	-- Se estava dentro de casa, volta a câmera ao normal
	if character:GetAttribute("InsideHouse") then
		character:SetAttribute("InsideHouse", false)
		cameraEvent:FireClient(player, "Normal")
	end

	task.delay(1, function()
		if character.Parent then
			character:SetAttribute("Teleportando", false)
		end
	end)
end

-- ═══════════════════════════════════════════
-- Start
-- ═══════════════════════════════════════════
function MapService.Start()
	GetDestinations.OnServerInvoke = function(player)
		local result = {}
		for _, dest in ipairs(discover()) do
			local cf = boundsOf(dest.Instance)
			if cf then
				table.insert(result, {
					id = dest.Id,
					name = dest.Name,
					icon = dest.Icon,
					description = dest.Description,
					kind = dest.Kind,
					x = cf.Position.X,
					z = cf.Position.Z,
				})
			end
		end

		local exterior = getHomeExterior(player)
		if exterior then
			local pos = exterior:GetPivot().Position
			table.insert(result, {
				id = "home",
				name = MapConfig.Home.Name,
				icon = MapConfig.Home.Icon,
				description = MapConfig.Home.Description,
				kind = "home",
				x = pos.X,
				z = pos.Z,
			})
		end

		return result
	end

	TeleportTo.OnServerInvoke = function(player, id)
		if typeof(id) ~= "string" then
			return false, "Destino inválido"
		end

		local now = os.clock()
		if lastTeleport[player] and now - lastTeleport[player] < MapConfig.TeleportCooldown then
			return false, "Aguarde um pouco"
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return false, "Sem personagem"
		end
		if character:GetAttribute("Teleportando") then
			return false, "Aguarde um pouco"
		end

		local target
		if id == "home" then
			target = homeLanding(player)
		else
			local dest = findDestination(id)
			target = dest and landingFor(dest.Instance)
		end
		if not target then
			return false, "Destino indisponível"
		end

		lastTeleport[player] = now
		teleportCharacter(player, character, humanoid, target)
		return true
	end

	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)
end

return MapService
