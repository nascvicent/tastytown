--[[
	Componentes de UI reutilizáveis no estilo do Shop.
	Usados pelo Inventário e pelo Mapa (e futuramente pelo próprio Shop).
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local Colors = Theme.Colors

local Components = {}

local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ═══════════════════════════════════════════
-- Helpers básicos
-- ═══════════════════════════════════════════

-- Cria uma instância com propriedades e filhos. Parent é aplicado por último.
function Components.new(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local new = Components.new

function Components.corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Components.stroke(color, thickness, mode)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
	})
end

function Components.padding(scale)
	local s = UDim.new(scale or 0.03, 0)
	return new("UIPadding", { PaddingTop = s, PaddingBottom = s, PaddingLeft = s, PaddingRight = s })
end

function Components.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Colors.White,
		TextScaled = true,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return new("TextLabel", defaults)
end

-- Efeito de hover/clique por UIScale (não mexe no Size, então não quebra layouts)
function Components.hoverScale(button, amount)
	local scale = button:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = button })
	local hovered = false
	local function to(value)
		TweenService:Create(scale, QUICK, { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		hovered = true
		to(1 + (amount or 0.06))
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		to(1)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.94)
	end)
	button.MouseButton1Up:Connect(function()
		to(hovered and 1 + (amount or 0.06) or 1)
	end)
	return scale
end

-- ═══════════════════════════════════════════
-- Janela padrão (cabeçalho + abas + páginas + X)
-- ═══════════════════════════════════════════
--[[
	params:
		Parent: ScreenGui
		Name: nome do frame principal (default "MainFrame")
		Title: texto do cabeçalho
		HasTabs: se true, cria a coluna de abas à esquerda
		AspectRatio: proporção largura/altura (default 1.7)
	retorna { Frame, Tabs, Page, CloseButton, Title }
]]
function Components.Panel(params)
	local frame = new("Frame", {
		Name = params.Name or "MainFrame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.72, 0.72),
		BackgroundColor3 = Colors.Panel,
		Visible = false,
		Parent = params.Parent,
	}, {
		Components.corner(Theme.Radius.Panel),
		Components.stroke(Colors.PanelStroke, 4),
		new("UIAspectRatioConstraint", { AspectRatio = params.AspectRatio or 1.7 }),
		new("UISizeConstraint", { MaxSize = Vector2.new(980, 580), MinSize = Vector2.new(320, 190) }),
	})

	-- Cabeçalho: faixa marrom com cantos de cima arredondados
	-- (cor opaca já misturada: com transparência, a sobreposição com o tapa-cantos ficaria mais escura)
	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.fromScale(1, 0.14),
		BackgroundColor3 = Colors.HeaderSolid,
		Parent = frame,
	}, {
		Components.corner(Theme.Radius.Panel),
	})
	-- Tapa os cantos de baixo do cabeçalho para ficarem retos
	new("Frame", {
		Name = "SquareBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = Colors.HeaderSolid,
		BorderSizePixel = 0,
		Parent = header,
	})

	local title = Components.label({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.78),
		Text = params.Title or "",
		ZIndex = 2,
		Parent = header,
	})
	Components.stroke(Colors.Header, 3, Enum.ApplyStrokeMode.Contextual).Parent = title

	-- Botão X (mesma imagem do Shop), quadrado proporcional à altura da janela
	local closeButton = new("ImageButton", {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromScale(0.16, 0.16),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		Image = Theme.Images.Close,
		ZIndex = 10,
		Parent = frame,
	})
	Components.hoverScale(closeButton, 0.1)

	-- Corpo
	local body = new("Frame", {
		Name = "Body",
		Position = UDim2.fromScale(0, 0.14),
		Size = UDim2.fromScale(1, 0.86),
		BackgroundTransparency = 1,
		Parent = frame,
	}, {
		Components.padding(0.035),
	})

	local tabs = nil
	if params.HasTabs then
		tabs = new("Frame", {
			Name = "Tabs",
			Size = UDim2.fromScale(0.16, 1),
			BackgroundTransparency = 1,
			Parent = body,
		}, {
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.04, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end

	local page = new("Frame", {
		Name = "Page",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(params.HasTabs and 0.82 or 1, 1),
		BackgroundColor3 = Colors.Page,
		BackgroundTransparency = Theme.Transparency.Page,
		-- Sem ClipsDescendants aqui: recorte arredondado (UICorner) em um ancestral impede
		-- ViewportFrames de renderizar. Quem rola (ScrollingFrame) já recorta o conteúdo.
		ClipsDescendants = false,
		Parent = body,
	}, {
		Components.corner(Theme.Radius.Page),
	})

	return {
		Frame = frame,
		Tabs = tabs,
		Page = page,
		CloseButton = closeButton,
		Title = title,
	}
end

-- ═══════════════════════════════════════════
-- Aba lateral (ícone + legenda dentro de um quadrado)
-- ═══════════════════════════════════════════
function Components.TabTile(parent, params)
	local tile = new("TextButton", {
		Name = params.Name or "Tab",
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = params.LayoutOrder or 0,
		Size = UDim2.fromScale(0.86, 0.86),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundColor3 = Colors.Tile,
		Parent = parent,
	}, {
		Components.corner(Theme.Radius.Tile),
	})
	local stroke = Components.stroke(Colors.White, 3)
	stroke.Parent = tile

	new("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundTransparency = 1,
		Image = params.Image or "",
		ScaleType = Enum.ScaleType.Fit,
		Parent = tile,
	})

	local caption = Components.label({
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.9, 0.24),
		Text = params.Label or "",
		Parent = tile,
	})
	Components.stroke(Theme.Darken(Colors.Tile, 0.35), 2, Enum.ApplyStrokeMode.Contextual).Parent = caption

	local scale = Components.hoverScale(tile, 0.05)

	local function setSelected(selected)
		TweenService:Create(tile, QUICK, {
			BackgroundColor3 = selected and Colors.TileSelected or Colors.Tile,
		}):Play()
		TweenService:Create(stroke, QUICK, {
			Color = selected and Colors.TileSelectedStroke or Colors.White,
			Thickness = selected and 4 or 3,
		}):Play()
		TweenService:Create(scale, QUICK, { Scale = selected and 1.06 or 1 }):Play()
	end

	return tile, setSelected
