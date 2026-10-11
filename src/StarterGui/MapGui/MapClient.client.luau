--[[
	Mapa (cliente) — miniatura 3D da cidade com etiquetas de UI.

	• A cidade vem de ReplicatedStorage.MapMiniature (montada pelo MapService)
	  e é desenhada num ViewportFrame; arrastar gira a vista.
	• As etiquetas são UI comum, posicionadas projetando o ponto 3D na câmera.
	• O card da direita mostra o destino girando em 3D, como os cards do Shop.
	Abre pelo MapButton da HudGui e teleporta dentro do place (validação no servidor).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
local CAMERA = MapConfig.Camera

-- Cor de destaque de cada tipo de destino (etiqueta e borda do card)
local KIND_COLORS = {
	spawn = Theme.Rarity.Legendary.Color,
	building = Color3.fromRGB(235, 125, 80),
	extra = Color3.fromRGB(90, 170, 235),
	custom = Color3.fromRGB(200, 120, 220),
	home = Colors.MapHome,
}

-- Ícone do card quando o destino não tem modelo na miniatura
local FALLBACK_IMAGES = {
	home = Theme.Images.House,
	spawn = Theme.Images.Tag,
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

-- Moldura da miniatura (esquerda). Sem ClipsDescendants: recorte arredondado
-- impede o ViewportFrame de renderizar; o próprio viewport já recorta o 3D.
local canvas = new("Frame", {
	Name = "MapCanvas",
	Size = UDim2.fromScale(0.63, 1),
	BackgroundTransparency = 1,
	Parent = page,
})

local viewport = new("ViewportFrame", {
	Name = "City",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Colors.MapGround,
	Ambient = Color3.fromRGB(175, 175, 175),
	LightColor = Color3.fromRGB(255, 250, 240),
	LightDirection = Vector3.new(-0.6, -1, -0.4),
	Active = true,
	Parent = canvas,
}, {
	Components.corner(Theme.Radius.Page),
})
-- Borda branca por cima do viewport
new("Frame", {
	Name = "Border",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 8,
	Parent = canvas,
}, {
	Components.corner(Theme.Radius.Page),
	Components.stroke(Colors.White, 3),
})

local worldModel = new("WorldModel", { Parent = viewport })
local camera = new("Camera", { FieldOfView = CAMERA.FieldOfView, Parent = viewport })
viewport.CurrentCamera = camera

local loadingLabel = Components.label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.6, 0.1),
	Text = "Carregando a cidade...",
	ZIndex = 9,
	Parent = canvas,
})
Components.stroke(Colors.Header, 2, Enum.ApplyStrokeMode.Contextual).Parent = loadingLabel

-- Camada das etiquetas, alinhada ao viewport
local labelLayer = new("Frame", {
	Name = "Labels",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = canvas,
})

-- Botão "VER TUDO" (volta à visão geral)
local overviewButton = Components.ActionButton(canvas, {
	Name = "Overview",
	Text = "VER TUDO",
	Color = Colors.Header,
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromScale(0.03, 0.04),
	Size = UDim2.fromScale(0.26, 0.09),
})
overviewButton.ZIndex = 9
overviewButton.Visible = false

local hint = Components.label({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.97),
	Size = UDim2.fromScale(0.7, 0.06),
	Text = "Arraste para girar • Toque num local",
	TextTransparency = 0.15,
	ZIndex = 9,
	Parent = canvas,
})
Components.stroke(Colors.Header, 1.5, Enum.ApplyStrokeMode.Contextual).Parent = hint

-- ═══════════════════════════════════════════
-- Card de detalhes (direita), no estilo dos cards do Shop
-- ═══════════════════════════════════════════
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
local detailsStroke = Components.stroke(Colors.PanelStroke, 3)
detailsStroke.Parent = details

local kindLabel = Components.label({
	Name = "Kind",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.03),
	Size = UDim2.fromScale(0.6, 0.065),
	Text = "MAPA",
	TextColor3 = Colors.PanelStroke,
	ZIndex = 3,
	Parent = details,
})

local previewHolder = new("Frame", {
	Name = "Preview",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.1),
	Size = UDim2.fromScale(0.9, 0.36),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = details,
})

