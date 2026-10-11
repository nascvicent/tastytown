--[[
	Mapa (cliente) — abre pelo MapButton da HudGui e teleporta dentro do place.
	Visual no mesmo estilo do Shop/Inventário (Shared/UI).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme"))
local Components = require(UI:WaitForChild("Components"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local Colors = Theme.Colors

local MapEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MapEvents")
local GetDestinations = MapEvents:WaitForChild("GetDestinations")
local TeleportTo = MapEvents:WaitForChild("TeleportTo")
local popSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("PopSound")

local gui = script.Parent
local new = Components.new

local STUDS_TO_METERS = 0.28

-- Cor de destaque de cada tipo de destino (borda do pin e do card)
local KIND_COLORS = {
	spawn = Theme.Rarity.Legendary.Color,
	building = Colors.Panel,
	extra = Color3.fromRGB(120, 190, 255),
	custom = Colors.TileSelected,
	home = Colors.MapHome,
}

-- ═══════════════════════════════════════════
-- Janela
-- ═══════════════════════════════════════════
local panel = Components.Panel({
	Parent = gui,
	Name = "MainFrame",
	Title = "MAPA",
	HasTabs = false,
})
local mainFrame = panel.Frame
local page = panel.Page
new("UIPadding", {
	PaddingTop = UDim.new(0.04, 0),
	PaddingBottom = UDim.new(0.04, 0),
	PaddingLeft = UDim.new(0.025, 0),
	PaddingRight = UDim.new(0.025, 0),
	Parent = page,
})

-- Área do mapa (esquerda)
local canvas = new("Frame", {
	Name = "MapCanvas",
	Size = UDim2.fromScale(0.63, 1),
	BackgroundColor3 = Colors.MapGround,
	ClipsDescendants = true,
	Parent = page,
}, {
	Components.corner(Theme.Radius.Page),
	Components.stroke(Colors.White, 3),
	new("UIGradient", {
		Rotation = 45,
		Color = ColorSequence.new(Colors.MapGround, Colors.MapGroundDark),
	}),
})

if MapConfig.MapImage ~= "" then
	new("ImageLabel", {
		Name = "MapImage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = MapConfig.MapImage,
		ScaleType = Enum.ScaleType.Stretch,
		Parent = canvas,
	})
end

-- Margem interna para os pins não encostarem na borda
local pinLayer = new("Frame", {
	Name = "Pins",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.84, 0.8),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Parent = canvas,
})

local youMarker = new("Frame", {
	Name = "You",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromScale(0.05, 0.05),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	BackgroundColor3 = Colors.MapYou,
	Visible = false,
	ZIndex = 6,
	Parent = pinLayer,
}, {
	Components.corner(999),
	Components.stroke(Colors.White, 2),
})
local youLabel = Components.label({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -2),
	Size = UDim2.fromScale(3.2, 1.3),
	Text = "VOCÊ",
	TextColor3 = Colors.MapYou,
	ZIndex = 6,
	Parent = youMarker,
})
Components.stroke(Colors.White, 2, Enum.ApplyStrokeMode.Contextual).Parent = youLabel

-- Card de detalhes (direita), no estilo dos cards do Shop
local details = new("Frame", {
	Name = "Details",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromScale(0.34, 1),
	BackgroundColor3 = Colors.White,
	Parent = page,
}, {
	Components.corner(Theme.Radius.Card),
})
local detailsGradient = new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Colors.White, Colors.White),
	Parent = details,
})
local detailsStroke = Components.stroke(Colors.Panel, 3)
detailsStroke.Parent = details

local detailIcon = Components.label({
	Name = "Icon",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.06),
	Size = UDim2.fromScale(0.5, 0.24),
	Text = "🗺️",
	Parent = details,
})
local detailName = Components.label({
	Name = "Name",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.33),
	Size = UDim2.fromScale(0.9, 0.12),
	Text = "Escolha um local",
	Parent = details,
})
local detailNameStroke = Components.stroke(Colors.Header, 2, Enum.ApplyStrokeMode.Contextual)
detailNameStroke.Parent = detailName

local detailDescription = Components.label({
	Name = "Description",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromScale(0.88, 0.2),
	Text = "Toque em um ponto do mapa para ver os detalhes.",
	Font = Theme.BodyFont,
	TextColor3 = Colors.Text,
	TextScaled = true,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = details,
})
new("UITextSizeConstraint", { MaxTextSize = 18, Parent = detailDescription })

local detailDistance = Components.label({
	Name = "Distance",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.69),
	Size = UDim2.fromScale(0.8, 0.07),
	Text = "",
	TextColor3 = Colors.TextSoft,
	Parent = details,
})