end

-- ═══════════════════════════════════════════
-- Grade rolável de cards
-- ═══════════════════════════════════════════
function Components.Grid(parent, params)
	params = params or {}
	local scroll = new("ScrollingFrame", {
		Name = params.Name or "Grid",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Colors.White,
		ScrollBarImageTransparency = 0.3,
		Parent = parent,
	}, {
		new("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 16),
		}),
	})

	local columns = params.Columns or 3
	local aspect = params.CellAspect or 0.72 -- largura / altura
	local gap = 14
	local layout = new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(gap, gap),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})

	-- Tamanho da célula em pixels a partir da largura útil (12 + 16 de padding e a barra de rolagem).
	-- Não usar UIAspectRatioConstraint no layout: ele encolhe a célula para caber no CellSize.
	local function updateCells()
		local usable = scroll.AbsoluteSize.X - 28 - scroll.ScrollBarThickness
		local width = math.max(math.floor((usable - gap * (columns - 1)) / columns), 60)
		layout.CellSize = UDim2.fromOffset(width, math.floor(width / aspect))
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCells)
	updateCells()

	return scroll
end

-- ═══════════════════════════════════════════
-- Card no estilo do Shop (gradiente + borda + tag de raridade)
-- ═══════════════════════════════════════════
function Components.ItemCard(parent, params)
	local rarity = Theme.GetRarity(params.Rarity)
	local color = rarity.Color

	local card = new("Frame", {
		Name = params.Name or "Card",
		LayoutOrder = params.LayoutOrder or 0,
		BackgroundColor3 = Colors.White,
		Parent = parent,
	}, {
		Components.corner(Theme.Radius.Card),
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Colors.White, color:Lerp(Colors.White, 0.7)),
		}),
	})
	local stroke = Components.stroke(color, 3)
	stroke.Parent = card

	Components.label({
		Name = "RarityTag",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.035),
		Size = UDim2.fromScale(0.6, 0.08),
		Text = rarity.Title,
		TextColor3 = color,
		ZIndex = 3,
		Parent = card,
	})

	-- Com subtítulo (ex.: preço) o nome sobe um pouco para caber as duas linhas
	local hasSubtitle = params.Subtitle ~= nil
	local nameLabel = Components.label({
		Name = "NameLabel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, hasSubtitle and 0.545 or 0.6),
		Size = UDim2.fromScale(0.9, hasSubtitle and 0.1 or 0.13),
		Text = params.Title or "",
		ZIndex = 3,
		Parent = card,
	})
	Components.stroke(Theme.Darken(color, 0.15), 2, Enum.ApplyStrokeMode.Contextual).Parent = nameLabel

	if hasSubtitle then
		local subtitle = Components.label({
			Name = "Subtitle",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.65),
			Size = UDim2.fromScale(0.7, 0.085),
			Text = params.Subtitle,
			TextColor3 = Theme.Rarity.Legendary.Color,
			ZIndex = 3,
			Parent = card,
		})
		Components.stroke(Theme.Darken(Theme.Rarity.Legendary.Color, 0.45), 2, Enum.ApplyStrokeMode.Contextual).Parent = subtitle
	end

	return card, color, stroke
