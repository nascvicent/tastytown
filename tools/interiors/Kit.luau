--[[
	Kit de construção de interiores (Luau com a API do Roblox).

	Recebe a API como parâmetro (rbx) para o mesmo código rodar:
	  • no Lune (require("@lune/roblox")) — gera o .rbxmx e o preview
	  • no Studio (Instance, CFrame, ... globais)

	Estilo do jogo: low-poly, SmoothPlastic, cores pastel saturadas, sem texturas.
]]

local Kit = {}
Kit.__index = Kit

-- scale: tamanho final em relação às medidas usadas no código (ex.: 0.7 para
-- personagens menores que o rig padrão). Tudo é escalado a partir da origem.
function Kit.new(rbx, scale)
	local self = setmetatable({}, Kit)
	self.rbx = rbx
	self.scale = scale or 1
	self.Instance = rbx.Instance
	self.Vector3 = rbx.Vector3
	self.CFrame = rbx.CFrame
	self.Color3 = rbx.Color3
	self.Enum = rbx.Enum
	self.UDim2 = rbx.UDim2
	self.seed = 12345
	return self
end

-- Aleatório determinístico (o mesmo layout toda vez que gerar)
function Kit:rand(min, max)
	self.seed = (self.seed * 1103515245 + 12345) % 2147483648
	local u = self.seed / 2147483648
	if min == nil then return u end
	return min + (max - min) * u
end

