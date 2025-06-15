-- ModuleScript: CharacterSelectorClient
local CharacterSelectorClient = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui") -- Referência ao StarterGui

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") -- A pasta PlayerGui sempre vai existir

local remote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SelectionEvents"):WaitForChild("ShowCharacterSelection")

function CharacterSelectorClient.Start()
    remote.OnClientEvent:Connect(function()
        -- A lógica agora está DENTRO do evento, que é o lugar seguro.

        -- 1. Primeiro, procuramos e destruímos qualquer versão antiga da GUI que possa existir.
        local existingGui = playerGui:FindFirstChild("CharacterSelectionGui")
        if existingGui then
            existingGui:Destroy()
        end

        -- 2. Agora, clonamos uma cópia "fresquinha" do modelo no StarterGui.
        local guiTemplate = StarterGui:WaitForChild("CharacterSelectionGui")
        if not guiTemplate then
            warn("AVISO: CharacterSelectionGui não foi encontrada em StarterGui!")
            return
        end
          print(debug.traceback("Evento 'ShowSelectionEvent' recebido! Origem no servidor:"))
        local newGui = guiTemplate:Clone()
        newGui.Parent = playerGui
        newGui.Enabled = true
        newGui.CharacterFrame.Visible = true 
        
        print("Interface de Seleção de Personagem exibida para o jogador.") -- Mensagem para debug
    end)

    print("CharacterSelectorClient iniciado. Aguardando evento do servidor.")
end

return CharacterSelectorClient