local detailName = Components.label({
	Name = "Name",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromScale(0.9, 0.1),
	Text = "Escolha um local",
	ZIndex = 3,
	Parent = details,
})
local detailNameStroke = Components.stroke(Colors.Header, 2, Enum.ApplyStrokeMode.Contextual)
detailNameStroke.Parent = detailName

local detailDescription = Components.label({
	Name = "Description",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.585),
	Size = UDim2.fromScale(0.88, 0.14),
	Text = "Toque numa etiqueta do mapa para ver os detalhes.",
	Font = Theme.BodyFont,
	TextColor3 = Colors.Text,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 3,
	Parent = details,
})
new("UITextSizeConstraint", { MaxTextSize = 16, Parent = detailDescription })

local detailDistance = Components.label({
	Name = "Distance",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.735),
	Size = UDim2.fromScale(0.7, 0.055),
	Text = "",
	TextColor3 = Colors.TextSoft,
	ZIndex = 3,
	Parent = details,
})

local goButton, setGoStyle = Components.ActionButton(details, {
	Name = "GoButton",
	Size = UDim2.fromScale(0.86, 0.14),
	Position = UDim2.fromScale(0.5, 0.96),
})
setGoStyle("IR!", Colors.Gray, false)

-- ═══════════════════════════════════════════
-- Estado
-- ═══════════════════════════════════════════
local destinations = {}
local labels = {} -- [id] = { holder, pill, stem, stroke, scale, dest }
local selected = nil
local teleporting = false
local cityBuilt = false
local cityModel = nil

-- Câmera: foco/distância atuais e alvo (interpolados a cada frame)
local overviewFocus, overviewDistance = Vector3.zero, 300
local focus, distance = Vector3.zero, 300
local targetFocus, targetDistance = Vector3.zero, 300
local yaw = math.rad(CAMERA.Yaw)
local pitch = math.rad(CAMERA.Pitch)

local fade = Components.ScreenFade(playerGui)
local setCameraEffects = Components.CameraEffects("MapBlur")

local function isOpen()
	return gui.Enabled and mainFrame.Visible
end

-- ═══════════════════════════════════════════
-- Miniatura 3D
-- ═══════════════════════════════════════════
local function buildCity()
	if cityBuilt then return true end
	local source = ReplicatedStorage:WaitForChild("MapMiniature", 15)
	if not source then
		loadingLabel.Text = "Mapa indisponível"
		return false
	end

	cityModel = new("Model", { Name = "City" })
	for _, child in ipairs(source:GetChildren()) do
		child:Clone().Parent = cityModel
	end
	cityModel.Parent = worldModel

	-- Chão verde sob a cidade (o terreno não aparece em ViewportFrame)
	local cf, size = cityModel:GetBoundingBox()
	new("Part", {
		Name = "Ground",
		Anchored = true,
		Size = Vector3.new(size.X + 120, 1, size.Z + 120),
		CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 - 0.6, cf.Position.Z),
		Color = Colors.MapGround,
		Material = Enum.Material.SmoothPlastic,
		Parent = worldModel,
	})

	-- Enquadramento da visão geral: cabe a cidade inteira na vertical do FOV
	overviewFocus = cf.Position
	local radius = math.max(size.X, size.Z) / 2
	overviewDistance = radius / math.tan(math.rad(CAMERA.FieldOfView) / 2) * 0.95
	focus, distance = overviewFocus, overviewDistance * 1.25 -- entra com um leve zoom
	targetFocus, targetDistance = overviewFocus, overviewDistance

	cityBuilt = true
	loadingLabel.Visible = false
	return true
end

local function cameraCFrame()
	return CFrame.new(focus)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(-pitch, 0, 0)
		* CFrame.new(0, 0, distance)
end

-- Projeta um ponto 3D na tela do viewport (escala 0..1); nil se atrás da câmera
local function project(worldPos)
	local p = camera.CFrame:PointToObjectSpace(worldPos)
	if p.Z >= 0 then return nil end
	local size = viewport.AbsoluteSize
	if size.Y <= 0 then return nil end
	local tanY = math.tan(math.rad(camera.FieldOfView) / 2)
	local aspect = size.X / size.Y
	local x = (p.X / -p.Z) / (tanY * aspect)
	local y = (p.Y / -p.Z) / tanY
	return 0.5 + x / 2, 0.5 - y / 2
