
local AnimationFixController = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function fixCharacterAnimation(character)
    if not character then return end
    
    
    local animateScript = character:WaitForChild("Animate", 5) 
    
    if animateScript and animateScript:IsA("LocalScript") then
       
        animateScript.Disabled = true
        task.wait() 
        animateScript.Disabled = false
    end
end

function AnimationFixController.Start()
    -- Conecta a função ao evento CharacterAdded
    player.CharacterAdded:Connect(fixCharacterAnimation)

    -- Se o personagem já existir quando o módulo iniciar, aplica a correção
    if player.Character then
        fixCharacterAnimation(player.Character)
    end
end

return AnimationFixController
