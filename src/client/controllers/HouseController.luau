local HouseController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntrouNaCasa = ReplicatedStorage:WaitForChild("EntrouNaCasa")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") -- Pegar a pasta PlayerGui é seguro
local camera = workspace.CurrentCamera
local insideHouse = false

-- MUDANÇA 1: A variável agora começa como nula. Não tentamos pegar a GUI aqui.
local CasaGUI = nil

-- MUDANÇA 2: Criamos a nossa função segura para pegar a GUI, igual fizemos antes.
local function getCasaGui()
    -- Se ainda não temos a referência da GUI ou se ela foi destruída...
    if not CasaGUI or not CasaGUI.Parent then
        -- ...procuramos por ela com FindFirstChild, que não trava o script.
        CasaGUI = playerGui:FindFirstChild("CasaGui")
    end
    return CasaGUI
end

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
    
    -- MUDANÇA 3: Usamos nossa função segura aqui.
    local gui = getCasaGui()
    if not gui then
        warn("CasaGui não foi encontrada ao tentar entrar na casa.")
        return 
    end

	gui.Enabled = true

	local botao = gui:FindFirstChild("BotaoArmarioGui")
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
    
    -- MUDANÇA 4: E usamos nossa função segura aqui também.
    local gui = getCasaGui()
    if gui then -- Só tentamos desabilitar se a GUI existir
	    gui.Enabled = false

	    local botao = gui:FindFirstChild("BotaoArmarioGui")
	    if botao then
		    botao.Enabled = false
		    local image = botao:FindFirstChild("ImageButton")
		    if image then
			    image.Visible = false
			    image.Active = false
		    end
	    end
    end

	RunService:UnbindFromRenderStep("IsometricCamera")
	task.wait(0.1)

	if player.Character and player.Character:FindFirstChild("Humanoid") then
		camera.CameraSubject = player.Character.Humanoid
	end

	camera.CameraType = Enum.CameraType.Custom
end


local function connectTouchEvents()
	local casaPart = getCasaTrigger()
	if not casaPart then return end

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

function HouseController.PauseIsometricCamera()
	print("HouseController: Pausando a câmera isométrica a pedido de outro script.")
	RunService:UnbindFromRenderStep("IsometricCamera")
end

-- Esta função permite que outro script peça para a gente retomar o controle.
function HouseController.ResumeIsometricCamera()
	print("HouseController: Retomando a câmera isométrica, se necessário.")
	-- Só retomamos o controle se o jogador ainda estiver dentro de casa.
	if insideHouse then
		camera.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep("IsometricCamera", Enum.RenderPriority.Camera.Value, updateIsometricCamera)
	end
end


function HouseController.Start()
	-- Adicionamos um pequeno delay aqui para dar tempo da casa do jogador ser criada no workspace
	task.wait(1) 
	
	if player.Character then
		connectTouchEvents()
	end

	player.CharacterAdded:Connect(function()
		task.wait(1) -- Delay para garantir que a casa já foi criada após o respawn
		connectTouchEvents()
	end)
end

return HouseController