local CharacterSelectorClient = require(script.services.CharacterSelectorClient)
local AnimationFixController = require(script.controllers.AnimationFixController)
local HouseCameraController = require(script.controllers.HouseController)
local WardrobeBillboardController = require(script.controllers.WardrobeBillboardController)
local BiteTransitionController = require(script.controllers.BiteTransitionController)




CharacterSelectorClient.Start()
HouseCameraController.Start()
WardrobeBillboardController.Start()
AnimationFixController.Start()
BiteTransitionController.Start()





print("MainClient iniciado.")