function Kit:pick(list)
	return list[math.floor(self:rand(1, #list + 0.999))]
end

function Kit:rgb(r, g, b)
	return self.Color3.fromRGB(r, g, b)
end

function Kit:model(name, parent)
	local m = self.Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit:folder(name, parent)
	local f = self.Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

--[[
	props:
		name, size (Vector3), cf (CFrame), color (Color3)
		class ("Part" | "WedgePart"), shape ("Block" | "Cylinder" | "Ball")
		material (Enum.Material), transparency, collide (default true), shadow
]]
function Kit:part(parent, props)
	local Enum = self.Enum
	local p = self.Instance.new(props.class or "Part")
	p.Name = props.name or "Part"
	p.Anchored = true
	-- Escala uniforme a partir da origem: posição e tamanho; a rotação não muda
	local s = self.scale
	p.Size = props.size * s
	p.CFrame = self.CFrame.new(props.cf.Position * s) * props.cf.Rotation
	p.Color = props.color or self:rgb(255, 255, 255)
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape and p:IsA("Part") then
		p.Shape = Enum.PartType[props.shape]
	end
	if props.transparency then p.Transparency = props.transparency end
	if props.collide == false then
		p.CanCollide = false
		p.CanTouch = props.touch == true
		p.CanQuery = props.touch == true
	end
	if props.shadow == false then p.CastShadow = false end
	p.Parent = parent
	return p
end

function Kit:box(parent, name, size, cf, color, extra)
	local props = extra or {}
	props.name, props.size, props.cf, props.color = name, size, cf, color
	return self:part(parent, props)
end

-- Cilindro em pé (no Roblox o eixo do cilindro é o X local)
function Kit:vcyl(parent, name, height, diameter, center, color, extra)
	local props = extra or {}
	props.name = name
	props.shape = "Cylinder"
	props.size = self.Vector3.new(height, diameter, diameter)
	props.cf = self.CFrame.new(center) * self.CFrame.Angles(0, 0, math.rad(90))
	props.color = color
	return self:part(parent, props)
end

-- Cilindro deitado ao longo de um CFrame qualquer (eixo = X local do cf)
function Kit:cyl(parent, name, length, diameter, cf, color, extra)
	local props = extra or {}
	props.name = name
	props.shape = "Cylinder"
	props.size = self.Vector3.new(length, diameter, diameter)
	props.cf = cf
	props.color = color
	return self:part(parent, props)
end

function Kit:ball(parent, name, diameter, position, color, extra)
	local props = extra or {}
	props.name = name
	props.shape = "Ball"
	props.size = self.Vector3.new(diameter, diameter, diameter)
	props.cf = self.CFrame.new(position)
	props.color = color
	return self:part(parent, props)
end

-- CFrame em "at" olhando para "target" (como CFrame.lookAt do Roblox).
-- Não usar o CFrame.lookAt do Lune: ele espelha a inclinação (a componente Z da
-- direção sai invertida), deixando canudos, corrimãos e fachos tortos no jogo.
function Kit:lookAt(at, target)
	local Vector3 = self.Vector3
	local look = (target - at).Unit
	local up = Vector3.new(0, 1, 0)
	if math.abs(look:Dot(up)) > 0.999 then
		up = Vector3.new(0, 0, 1)
	end
	local right = look:Cross(up).Unit
	local trueUp = right:Cross(look).Unit
	return self.CFrame.fromMatrix(at, right, trueUp, -look)
end

-- Peça ligando dois pontos (canudos, cordas, fachos de luz)
function Kit:beam(parent, name, a, b, thickness, color, extra)
	local length = (b - a).Magnitude
	local props = extra or {}
	props.name = name
	props.size = self.Vector3.new(thickness, thickness, length)
	props.cf = self:lookAt((a + b) / 2, b)
	props.color = color
	return self:part(parent, props)
end

function Kit:light(part, props)
	local l = self.Instance.new(props.class or "PointLight")
	l.Color = props.color or self:rgb(255, 230, 190)
	l.Brightness = props.brightness or 1.5
	l.Range = (props.range or 16) * self.scale
	l.Shadows = props.shadows == true
	if props.face and l:IsA("SpotLight") then
		l.Face = props.face
		l.Angle = props.angle or 60
	end
	l.Parent = part
	return l
end

--[[
	Rampa invisível de colisão (WedgePart) entre dois pontos no eixo Z.
	Serve para escadas/degraus: o Humanoid só sobe sozinho degraus mais baixos que o
	passo dele (personagens pequenos, como o waffle, travam); numa rampa qualquer um sobe.
	x0..x1: largura; (zLow, yLow) é a base, (zHigh, yHigh) o topo.
]]
function Kit:ramp(parent, name, x0, x1, zLow, yLow, zHigh, yHigh)
	local CFrame, Vector3 = self.CFrame, self.Vector3
	local length = math.abs(zHigh - zLow)
	local height = yHigh - yLow
	local center = Vector3.new((x0 + x1) / 2, (yLow + yHigh) / 2, (zLow + zHigh) / 2)
	-- O WedgePart sobe em direção ao +Z local; gira 180° se o topo estiver no -Z
	local cf = CFrame.new(center)
	if zHigh < zLow then
		cf = cf * CFrame.Angles(0, math.pi, 0)
	end
	return self:part(parent, {
		name = name,
		class = "WedgePart",
		size = Vector3.new(math.abs(x1 - x0), height, length),
		cf = cf,
		transparency = 1,
	})
end

--[[
	Placa com SurfaceGui (cardápio, cartazes, letreiros).
	opts:
		face (Enum.NormalId), bg (Color3), bgTransparency, glow (ignora luz da cena)
		lines = { { text, y, h, color, stroke (Color3?), font (Enum.Font?), x, w, align } }
		frames = { { x, y, w, h, color, transparency, corner } }
]]
function Kit:sign(part, opts)
	local Enum, Instance, UDim2 = self.Enum, self.Instance, self.UDim2
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = opts.face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- Compensa a escala para o texto manter a mesma resolução
	gui.PixelsPerStud = (opts.pixelsPerStud or 40) / self.scale
	gui.LightInfluence = opts.glow and 0 or 1
	gui.Brightness = opts.glow and 1.4 or 1
	gui.Parent = part

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = opts.bg or self:rgb(255, 255, 255)
	bg.BackgroundTransparency = opts.bgTransparency or 0
	bg.Parent = gui

	for i, f in ipairs(opts.frames or {}) do
		local frame = Instance.new("Frame")
		frame.Name = "Shape" .. i
		frame.Position = UDim2.fromScale(f.x, f.y)
		frame.Size = UDim2.fromScale(f.w, f.h)
		frame.BackgroundColor3 = f.color
		frame.BackgroundTransparency = f.transparency or 0
		frame.BorderSizePixel = 0
		frame.Parent = bg
		if f.corner then
			local c = Instance.new("UICorner")
			c.CornerRadius = self.rbx.UDim.new(f.corner, 0)
			c.Parent = frame
		end
	end

	for i, line in ipairs(opts.lines or {}) do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. i
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(line.x or 0.05, line.y)
		label.Size = UDim2.fromScale(line.w or 0.9, line.h)
		label.Text = line.text
		label.TextScaled = true
		label.Font = line.font or Enum.Font.FredokaOne
		label.TextColor3 = line.color or self:rgb(255, 255, 255)
		if line.align == "left" then
			label.TextXAlignment = Enum.TextXAlignment.Left
		elseif line.align == "right" then
			label.TextXAlignment = Enum.TextXAlignment.Right
		end
		if line.stroke then
			label.TextStrokeColor3 = line.stroke
			label.TextStrokeTransparency = 0
		end
		label.ZIndex = 2
		label.Parent = bg
	end
	return gui
end

return Kit
