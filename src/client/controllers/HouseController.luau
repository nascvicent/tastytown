
local HouseController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EntrouNaCasa = ReplicatedStorage:WaitForChild("EntrouNaCasa")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local insideHouse = false

local CasaGUI = player:WaitForChild("PlayerGui"):WaitForChild("CasaGui")

local function updateIsometricCamera()
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local rp = player.Character.HumanoidRootPart
		local cameraDistance = 20
		local height = 25

		local angleY = math.rad(315)
		local offsetDirection = CFrame.Angles(0, angleY, 0) * Vector3.new(0, height, -cameraDistance)

		local cameraPosition = rp.Position + offsetDirection
		camera.CFrame = CFrame.new(cameraPosition, rp.Position + Vector3.new(0, 5, 0))
	end
end

local function getCasaTrigger()
	local nomeCasa = player.Name .. "_Casa"
	local casaModel = workspace:WaitForChild("Casas"):WaitForChild(nomeCasa)
	return casaModel:WaitForChild("CasaTrigger")
end

local function entrarNaCasa()
	if insideHouse then return end
	insideHouse = true

	CasaGUI.Enabled = true

	local botao = CasaGUI:FindFirstChild("BotaoArmarioGui")
	if botao then
		botao.Enabled = true
		botao.Active = true

		local image = botao:FindFirstChild("ImageButton")
		if image then
			image.Visible = true
			image.Active = true
		end
	end

	EntrouNaCasa:Fire()

	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("IsometricCamera", Enum.RenderPriority.Camera.Value, updateIsometricCamera)
end

local function sairDaCasa()
	if not insideHouse then return end
	insideHouse = false
	CasaGUI.Enabled = false

	local botao = CasaGUI:FindFirstChild("BotaoArmarioGui")
	if botao then
		botao.Enabled = false
		local image = botao:FindFirstChild("ImageButton")
		if image then
			image.Visible = false
			image.Active = false
		end
	end

	camera.CameraType = Enum.CameraType.Custom
	RunService:UnbindFromRenderStep("IsometricCamera")
end

local function connectTouchEvents()
	local casaPart = getCasaTrigger()

	casaPart.Touched:Connect(function(hit)
		if hit and hit.Parent == player.Character then
			entrarNaCasa()
		end
	end)

	casaPart.TouchEnded:Connect(function(hit)
		if hit and hit.Parent == player.Character then
			sairDaCasa()
		end
	end)
end

function HouseController.Start()
	if player.Character then
		task.delay(1, connectTouchEvents)
	end

	player.CharacterAdded:Connect(function()
		task.delay(1, connectTouchEvents)
	end)
end

return HouseController
