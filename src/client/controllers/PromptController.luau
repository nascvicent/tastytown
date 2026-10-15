--[[
	PromptController — visual próprio para ProximityPrompts com Style = Custom.

	Mesmo estilo dos botões do jogo (pílula rosa do "Edit Home", FredokaOne):
	selo branco com a tecla (E / botão do controle / "TOQUE") + ação e objeto.
	Clicar/tocar na pílula também ativa o prompt.
]]

local PromptController = {}

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PINK = Color3.fromRGB(255, 182, 193)
local PINK_DARK = Color3.fromRGB(235, 120, 150)
local WHITE = Color3.new(1, 1, 1)

local GAMEPAD_LABELS = {
	ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y",
	ButtonL1 = "LB", ButtonR1 = "RB", ButtonL2 = "LT", ButtonR2 = "RT",
}

local function new(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	inst.Parent = props.Parent
	return inst
end

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TOQUE"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD_LABELS[prompt.GamepadKeyCode.Name] or prompt.GamepadKeyCode.Name
	end
	return prompt.KeyboardKeyCode.Name
end

local function buildPrompt(prompt, inputType)
	local billboard = new("BillboardGui", {
		Name = "TastyPrompt",
		AlwaysOnTop = true,
		Active = true,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(240, 64),
		StudsOffset = Vector3.new(0, 3, 0),
		LightInfluence = 0,
		Adornee = prompt.Parent,
		Parent = playerGui,
	})

	local pill = new("TextButton", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 52),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = PINK,
		AutoButtonColor = false,
		Text = "",
		Parent = billboard,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		new("UIStroke", { Color = WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 18) }),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	local scale = new("UIScale", { Scale = 0.6, Parent = pill })

	-- Selo com a tecla
	local key = keyText(prompt, inputType)
	local badge = new("Frame", {
		Name = "Tecla",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(#key > 2 and 64 or 40, 40),
		BackgroundColor3 = WHITE,
		Parent = pill,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = key,
		Font = Enum.Font.FredokaOne,
		TextColor3 = PINK_DARK,
		TextScaled = true,
		Parent = badge,
	}, {
		new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0), PaddingLeft = UDim.new(0.12, 0), PaddingRight = UDim.new(0.12, 0) }),
	})

	-- Textos: ação (grande) e objeto (pequeno, acima)
	local texts = new("Frame", {
		Name = "Textos",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = pill,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	if prompt.ObjectText ~= "" then
		new("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(0, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = prompt.ObjectText,
			Font = Enum.Font.FredokaOne,
			TextSize = 14,
			TextColor3 = WHITE,
			TextTransparency = 0.15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = texts,
		})
	end
	local action = new("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = prompt.ActionText,
		Font = Enum.Font.FredokaOne,
		TextSize = 22,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = texts,
	})
	new("UIStroke", { Color = PINK_DARK, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = action })

	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	-- Clique/toque na pílula ativa o prompt
	pill.Activated:Connect(function()
		prompt:InputHoldBegin()
		task.wait()
		prompt:InputHoldEnd()
	end)
	pill.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
	end)
	pill.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)

	local triggeredConnection = prompt.Triggered:Connect(function()
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)

	return function()
		triggeredConnection:Disconnect()
		local tween = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.5 })
		tween.Completed:Connect(function() billboard:Destroy() end)
		tween:Play()
	end
end

function PromptController.Start()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
		local cleanup = buildPrompt(prompt, inputType)
		local hiddenConnection
		hiddenConnection = prompt.PromptHidden:Connect(function()
			hiddenConnection:Disconnect()
			cleanup()
		end)
	end)

	-- Atributo "Som" no prompt: nome de um som em ReplicatedStorage.Sounds, tocado ao ativar
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local soundName = prompt:GetAttribute("Som")
		if type(soundName) ~= "string" then return end
		local sounds = ReplicatedStorage:FindFirstChild("Sounds")
		local sound = sounds and sounds:FindFirstChild(soundName)
		if sound and sound:IsA("Sound") then sound:Play() end
	end)
end

return PromptController