local goButton, setGoStyle = Components.ActionButton(details, {
	Name = "GoButton",
	Size = UDim2.fromScale(0.86, 0.15),
	Position = UDim2.fromScale(0.5, 0.95),
})
setGoStyle("IR!", Colors.Gray, false)

-- ═══════════════════════════════════════════
-- Estado
-- ═══════════════════════════════════════════
local destinations = {}
local selected = nil
local pins = {} -- [id] = { button, stroke, scale }
local teleporting = false
local projection = nil -- função world (x,z) -> UDim2

local fade = Components.ScreenFade(playerGui)
local setCameraEffects = Components.CameraEffects("MapBlur")

local function isOpen()
	return gui.Enabled and mainFrame.Visible
end

-- ═══════════════════════════════════════════
-- Projeção mundo -> mapa
-- ═══════════════════════════════════════════
-- Sem imagem: enquadra todos os destinos mantendo a proporção real (sem esticar)
local function buildProjection()
	local bounds = MapConfig.WorldBounds
	if MapConfig.MapImage ~= "" and bounds then
		return function(x, z)
			return UDim2.fromScale(
				(x - bounds.MinX) / (bounds.MaxX - bounds.MinX),
				(z - bounds.MinZ) / (bounds.MaxZ - bounds.MinZ)
			)
		end
	end

	if #destinations == 0 then return nil end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, dest in ipairs(destinations) do
		minX = math.min(minX, dest.x)
		maxX = math.max(maxX, dest.x)
		minZ = math.min(minZ, dest.z)
		maxZ = math.max(maxZ, dest.z)
	end
	local rangeX = math.max(maxX - minX, 50)
	local rangeZ = math.max(maxZ - minZ, 50)
	local centerX, centerZ = (minX + maxX) / 2, (minZ + maxZ) / 2

	local size = pinLayer.AbsoluteSize
	local layerAspect = (size.Y > 0) and size.X / size.Y or 1
	local worldAspect = rangeX / rangeZ
	local spanX, spanZ = 1, 1
	if worldAspect > layerAspect then
		spanZ = layerAspect / worldAspect
	else
		spanX = worldAspect / layerAspect
	end

	return function(x, z)
		return UDim2.fromScale(
			0.5 + (x - centerX) / rangeX * spanX,
			0.5 + (z - centerZ) / rangeZ * spanZ
		)
	end
end

local function clampPosition(position)
	return UDim2.fromScale(math.clamp(position.X.Scale, 0, 1), math.clamp(position.Y.Scale, 0, 1))
end

-- ═══════════════════════════════════════════
-- Seleção / detalhes
-- ═══════════════════════════════════════════
local function distanceTo(dest)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local d = Vector2.new(root.Position.X - dest.x, root.Position.Z - dest.z).Magnitude
	return math.floor(d * STUDS_TO_METERS + 0.5)
end

local function selectDestination(dest)
	selected = dest
	for id, pin in pairs(pins) do
		local isSelected = dest and id == dest.id
		TweenService:Create(pin.scale, TweenInfo.new(0.15), { Scale = isSelected and 1.25 or 1 }):Play()
		pin.button.ZIndex = isSelected and 5 or 4
	end

	if not dest then
		detailIcon.Text = "🗺️"
		detailName.Text = "Escolha um local"
		detailDescription.Text = "Toque em um ponto do mapa para ver os detalhes."
		detailDistance.Text = ""
		detailsStroke.Color = Colors.Panel
		detailsGradient.Color = ColorSequence.new(Colors.White, Colors.White)
		setGoStyle("IR!", Colors.Gray, false)
		return
	end

	local color = KIND_COLORS[dest.kind] or Colors.Panel
	detailIcon.Text = dest.icon
	detailName.Text = dest.name
	detailNameStroke.Color = Theme.Darken(color, 0.3)
	detailDescription.Text = dest.description ~= "" and dest.description or " "
	detailsStroke.Color = color
	detailsGradient.Color = ColorSequence.new(Colors.White, color:Lerp(Colors.White, 0.7))

	local meters = distanceTo(dest)
	detailDistance.Text = meters and ("📍 ~" .. meters .. " m daqui") or ""
	setGoStyle("IR!", dest.kind == "home" and Colors.Blue or Colors.Green, true)
end

-- ═══════════════════════════════════════════
-- Pins
-- ═══════════════════════════════════════════
local function clearPins()
	for _, pin in pairs(pins) do
		pin.button:Destroy()
	end
	pins = {}
end