end

-- Área de preview dentro do card (onde vai o viewport/ícone).
-- compact = true quando o card tem subtítulo.
function Components.CardPreview(card, compact)
	return new("Frame", {
		Name = "Preview",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.fromScale(0.88, compact and 0.42 or 0.47),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = card,
	})
end

-- Botão circular "i" no canto do card
function Components.InfoButton(card, color)
	local button = new("TextButton", {
		Name = "InfoButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.95, 0.025),
		Size = UDim2.fromScale(0.15, 0.15),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Font = Theme.Font,
		Text = "i",
		TextColor3 = Colors.White,
		TextScaled = true,
		ZIndex = 6,
		Parent = card,
	}, {
		Components.corner(999),
		new("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0) }),
	})
	Components.stroke(Colors.White, 2).Parent = button
	Components.hoverScale(button, 0.12)
	return button
end

-- Popup de informações (fundo escurecido + card central), como o do Shop
function Components.InfoPopup(container, params)
	local color = params.Color or Colors.Panel
	local overlay = new("TextButton", {
		Name = "PopupOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.Black,
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 100,
		Parent = container,
	}, {
		Components.corner(Theme.Radius.Panel),
	})

	local popup = new("Frame", {
		Name = "Popup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.78),
		BackgroundColor3 = Colors.White,
		ZIndex = 101,
		Parent = overlay,
	}, {
		Components.corner(15),
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Colors.White, color:Lerp(Colors.White, 0.75)),
		}),
	})
	Components.stroke(color, 4).Parent = popup
	local scale = new("UIScale", { Scale = 0.6, Parent = popup })

	local title = Components.label({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(0.9, 0.14),
		Text = params.Title or "",
		TextColor3 = color,
		ZIndex = 102,
		Parent = popup,
	})
	Components.stroke(Theme.Darken(color, 0.4), 2, Enum.ApplyStrokeMode.Contextual).Parent = title

	local description = Components.label({
		Name = "Description",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromScale(0.86, 0.56),
		Text = params.Description or "Sem descrição disponível.",
		Font = Theme.BodyFont,
		TextColor3 = Colors.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 102,
		Parent = popup,
	})
	new("UITextSizeConstraint", { MaxTextSize = 18, Parent = description })

	local closeButton = Components.ActionButton(popup, {
		Name = "CloseButton",
		Text = "FECHAR",
		Color = color,
		Size = UDim2.fromScale(0.42, 0.13),
		Position = UDim2.fromScale(0.5, 0.95),
	})
	closeButton.ZIndex = 103

	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local closing = false
	local function close()
		if closing then return end
		closing = true
		local tween = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.6 })
		tween.Completed:Connect(function()
			overlay:Destroy()
		end)
		tween:Play()
	end
	closeButton.MouseButton1Click:Connect(close)
	overlay.MouseButton1Click:Connect(close)

	return overlay, close
