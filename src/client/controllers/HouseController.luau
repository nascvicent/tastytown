local HouseController = {}

-- === SERVIÇOS ===
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- === EVENTOS ===
local EventsFolder = ReplicatedStorage:WaitForChild("Events")
local cameraEvent = EventsFolder:WaitForChild("SetCameraMode")
local cameraSyncEvent = EventsFolder:WaitForChild("CameraSyncRequest")

-- === REFERÊNCIAS LOCAIS ===
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local insideHouse = false
local CasaGUI = nil
local ALTURA_INTERIOR_MINIMA = 4000
local currentHouseRotationY = 0

-- === GUI ===
local function getCasaGui()
	if not CasaGUI or not CasaGUI.Parent then
		CasaGUI = playerGui:FindFirstChild("CasaGui")
	end
	return CasaGUI
end

-- === SEGURANÇA (RAYCAST) ===
local function buscarAnguloDoChao()
	local char = player.Character
	if not char then return nil end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local rayResult = workspace:Raycast(root.Position, Vector3.new(0, -200, 0), params)
	if rayResult and rayResult.Instance then
		local _, ry, _ = rayResult.Instance.CFrame:ToOrientation()
		return ry
	end

	return nil
end

local function forcarDescobertaDeAngulo()
	task.spawn(function()
		for i = 1, 20 do
			if not insideHouse then break end

			local anguloAchado = buscarAnguloDoChao()
			if anguloAchado then
				currentHouseRotationY = anguloAchado
				break
			end

			task.wait(0.25)
		end
	end)
end

-- === CÂMERA ISOMÉTRICA ===
local function updateIsometricCamera()
	local char = player.Character
	local rp = char and char:FindFirstChild("HumanoidRootPart")
	if not rp then return end

	local cameraDistance = 20
	local height = 25

	local houseCFrame = CFrame.Angles(0, currentHouseRotationY, 0)
	local isometricRotation = CFrame.Angles(0, math.rad(315), 0)

	local finalOffset =
		(houseCFrame * isometricRotation) * Vector3.new(0, height, -cameraDistance)

	local cameraPosition = rp.Position + finalOffset
	local targetCFrame =
		CFrame.new(cameraPosition, rp.Position + Vector3.new(0, 5, 0))

	camera.CFrame = camera.CFrame:Lerp(targetCFrame, 0.5)
end

-- === MODO CASA ===
local function ativarModoCasa(targetPartOpcional)
	if not insideHouse then
		insideHouse = true
	end

	local gui = getCasaGui()
	if gui then
		gui.Enabled = true
	end

	if targetPartOpcional then
		local _, y, _ = targetPartOpcional.CFrame:ToOrientation()
		currentHouseRotationY = y
	else
		forcarDescobertaDeAngulo()
	end

	-- Backup de segurança
	forcarDescobertaDeAngulo()

	camera.CameraType = Enum.CameraType.Scriptable
	RunService:UnbindFromRenderStep("IsometricCamera")
	RunService:BindToRenderStep(
		"IsometricCamera",
		Enum.RenderPriority.Camera.Value + 1,
		updateIsometricCamera
	)
end

local function desativarModoCasa()
	if not insideHouse then return end

	insideHouse = false
	currentHouseRotationY = 0

	local gui = getCasaGui()
	if gui then
		gui.Enabled = false
	end

	RunService:UnbindFromRenderStep("IsometricCamera")
	camera.CameraType = Enum.CameraType.Custom

	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
end

function HouseController.PauseIsometricCamera()
	RunService:UnbindFromRenderStep("IsometricCamera")
end

function HouseController.ResumeIsometricCamera()
	if insideHouse then
		camera.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep(
			"IsometricCamera",
			Enum.RenderPriority.Camera.Value + 1,
			updateIsometricCamera
		)
	end
end

-- === START ===
function HouseController.Start()
	-- Eventos do servidor
	cameraEvent.OnClientEvent:Connect(function(mode, targetPart)
		if mode == "Isometrico" then
			ativarModoCasa(targetPart)
		elseif mode == "Normal" then
			desativarModoCasa()
		end
	end)

	-- Handshake inicial
	task.defer(function()
		pcall(function()
			cameraSyncEvent:FireServer()
		end)
	end)

	-- Fallback por altura
	RunService:UnbindFromRenderStep("CasaAutoDetect")
	RunService:BindToRenderStep(
		"CasaAutoDetect",
		Enum.RenderPriority.Camera.Value,
		function()
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then return end

			if hrp.Position.Y > ALTURA_INTERIOR_MINIMA then
				if not insideHouse then
					ativarModoCasa(nil)
				end
			else
				if insideHouse then
					desativarModoCasa()
				end
			end
		end
	)

	-- Respawn
	player.CharacterAdded:Connect(function(newChar)
		RunService:UnbindFromRenderStep("IsometricCamera")

		local hrp = newChar:WaitForChild("HumanoidRootPart", 10)
		newChar:WaitForChild("Humanoid", 10)

		task.wait(0.2)

		local insideAttr = newChar:GetAttribute("InsideHouse")
		if insideAttr == true or (hrp and hrp.Position.Y > ALTURA_INTERIOR_MINIMA) then
			ativarModoCasa(nil)
			camera.CFrame =
				CFrame.new(hrp.Position + Vector3.new(20, 25, 20), hrp.Position)
		else
			desativarModoCasa()
		end

		pcall(function()
			cameraSyncEvent:FireServer()
		end)
	end)

	print("HouseController iniciado.")
end

return HouseController
