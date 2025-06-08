-- ModuleScript: SprintController

local SprintController = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService") -- Novo serviço

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera -- Pega a câmera atual

-- Variáveis para armazenar o estado do personagem atual
local currentCharacter = nil
local currentHumanoid = nil
local initialWalkSpeed = 0
local sprintMultiplier = 1.30

-- Variáveis para o FOV
local initialFOV = 70 -- Será definido com o FOV atual da câmera ao iniciar
local sprintFOVOffset = 8 -- Quanto o FOV aumenta ao correr (ex: 70 + 8 = 78)
local fovTweenDuration = 0.2 -- Duração da animação de mudança do FOV
local currentFOVTween = nil -- Para controlar o tween atual do FOV

local shiftKeysPressed = {}

local updateSprintState -- Declaração antecipada

local function onInputBegan(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if not currentHumanoid or not currentHumanoid.Parent then return end

    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        shiftKeysPressed[input.KeyCode] = true
        updateSprintState()
    end
end

local function onInputEnded(input, gameProcessedEvent)
    if not currentHumanoid or not currentHumanoid.Parent then return end

    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        shiftKeysPressed[input.KeyCode] = nil
        updateSprintState()
    end
end

updateSprintState = function()
    if not currentHumanoid or not currentHumanoid.Parent then return end

    local targetSpeed
    local targetFOV

    if next(shiftKeysPressed) then -- Se alguma tecla Shift está pressionada (correndo)
        targetSpeed = initialWalkSpeed * sprintMultiplier
        targetFOV = initialFOV + sprintFOVOffset
    else -- Não está correndo
        targetSpeed = initialWalkSpeed
        targetFOV = initialFOV -- Volta para o FOV inicial capturado
    end

    -- Atualiza a velocidade de caminhada
    if currentHumanoid.WalkSpeed ~= targetSpeed then
        currentHumanoid.WalkSpeed = targetSpeed
    end

    -- Atualiza o FOV com Tween
    if camera.FieldOfView ~= targetFOV then
        if currentFOVTween then
            currentFOVTween:Cancel() -- Cancela qualquer tween de FOV anterior
            currentFOVTween = nil
        end
        
        local tweenInfo = TweenInfo.new(fovTweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        currentFOVTween = TweenService:Create(camera, tweenInfo, { FieldOfView = targetFOV })
        currentFOVTween:Play()
    end
end

local function setupSprintForCharacter(character)
    if currentHumanoid then
        -- Opcional: Se você tinha conexões específicas ao humanoid antigo que precisam ser limpas
        -- (além do Died que já é tratado por ser uma nova instância).
    end
    
    currentCharacter = character
    currentHumanoid = character:WaitForChild("Humanoid")
    initialWalkSpeed = currentHumanoid.WalkSpeed 

    print(string.format("SprintController: Configurado para %s. Velocidade base: %.2f, Velocidade Sprint: %.2f, FOV Base: %.2f", 
        character.Name, initialWalkSpeed, initialWalkSpeed * sprintMultiplier, initialFOV))

    shiftKeysPressed = {} -- Limpa ao trocar de personagem

    currentHumanoid.Died:Connect(function()
        shiftKeysPressed = {}
        -- Ao morrer, o FOV deve ser resetado. updateSprintState fará isso se chamado
        -- quando shiftKeysPressed estiver vazio.
        -- Se o jogador respawnar, setupSprintForCharacter será chamado e o FOV será reconfigurado.
        if camera.FieldOfView ~= initialFOV then
             local tweenInfo = TweenInfo.new(fovTweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
             local deathFovTween = TweenService:Create(camera, tweenInfo, { FieldOfView = initialFOV })
             deathFovTween:Play()
        end
    end)
    
    updateSprintState() -- Atualiza o estado inicial (velocidade e FOV)
end

function SprintController.Start()
    initialFOV = camera.FieldOfView -- Captura o FOV inicial do jogador uma vez

    UserInputService.InputBegan:Connect(onInputBegan)
    UserInputService.InputEnded:Connect(onInputEnded)

    UserInputService.WindowFocusReleased:Connect(function()
        if next(shiftKeysPressed) then
            shiftKeysPressed = {}
            updateSprintState()
        end
    end)

    if player.Character then
        setupSprintForCharacter(player.Character)
    end
    player.CharacterAdded:Connect(setupSprintForCharacter)

    print("SprintController.Start() chamado. Sistema de Sprint com FOV Ativo. FOV Inicial Padrão: " .. initialFOV)
end

return SprintController