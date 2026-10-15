local CharacterSelectorClient = require(script.services.CharacterSelectorClient)
local AnimationFixController = require(script.controllers.AnimationFixController)
local HouseCameraController = require(script.controllers.HouseController)
local BiteTransitionController = require(script.controllers.BiteTransitionController)
local HouseExitController = require(script.controllers.HouseExitController)
local PromptController = require(script.controllers.PromptController)
local FloorCutawayController = require(script.controllers.FloorCutawayController)




CharacterSelectorClient.Start()
HouseCameraController.Start()
AnimationFixController.Start()
HouseExitController.Start()
PromptController.Start()
FloorCutawayController.Start()
BiteTransitionController.Start() -- espera a BiteAnim em segundo plano





print("MainClient iniciado.")

