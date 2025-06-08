-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CafeteriaController = {} -- Tabela para o nosso módulo

function CafeteriaController.Start()
    local player = Players.LocalPlayer
    -- Garante que o personagem existe ou espera por ele
    local character = player.Character or player.CharacterAdded:Wait()

    -- Encontra o BillboardGui no ReplicatedStorage
    local cafeteriaGui = ReplicatedStorage:WaitForChild("Billboards"):WaitForChild("CafeteriaGui")

    -- *** IMPORTANTE: Verifique se este caminho está correto no seu Workspace! ***
    -- Certifique-se de que "croassaint" e "Box011" são os nomes exatos.
    local parteDaCafeteria = workspace:WaitForChild("croassaint"):WaitForChild("Box011") 

    -- Clone o BillboardGui (é uma boa prática clonar GUIs de ReplicatedStorage)
    local clonedCafeteriaGui = cafeteriaGui:Clone()

    -- Configure o Adornee
    clonedCafeteriaGui.Adornee = parteDaCafeteria


    
    clonedCafeteriaGui.Parent = player.PlayerGui

    print("Cafeteria Billboard carregado!") -- Mensagem de depuração
end

return CafeteriaController