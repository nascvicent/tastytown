local CharacterSelectorClient = require(script.services.CharacterSelectorClient)
local AnimationFixController = require(script.controllers.AnimationFixController)
local HouseCameraController = require(script.controllers.HouseController)
local WardrobeBillboardController = require(script.controllers.WardrobeBillboardController)
local SprintController = require(script.controllers.SprintController) 

-- Adicione a linha para o seu novo controlador
local CafeteriaController = require(script.controllers.CafeteriaController) 

CharacterSelectorClient.Start()
HouseCameraController.Start()
WardrobeBillboardController.Start()
AnimationFixController.Start()
SprintController.Start()

-- Chame a função Start() do seu CafeteriaController
CafeteriaController.Start()

-- LocalScript: MainClient

print("MainClient iniciado.")