end

-- ═══════════════════════════════════════════
-- Etiquetas (UI presa aos pontos 3D)
-- ═══════════════════════════════════════════
local function clearLabels()
	for _, label in pairs(labels) do
		label.holder:Destroy()
	end
	labels = {}
end

local function styleLabel(label, isSelected)
	local color = KIND_COLORS[label.dest.kind] or Colors.PanelStroke
	label.pill.BackgroundColor3 = isSelected and color or Colors.White
	label.stem.BackgroundColor3 = isSelected and color or Colors.White
	label.pill.TextColor3 = isSelected and Colors.White or Theme.Darken(color, 0.25)
	label.holder.ZIndex = isSelected and 7 or 6
	TweenService:Create(label.scale, TweenInfo.new(0.15), { Scale = isSelected and 1.15 or 1 }):Play()
end

local selectDestination -- declarado abaixo

local function createLabel(dest)
	local color = KIND_COLORS[dest.kind] or Colors.PanelStroke

	-- holder: ponto de ancoragem (base da haste) na posição projetada
	local holder = new("Frame", {
		Name = dest.id,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = labelLayer,
	})
	local scale = new("UIScale", { Parent = holder })

	local stem = new("Frame", {
		Name = "Stem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -7),
		Size = UDim2.fromOffset(11, 11),
		Rotation = 45,
		BackgroundColor3 = Colors.White,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = holder,
	})
	Components.stroke(color, 2).Parent = stem

	local pill = new("TextButton", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -10),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Colors.White,
		AutoButtonColor = false,
		Font = Theme.Font,
		Text = dest.name,
		TextSize = 15,
		TextColor3 = Theme.Darken(color, 0.25),
		ZIndex = 7,
		Parent = holder,
	}, {
		Components.corner(999),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	local stroke = Components.stroke(color, 2.5)
	stroke.Parent = pill

	pill.MouseButton1Click:Connect(function()
		popSound:Play()
		selectDestination(dest)
	end)

	labels[dest.id] = { holder = holder, pill = pill, stem = stem, stroke = stroke, scale = scale, dest = dest }
end

-- "VOCÊ": bolinha rosa na posição do personagem
local youMarker = new("Frame", {
	Name = "You",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(14, 14),
	BackgroundColor3 = Colors.MapYou,
	Visible = false,
	ZIndex = 6,
	Parent = labelLayer,
}, {
	Components.corner(999),
	Components.stroke(Colors.White, 2),
})
local youLabel = Components.label({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -3),
	Size = UDim2.fromOffset(60, 18),
	Text = "VOCÊ",
	TextColor3 = Colors.MapYou,
	ZIndex = 6,
	Parent = youMarker,
})
Components.stroke(Colors.White, 2, Enum.ApplyStrokeMode.Contextual).Parent = youLabel

-- ═══════════════════════════════════════════
-- Detalhes
-- ═══════════════════════════════════════════
local function distanceTo(dest)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local d = Vector2.new(root.Position.X - dest.x, root.Position.Z - dest.z).Magnitude
	return math.floor(d * STUDS_TO_METERS + 0.5)
end

local function findMiniatureModel(id)
	local source = ReplicatedStorage:FindFirstChild("MapMiniature")
	if not source then return nil end
	for _, child in ipairs(source:GetChildren()) do
		if child:GetAttribute("DestinationId") == id and child:IsA("Model") then
			return child
		end
	end
	return nil
end

local function showPreview(dest)
	previewHolder:ClearAllChildren()
	if not dest then return end

	local model = findMiniatureModel(dest.id)
	if model then
		Components.Viewport(previewHolder, model, {
			distanceMultiplier = 0.75,
			cameraHeight = 0.55,
		}, isOpen)
	else
		new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.75, 0.75),
			BackgroundTransparency = 1,
			Image = FALLBACK_IMAGES[dest.kind] or Theme.Images.House,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
			Parent = previewHolder,
		})
	end
end

