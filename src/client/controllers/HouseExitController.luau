--[[
	HouseExitController — botão "Sair de Casa" (aparece só dentro de casa).

	Mesmo visual do botão "Edit Home" do CasaGui (pílula rosa, FredokaOne) e fica
	logo acima dele. Pede ao servidor (HouseEvents.ExitHouse), que faz a transição
	de mordida e leva o jogador para a frente da casa.
]]

local HouseExitController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DEFAULT_COLOR = Color3.fromRGB(255, 182, 193) -- mesmas cores do Edit Home
local HOVER_COLOR = Color3.fromRGB(255, 160, 180)

local exitEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("HouseEvents"):WaitForChild("ExitHouse")

local function new(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	inst.Parent = props.Parent
	return inst
end

local function buildGui()
	local gui = new("ScreenGui", {
		Name = "HouseExitGui",
		ResetOnSpawn = false,
		Enabled = false,
		DisplayOrder = 5,
		Parent = playerGui,
	})

	local button = new("TextButton", {
		Name = "SairButton",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.02, 0, 0.905, 0), -- logo acima do Edit Home (0.98)
		Size = UDim2.new(0, 0, 0.06, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = DEFAULT_COLOR,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.25, 0) }),
		new("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	local scale = new("UIScale", { Parent = button })

	-- Ícone de porta desenhado com frames (sem depender de asset)
	local icon = new("Frame", {
		Name = "Icone",
		LayoutOrder = 1,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = button,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = 0.75 }),
	})
	new("Frame", {
		Name = "Porta",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(196, 128, 88),
		BorderSizePixel = 0,
		Parent = icon,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
		new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }),
	})
	new("Frame", {
		Name = "Macaneta",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.72, 0.55),
		Size = UDim2.fromScale(0.2, 0.15),
		BackgroundColor3 = Color3.fromRGB(255, 214, 90),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = icon,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local label = new("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "Sair de Casa",
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Parent = button,
	})
	new("UITextSizeConstraint", { MinTextSize = 14, MaxTextSize = 28, Parent = label })

	local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = HOVER_COLOR
		TweenService:Create(scale, info, { Scale = 1.1 }):Play()
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = DEFAULT_COLOR
		TweenService:Create(scale, info, { Scale = 1 }):Play()
	end)

	local busy = false
	button.MouseButton1Click:Connect(function()
		if busy then return end
		busy = true
		exitEvent:FireServer()
		task.delay(2, function() busy = false end)
	end)

	return gui
end

function HouseExitController.Start()
	local gui = buildGui()

	-- Mostra o botão só enquanto o personagem está dentro de casa
	local attributeConnection
	local function watch(character)
		if attributeConnection then attributeConnection:Disconnect() end
		local function update()
			gui.Enabled = character:GetAttribute("InsideHouse") == true
		end
		attributeConnection = character:GetAttributeChangedSignal("InsideHouse"):Connect(update)
		update()
	end

	if player.Character then watch(player.Character) end
	player.CharacterAdded:Connect(watch)
end

return HouseExitController