end

-- Brilho passando pelo botão de tempos em tempos (itens VIP)
function Components.Shine(button)
	button.ClipsDescendants = true
	local shine = new("Frame", {
		Name = "Shine",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.3, 0.5),
		Size = UDim2.fromScale(0.25, 2),
		Rotation = 20,
		BackgroundColor3 = Colors.White,
		BorderSizePixel = 0,
		ZIndex = button.ZIndex + 1,
		Parent = button,
	}, {
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	task.spawn(function()
		while shine.Parent do
			shine.Position = UDim2.fromScale(-0.3, 0.5)
			local tween = TweenService:Create(shine, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {
				Position = UDim2.fromScale(1.3, 0.5),
			})
			tween:Play()
			tween.Completed:Wait()
			task.wait(2)
		end
	end)
	return shine
end

-- ═══════════════════════════════════════════
-- Botão de ação (COMPRAR / EQUIPAR / IR)
-- ═══════════════════════════════════════════
function Components.ActionButton(parent, params)
	local color = params.Color or Colors.Green
	local button = new("TextButton", {
		Name = params.Name or "ActionButton",
		AnchorPoint = params.AnchorPoint or Vector2.new(0.5, 1),
		Position = params.Position or UDim2.fromScale(0.5, 0.95),
		Size = params.Size or UDim2.fromScale(0.88, 0.18),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Font = Theme.Font,
		Text = params.Text or "",
		TextColor3 = Colors.White,
		TextScaled = true,
		ZIndex = 4,
		Parent = parent,
	}, {
		Components.corner(Theme.Radius.Button),
		new("UIPadding", {
			PaddingTop = UDim.new(0.12, 0),
			PaddingBottom = UDim.new(0.12, 0),
			PaddingLeft = UDim.new(0.06, 0),
			PaddingRight = UDim.new(0.06, 0),
		}),
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Colors.White, Color3.fromRGB(215, 215, 215)),
		}),
	})
	local stroke = Components.stroke(Theme.Darken(color), 2)
	stroke.Parent = button
	Components.hoverScale(button, 0.04)

	local function setStyle(text, newColor, enabled)
		button.Text = text
		button.BackgroundColor3 = newColor
		stroke.Color = Theme.Darken(newColor)
		button.Active = enabled ~= false
		button.AutoButtonColor = false
	end

	return button, setStyle
end

-- ═══════════════════════════════════════════
-- Viewport 3D girando (mesma lógica do Shop)
-- ═══════════════════════════════════════════
local DEFAULT_CAMERA = {
	offsetY = 0,
	distanceMultiplier = 0.7,
	cameraHeight = 0.7,
	cameraAngleX = 0,
	lookAtOffsetY = 0,
}

