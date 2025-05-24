local CharacterSelectorClient = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer


local gui = player:WaitForChild("PlayerGui"):WaitForChild("CharacterSelectionGui")
local remote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SelectionEvents"):WaitForChild("ShowCharacterSelection")

function CharacterSelectorClient.Start()
	remote.OnClientEvent:Connect(function()
	gui:Destroy()
	local newGui = game.StarterGui:WaitForChild("CharacterSelectionGui"):Clone()
	newGui.Parent = player:WaitForChild("PlayerGui")
	newGui.Enabled = true
end)

end

return CharacterSelectorClient