selectDestination = function(dest)
	selected = dest
	for id, label in pairs(labels) do
		styleLabel(label, dest ~= nil and id == dest.id)
	end
	showPreview(dest)

	if not dest then
		kindLabel.Text = "MAPA"
		kindLabel.TextColor3 = Colors.PanelStroke
		detailName.Text = "Escolha um local"
		detailDescription.Text = "Toque numa etiqueta do mapa para ver os detalhes."
		detailDistance.Text = ""
		detailsStroke.Color = Colors.PanelStroke
		detailsGradient.Color = ColorSequence.new(Colors.White, Colors.White)
		setGoStyle("IR!", Colors.Gray, false)
		targetFocus, targetDistance = overviewFocus, overviewDistance
		overviewButton.Visible = false
		return
	end

	local color = KIND_COLORS[dest.kind] or Colors.PanelStroke
	kindLabel.Text = MapConfig.KindLabels[dest.kind] or "LOCAL"
	kindLabel.TextColor3 = color
	detailName.Text = dest.name
	detailNameStroke.Color = Theme.Darken(color, 0.3)
	detailDescription.Text = dest.description ~= "" and dest.description or " "
	detailsStroke.Color = color
	detailsGradient.Color = ColorSequence.new(Colors.White, color:Lerp(Colors.White, 0.7))

	local meters = distanceTo(dest)
	detailDistance.Text = meters and ("~" .. meters .. " m daqui") or ""
	setGoStyle("IR!", dest.kind == "home" and Colors.Blue or Colors.Green, true)

	-- Câmera voa até o destino
	targetFocus = Vector3.new(dest.x, (dest.y + overviewFocus.Y) / 2, dest.z)
	targetDistance = overviewDistance * CAMERA.FocusZoom
	overviewButton.Visible = true
end

overviewButton.MouseButton1Click:Connect(function()
	popSound:Play()
	selectDestination(nil)
end)

-- ═══════════════════════════════════════════
-- Dados
-- ═══════════════════════════════════════════
local function loadDestinations()
	local ok, result = pcall(function()
		return GetDestinations:InvokeServer()
	end)
	if not ok or type(result) ~= "table" or type(result.destinations) ~= "table" then
		warn("[Map] Erro ao carregar destinos:", result)
		return
	end

	local previousId = selected and selected.id
	destinations = result.destinations
	clearLabels()
	for _, dest in ipairs(destinations) do
		createLabel(dest)
	end

	local keep = nil
	for _, dest in ipairs(destinations) do
		if dest.id == previousId then keep = dest end
	end
	selectDestination(keep)
end

-- ═══════════════════════════════════════════
-- Arrastar para girar
-- ═══════════════════════════════════════════
local dragging = false
local lastDragX = 0

viewport.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		lastDragX = input.Position.X
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		yaw -= (input.Position.X - lastDragX) * 0.008
		lastDragX = input.Position.X
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

-- ═══════════════════════════════════════════
-- Loop: câmera suave + etiquetas seguindo os pontos 3D
-- ═══════════════════════════════════════════
local distanceAccumulator = 0

RunService.RenderStepped:Connect(function(dt)
	if not isOpen() or not cityBuilt then return end

	local alpha = 1 - math.exp(-dt * 6)
	focus = focus:Lerp(targetFocus, alpha)
	distance += (targetDistance - distance) * alpha
	camera.CFrame = cameraCFrame()

	for _, label in pairs(labels) do
		local dest = label.dest
		local sx, sy = project(Vector3.new(dest.x, dest.y + 2, dest.z))
		local visible = sx ~= nil and sx > -0.05 and sx < 1.05 and sy > -0.05 and sy < 1.05
		label.holder.Visible = visible
		if visible then
			label.holder.Position = UDim2.fromScale(sx, sy)
		end
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local sx, sy = nil, nil
	if root then
		sx, sy = project(root.Position)
	end
	youMarker.Visible = sx ~= nil and sx > 0 and sx < 1 and sy > 0 and sy < 1
	if youMarker.Visible then
		youMarker.Position = UDim2.fromScale(sx, sy)
	end

	distanceAccumulator += dt
	if selected and distanceAccumulator > 0.3 then
		distanceAccumulator = 0
		local meters = distanceTo(selected)
		detailDistance.Text = meters and ("~" .. meters .. " m daqui") or ""
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
		task.spawn(function()
			buildCity()
			loadDestinations()
		end)
	else
		dragging = false
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
