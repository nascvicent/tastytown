local CharacterSelectorClient = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer

local gui = player:WaitForChild("PlayerGui"):WaitForChild("CharacterSelectionGui")
local remote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ShowCharacterSelection")

function CharacterSelectorClient.Start()
	remote.OnClientEvent:Connect(function()
		gui.Enabled = true
	end)
end

return CharacterSelectorClient
