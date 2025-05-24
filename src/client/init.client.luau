local CharacterSelectorClient = require(script.services.CharacterSelectorClient)
local AnimationFixController = require(script.controllers.AnimationFixController)
local HouseCameraController = require(script.controllers.HouseController)
local WardrobeBillboardController = require(script.controllers.WardrobeBillboardController)

CharacterSelectorClient.Start()
HouseCameraController.Start()
WardrobeBillboardController.Start()
AnimationFixController.Start()
