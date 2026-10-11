local CharacterSelectorClient = require(script.services.CharacterSelectorClient)
local AnimationFixController = require(script.controllers.AnimationFixController)
local HouseCameraController = require(script.controllers.HouseController)
local WardrobeBillboardController = require(script.controllers.WardrobeBillboardController)
local BiteTransitionController = require(script.controllers.BiteTransitionController)
local HouseExitController = require(script.controllers.HouseExitController)




CharacterSelectorClient.Start()
HouseCameraController.Start()
WardrobeBillboardController.Start()
AnimationFixController.Start()
HouseExitController.Start()
BiteTransitionController.Start() -- pode esperar até 10s pela BiteAnim; fica por último





print("MainClient iniciado.")