local function createPin(dest)
	local color = KIND_COLORS[dest.kind] or Colors.Panel
	local button = new("TextButton", {
		Name = dest.id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.13, 0.13),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = Colors.White,
		AutoButtonColor = false,
		Font = Theme.Font,
		Text = dest.icon,
		TextScaled = true,
		ZIndex = 4,
		Parent = pinLayer,
	}, {
		Components.corner(999),
		new("UIPadding", {
			PaddingTop = UDim.new(0.18, 0),
			PaddingBottom = UDim.new(0.18, 0),
			PaddingLeft = UDim.new(0.18, 0),
			PaddingRight = UDim.new(0.18, 0),
		}),
	})
	local stroke = Components.stroke(color, 3)
	stroke.Parent = button

	local caption = Components.label({
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromScale(3, 0.55),
		Text = dest.name,
		ZIndex = 4,
		Parent = button,
	})
	Components.stroke(Theme.Darken(color, 0.35), 2, Enum.ApplyStrokeMode.Contextual).Parent = caption

	local scale = new("UIScale", { Parent = button })
	button.MouseButton1Click:Connect(function()
		popSound:Play()
		selectDestination(dest)
	end)

	pins[dest.id] = { button = button, stroke = stroke, scale = scale }
end

local function layoutPins()
	projection = buildProjection()
	if not projection then return end
	for _, dest in ipairs(destinations) do
		local pin = pins[dest.id]
		if pin then
			pin.button.Position = clampPosition(projection(dest.x, dest.z))
		end
	end
end

pinLayer:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutPins)

local function loadDestinations()
	local ok, result = pcall(function()
		return GetDestinations:InvokeServer()
	end)
	if not ok or type(result) ~= "table" then
		warn("[Map] Erro ao carregar destinos:", result)
		return
	end

	local previousId = selected and selected.id
	destinations = result
	clearPins()
	for _, dest in ipairs(destinations) do
		createPin(dest)
	end
	layoutPins()

	local keep = nil
	for _, dest in ipairs(destinations) do
		if dest.id == previousId then keep = dest end
	end
	selectDestination(keep)
end

-- Marcador "VOCÊ" acompanha o personagem enquanto o mapa está aberto
local markerAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	if not isOpen() then return end
	markerAccumulator += dt
	if markerAccumulator < 0.2 then return end
	markerAccumulator = 0

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and projection then
		youMarker.Position = clampPosition(projection(root.Position.X, root.Position.Z))
		youMarker.Visible = true
	else
		youMarker.Visible = false
	end
	if selected then
		local meters = distanceTo(selected)
		detailDistance.Text = meters and ("📍 ~" .. meters .. " m daqui") or ""
	end
end)

-- ═══════════════════════════════════════════
-- Abrir / fechar
-- ═══════════════════════════════════════════
local openScale = new("UIScale", { Parent = mainFrame })

local function setOpen(open)
	if open == isOpen() then return end
	gui.Enabled = open
	mainFrame.Visible = open
	setCameraEffects(open)

	if open then
		openScale.Scale = 0.9
		TweenService:Create(openScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		task.spawn(loadDestinations)
	end
end

panel.CloseButton.MouseButton1Click:Connect(function()
	popSound:Play()
	setOpen(false)
end)

-- O MapButton fica na HudGui (ResetOnSpawn), então pode ser recriado a cada respawn
local function bindMapButton(button)
	if not button:IsA("GuiButton") or button:GetAttribute("MapBound") then return end
	button:SetAttribute("MapBound", true)
	button.MouseButton1Click:Connect(function()
		setOpen(not isOpen())
	end)
end

for _, descendant in ipairs(playerGui:GetDescendants()) do
	if descendant.Name == "MapButton" then bindMapButton(descendant) end
end
playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "MapButton" then bindMapButton(descendant) end
end)

-- ═══════════════════════════════════════════
-- Teleporte
-- ═══════════════════════════════════════════
goButton.MouseButton1Click:Connect(function()
	if teleporting or not selected then return end
	teleporting = true
	local dest = selected
	setGoStyle("...", Colors.Gray, false)

	fade(true, 0.25)
	local ok, success, reason = pcall(function()
		return TeleportTo:InvokeServer(dest.id)
	end)

	if ok and success then
		setOpen(false)
		task.wait(0.35) -- dá tempo do mundo carregar em volta antes de revelar
		fade(false, 0.4)
	else
		fade(false, 0.2)
		local message = (ok and reason) or "Erro"
		setGoStyle(message, Colors.Red, false)
		task.wait(1.5)
	end

	teleporting = false
	selectDestination(selected)
end)
