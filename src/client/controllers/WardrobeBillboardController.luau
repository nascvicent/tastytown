local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local EntrouNaCasa = ReplicatedStorage:WaitForChild("EntrouNaCasa")

local WardrobeBillboardController = {}

local function safeWait(parent, childName, timeout)
	local success, result = pcall(function()
		return parent:WaitForChild(childName, timeout or 5)
	end)
	if success and result then
		return result
	else
		warn("❌ Objeto '" .. tostring(childName) .. "' não encontrado em " .. parent:GetFullName())
		return nil
	end
end

local function ajustarTamanho(imageButton)
	local camera = Workspace.CurrentCamera
	if not imageButton or not camera then return end

	local resolution = camera.ViewportSize
	local largura = resolution.X * 0.08
	local altura = resolution.Y * 0.12

	imageButton.AnchorPoint = Vector2.new(0.5, 0.5)
	imageButton.Position = UDim2.new(0.5, 0, 0.4, 0)
	imageButton.Size = UDim2.new(0, largura, 0, altura)
end

local function adicionarBillboardGui()
	local casasFolder = safeWait(Workspace, "Casas")
	if not casasFolder then return end

	local nomeCasa = player.Name .. "_Casa"
	local casa = safeWait(casasFolder, nomeCasa)
	if not casa then return end

	local wardrobe = safeWait(casa, "wardrobe")
	if not wardrobe then return end

	local armario = safeWait(wardrobe, "Click")
	if not armario then return end

	local templateGui = safeWait(ReplicatedStorage, "BotaoArmarioGui")
	if not templateGui then return end

	local playerGui = safeWait(player, "PlayerGui")
	if not playerGui then return end

	local casaGui = safeWait(playerGui, "CasaGui")
	if not casaGui then return end

	-- Remove anteriores
	for _, gui in pairs(casaGui:GetChildren()) do
		if gui:IsA("BillboardGui") and gui.Name == templateGui.Name then
			gui:Destroy()
		end
	end

	local guiClone = templateGui:Clone()
	guiClone.Adornee = armario
	guiClone.Parent = casaGui

	local imageButton = guiClone:FindFirstChild("ImageButton")
	if imageButton then
		ajustarTamanho(imageButton)
	end

	RunService.RenderStepped:Connect(function()
		if imageButton and imageButton.Parent then
			ajustarTamanho(imageButton)
		end
	end)
end

local function monitorarCasaDoJogador()
	local casasFolder = Workspace:WaitForChild("Casas")
	local casaNome = player.Name .. "_Casa"

	casasFolder.ChildAdded:Connect(function(child)
		if child.Name == casaNome then
			task.wait(1)
			adicionarBillboardGui()
		end
	end)
end

function WardrobeBillboardController.Start()
	adicionarBillboardGui()
	monitorarCasaDoJogador()

	EntrouNaCasa.Event:Connect(function()
		task.delay(0.5, adicionarBillboardGui)
	end)

	player.CharacterAdded:Connect(function()
		task.delay(1, adicionarBillboardGui)
	end)
end

return WardrobeBillboardController