-- isActive(): retorna false quando a janela está fechada, para não gastar frames à toa
function Components.Viewport(parent, model, cameraConfig, isActive)
	local viewport = new("ViewportFrame", {
		Name = "Viewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = parent,
	})
	local worldModel = new("WorldModel", { Parent = viewport })
	local camera = new("Camera", { Parent = viewport })
	viewport.CurrentCamera = camera

	local clone = model:Clone()
	-- Modelos como os carros A-Chassis carregam scripts; nunca deixar rodarem na UI
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end
	clone.Parent = worldModel

	local config = cameraConfig or DEFAULT_CAMERA
	local currentCFrame, size = clone:GetBoundingBox()
	clone:PivotTo(CFrame.new(0, config.offsetY or 0, 0) * currentCFrame.Rotation)

	local maxSize = math.max(size.X, size.Y, size.Z)
	local distance = maxSize * (config.distanceMultiplier or 0.7)
	local basePos = Vector3.new(distance, distance * (config.cameraHeight or 0.7), distance)
	local lookAt = Vector3.new(0, config.lookAtOffsetY or 0, 0)
	local tilt = CFrame.Angles(config.cameraAngleX or 0, 0, 0)

	local angle = math.rad(35)
	local function place()
		local pos = (CFrame.Angles(0, angle, 0) * tilt):PointToWorldSpace(basePos)
		camera.CFrame = CFrame.lookAt(pos, lookAt)
	end
	place()

	local connection = RunService.RenderStepped:Connect(function(dt)
		if isActive and not isActive() then return end
		angle += dt * 0.8
		place()
	end)
	viewport.Destroying:Connect(function()
		connection:Disconnect()
	end)

	return viewport
end

-- ═══════════════════════════════════════════
-- Estado vazio
-- ═══════════════════════════════════════════
function Components.EmptyState(parent, title, subtitle)
	local holder = new("Frame", {
		Name = "EmptyState",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.4),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local titleLabel = Components.label({
		Size = UDim2.fromScale(1, 0.45),
		Text = title,
		Parent = holder,
	})
	Components.stroke(Colors.Header, 2, Enum.ApplyStrokeMode.Contextual).Parent = titleLabel
	Components.label({
		Position = UDim2.fromScale(0, 0.55),
		Size = UDim2.fromScale(1, 0.3),
		Text = subtitle or "",
		Font = Theme.BodyFont,
		TextColor3 = Colors.White,
		TextTransparency = 0.1,
		Parent = holder,
	})
	return holder
end

-- ═══════════════════════════════════════════
-- Efeitos de câmera ao abrir janela (igual ao Shop/Inventário: FOV + blur)
-- ═══════════════════════════════════════════
function Components.CameraEffects(blurName)
	local camera = workspace.CurrentCamera
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local originalFOV = camera.FieldOfView

	local blur = camera:FindFirstChild(blurName) or new("BlurEffect", { Name = blurName, Size = 0, Enabled = false })
	blur.Parent = camera

	local isOn = false
	return function(on)
		if on == isOn then return end
		isOn = on
		if on then
			originalFOV = camera.FieldOfView
			blur.Enabled = true
			TweenService:Create(camera, info, { FieldOfView = 60 }):Play()
			TweenService:Create(blur, info, { Size = 15 }):Play()
		else
			TweenService:Create(camera, info, { FieldOfView = originalFOV }):Play()
			local tween = TweenService:Create(blur, info, { Size = 0 })
			tween.Completed:Connect(function()
				if not isOn then blur.Enabled = false end
			end)
			tween:Play()
		end
	end
end

-- ═══════════════════════════════════════════
-- Fade de tela inteira (transição do teleporte)
-- ═══════════════════════════════════════════
function Components.ScreenFade(playerGui)
	local gui = playerGui:FindFirstChild("ScreenFade") or new("ScreenGui", {
		Name = "ScreenFade",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
		Parent = playerGui,
	})
	local frame = gui:FindFirstChild("Fade") or new("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 223, 240), -- mesmo rosa do loading
		BackgroundTransparency = 1,
		Active = false,
		Parent = gui,
	})

	return function(visible, duration)
		local tween = TweenService:Create(frame, TweenInfo.new(duration or 0.3), {
			BackgroundTransparency = visible and 0 or 1,
		})
		tween:Play()
		tween.Completed:Wait()
	end
end

return Components
