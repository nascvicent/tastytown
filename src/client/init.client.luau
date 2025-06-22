local CharacterSelectorClient = require(script.services.CharacterSelectorClient)
local AnimationFixController = require(script.controllers.AnimationFixController)
local HouseCameraController = require(script.controllers.HouseController)
local WardrobeBillboardController = require(script.controllers.WardrobeBillboardController)
local SprintController = require(script.controllers.SprintController) 

-- Adicione a linha para o seu novo controlador


CharacterSelectorClient.Start()
HouseCameraController.Start()
WardrobeBillboardController.Start()
AnimationFixController.Start()
SprintController.Start()



-- LocalScript: MainClient

print("MainClient iniciado.")

