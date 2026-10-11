--[[
	FloorCutawayController — andares de cima somem quando o jogador está embaixo
	(estilo The Sims), para a câmera isométrica enxergar o térreo inteiro.

	Não mexe na câmera: só deixa o Model "AndarSuperior" do interior da própria casa
	invisível localmente (LocalTransparencyModifier) enquanto os pés do personagem
	estão abaixo do piso de cima (AndarSuperior/PisoSuperior).
]]

local FloorCutawayController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local CHECK_INTERVAL = 0.15
local MARGIN = 2.5 -- começa a mostrar o andar quando o jogador está quase chegando no topo da escada

-- [AndarSuperior] = boolean (chaves fracas: interiores reconstruídos são liberados)
local hiddenState = setmetatable({}, { __mode = "k" })

local function setHidden(level, hidden)
	if hiddenState[level] == hidden then return end
	hiddenState[level] = hidden
	for _, d in ipairs(level:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		elseif d:IsA("SurfaceGui") or d:IsA("Light") then
			d.Enabled = not hidden
		end
	end
end

local function feetHeight(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return nil end
	return root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
end

function FloorCutawayController.Start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_INTERVAL then return end
		elapsed = 0

		local interiores = workspace:FindFirstChild("Interiores")
		local interior = interiores and interiores:FindFirstChild(player.Name .. "_Interior")
		if not interior then return end

		local character = player.Character
		local feet = character and feetHeight(character)

		for _, level in ipairs(interior:GetChildren()) do
			if level.Name == "AndarSuperior" then
				local floor = level:FindFirstChild("PisoSuperior")
				if floor and floor:IsA("BasePart") then
					local floorTop = floor.Position.Y + floor.Size.Y / 2
					-- Sem personagem (ou fora de casa) o andar fica visível
					setHidden(level, feet ~= nil and character:GetAttribute("InsideHouse") == true and feet < floorTop - MARGIN)
				end
			end
		end
	end)
end

return FloorCutawayController
