--[[
	Peças de sushi reaproveitáveis (exterior e interior da Sushi House).

	Todas recebem o Kit (k) e montam a peça com primitivas, no estilo do jogo:
	low-poly, SmoothPlastic, cores saturadas.
]]

local Sushi = {}

function Sushi.colors(k)
	return {
		rice = k:rgb(252, 250, 242),
		riceShade = k:rgb(236, 231, 216),
		nori = k:rgb(36, 62, 44),
		noriLight = k:rgb(58, 90, 62),
		salmon = k:rgb(255, 136, 88),
		salmonFat = k:rgb(255, 214, 188),
		tuna = k:rgb(222, 56, 74),
		tamago = k:rgb(255, 212, 84),
		tamagoDark = k:rgb(236, 180, 60),
		ikura = k:rgb(255, 104, 30),
		cucumber = k:rgb(110, 196, 90),
		avocado = k:rgb(196, 226, 120),
		shrimp = k:rgb(255, 120, 80),
		wasabi = k:rgb(150, 206, 84),
		wasabiDark = k:rgb(118, 176, 64),
		ginger = k:rgb(255, 184, 190),
		soy = k:rgb(70, 34, 22),
		wood = k:rgb(226, 182, 124),
		woodDark = k:rgb(176, 124, 82),
		woodDeep = k:rgb(112, 70, 46),
		lacquer = k:rgb(206, 44, 52),
		lacquerDark = k:rgb(40, 28, 30),
		paper = k:rgb(255, 248, 232),
		porcelain = k:rgb(246, 248, 255),
		porcelainBlue = k:rgb(70, 110, 200),
		bamboo = k:rgb(140, 196, 96),
		bambooDark = k:rgb(104, 160, 70),
		sesame = k:rgb(255, 244, 214),
		gold = k:rgb(245, 196, 70),
	}
end

-- Grãos de arroz espalhados numa face. faceCf: centro da face com o LookVector para fora;
-- w x h é a área coberta (eixos X/Y do faceCf).
function Sushi.grains(k, parent, faceCf, w, h, count, color, size)
	local CFrame, Vector3 = k.CFrame, k.Vector3
	size = size or 1
	for _ = 1, count do
		local x, y = k:rand(-w / 2, w / 2), k:rand(-h / 2, h / 2)
		k:part(parent, {
			name = "Grao",
			shape = "Cylinder",
			size = Vector3.new(1.1 * size, 0.5 * size, 0.5 * size),
			cf = faceCf * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, k:rand(0, math.pi)),
			color = color,
			collide = false,
		})
	end
end

-- Maki em pé: alga por fora, arroz e recheio no topo. base = centro do chão.
function Sushi.maki(k, parent, name, base, d, h, filling)
	local C = Sushi.colors(k)
	local Vector3 = k.Vector3
	local m = k:model(name, parent)
	local top = base + Vector3.new(0, h, 0)
	k:vcyl(m, "Alga", h, d, base + Vector3.new(0, h / 2, 0), C.nori)
	k:vcyl(m, "Arroz", 0.2, d * 0.86, top + Vector3.new(0, 0.1, 0), C.rice)
	k:vcyl(m, "Recheio", 0.3, d * 0.34, top + Vector3.new(0, 0.12, 0), filling or C.salmon)
	for i = 0, 2 do
		local a = i / 3 * 2 * math.pi + 0.5
		local r = d * 0.25
		k:vcyl(m, "Pepino", 0.28, d * 0.14, top + Vector3.new(math.cos(a) * r, 0.11, math.sin(a) * r), C.cucumber)
	end
	return m
end

--[[
	Nigiri: bolinho de arroz com a fatia por cima. cf = centro da base, comprimento no X
	local. opts: topping (Color3), stripes (fatia com gordura, salmão), nori (faixa de alga),
	droop (fatia caindo nas pontas), grains (quantidade de grãos por lado).
]]
function Sushi.nigiri(k, parent, name, cf, len, width, height, opts)
	local C = Sushi.colors(k)
	local Vector3, CFrame = k.Vector3, k.CFrame
	opts = opts or {}
	local m = k:model(name, parent)
	local topping = opts.topping or C.salmon

	-- Arroz com as pontas arredondadas
	k:box(m, "Arroz", Vector3.new(len, height, width), cf * CFrame.new(0, height / 2, 0), C.rice)
	for _, side in ipairs({ -1, 1 }) do
		k:cyl(m, "ArrozPonta", width, height, cf * CFrame.new(side * len / 2, height / 2, 0) * CFrame.Angles(0, math.rad(90), 0), C.rice)
	end
	if opts.grains then
		for _, side in ipairs({ -1, 1 }) do
			local face = cf * CFrame.new(0, height / 2, side * width / 2) * CFrame.Angles(0, side == 1 and math.pi or 0, 0)
			Sushi.grains(k, m, face, len, height * 0.8, opts.grains, C.riceShade, height / 3)
		end
	end

	-- Fatia: centro reto e pontas caindo
	local thick = height * 0.32
	local sliceW = width * 1.08
	local centerLen = (len + height) * 0.62
	local endLen = (len + height) * 0.3
	local droop = math.rad(opts.droop or 22)
	local slices = {}
	slices[1] = k:box(m, "Fatia", Vector3.new(centerLen, thick, sliceW), cf * CFrame.new(0, height + thick / 2, 0), topping)
	for _, side in ipairs({ -1, 1 }) do
		local hinge = cf * CFrame.new(side * centerLen / 2, height + thick / 2, 0)
		local seg = hinge * CFrame.Angles(0, 0, -side * droop) * CFrame.new(side * endLen / 2, 0, 0)
		table.insert(slices, k:box(m, "FatiaPonta", Vector3.new(endLen, thick, sliceW), seg, topping))
	end

	if opts.stripes then
		for _, slice in ipairs(slices) do
			local sx = slice.Size.X
			local n = math.max(1, math.floor(sx / (height * 0.9)))
			for i = 1, n do
				local x = -sx / 2 + (i - 0.5) * sx / n
				k:box(m, "Gordura", Vector3.new(height * 0.12, 0.06, sliceW * 0.9),
					slice.CFrame * CFrame.new(x, thick / 2 + 0.02, 0) * CFrame.Angles(0, math.rad(28), 0), C.salmonFat, { collide = false })
			end
		end
	end

	if opts.nori then
		k:box(m, "FaixaAlga", Vector3.new(len * 0.2, height + thick + 0.12, width + 0.14), cf * CFrame.new(0, (height + thick) / 2 + 0.03, 0), C.nori)
	end
	return m
end

-- Gunkan: copinho de alga com ovas por cima
function Sushi.gunkan(k, parent, name, base, d, h, roe)
	local C = Sushi.colors(k)
	local Vector3 = k.Vector3
	local m = k:model(name, parent)
	k:vcyl(m, "Alga", h, d, base + Vector3.new(0, h / 2, 0), C.nori)
	k:vcyl(m, "Arroz", 0.2, d * 0.86, base + Vector3.new(0, h - 0.1, 0), C.rice)
	local ball = d * 0.22
	for i = 0, 6 do
		local a = i / 7 * 2 * math.pi
		local r = (i == 0) and 0 or d * 0.24
		k:ball(m, "Ova", ball, base + Vector3.new(math.cos(a) * r, h + ball * 0.3, math.sin(a) * r), roe or C.ikura)
	end
	return m
end

-- Lanterna de papel (chochin): bola com tampas e luz
function Sushi.lantern(k, parent, name, center, d, color, withLight)
	local C = Sushi.colors(k)
	local Vector3 = k.Vector3
	local m = k:model(name, parent)
	local body = k:ball(m, "Papel", d, center, color or C.lacquer)
	k:vcyl(m, "Tampa", d * 0.16, d * 0.5, center + Vector3.new(0, d * 0.47, 0), C.lacquerDark)
	k:vcyl(m, "Tampa", d * 0.16, d * 0.5, center - Vector3.new(0, d * 0.47, 0), C.lacquerDark)
	k:vcyl(m, "Faixa", d * 0.06, d * 1.01, center, C.lacquerDark)
	if withLight then
		k:light(body, { range = 14, brightness = 0.9, color = k:rgb(255, 196, 150) })
	end
	return m
end

-- Lâmpada andon (caixa de papel com moldura de madeira)
function Sushi.andon(k, parent, name, base, w, h, withLight)
	local C = Sushi.colors(k)
	local Vector3, CFrame = k.Vector3, k.CFrame
	local m = k:model(name, parent)
	local paper = k:box(m, "Papel", Vector3.new(w - 0.3, h - 1, w - 0.3), CFrame.new(base + Vector3.new(0, h / 2 + 0.3, 0)), C.paper,
		{ material = k.Enum.Material.Neon, transparency = 0.15 })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			k:box(m, "Moldura", Vector3.new(0.3, h, 0.3), CFrame.new(base + Vector3.new(sx * w / 2, h / 2, sz * w / 2)), C.woodDeep)
		end
	end
	for _, y in ipairs({ 0.4, h / 2 + 0.3, h - 0.2 }) do
		k:box(m, "Aro", Vector3.new(w + 0.2, 0.25, w + 0.2), CFrame.new(base + Vector3.new(0, y, 0)), C.woodDeep)
	end
	if withLight then
		k:light(paper, { range = 14, brightness = 0.8, color = k:rgb(255, 226, 180) })
	end
	return m
end

-- Hashi (palito) entre dois pontos: parte de trás laqueada e ponta de madeira
function Sushi.chopstick(k, parent, a, b, thick)
	local C = Sushi.colors(k)
	local split = a:Lerp(b, 0.42)
	k:beam(parent, "HashiCabo", a, split, thick, C.lacquer)
	k:beam(parent, "HashiPonta", split, b, thick * 0.75, C.wood)
end

-- Garrafinha de shoyu com tampa vermelha
function Sushi.soyBottle(k, parent, name, base, h)
	local C = Sushi.colors(k)
	local Vector3 = k.Vector3
	local m = k:model(name, parent)
	local d = h * 0.42
	k:vcyl(m, "Vidro", h * 0.62, d, base + Vector3.new(0, h * 0.31, 0), C.soy)
	k:ball(m, "Ombro", d, base + Vector3.new(0, h * 0.62, 0), C.soy)
	k:vcyl(m, "Gargalo", h * 0.2, d * 0.45, base + Vector3.new(0, h * 0.8, 0), C.soy)
	k:vcyl(m, "Tampa", h * 0.14, d * 0.62, base + Vector3.new(0, h * 0.93, 0), C.lacquer)
	local label = k:vcyl(m, "Rotulo", h * 0.24, d * 1.02, base + Vector3.new(0, h * 0.32, 0), C.paper)
	return m, label
end

-- Pratinho redondo (kaiten) — cores dos pratos de esteira
function Sushi.plate(k, parent, base, d, color)
	local C = Sushi.colors(k)
	local Vector3 = k.Vector3
	k:vcyl(parent, "Prato", 0.18, d, base + Vector3.new(0, 0.09, 0), color)
	k:vcyl(parent, "PratoMiolo", 0.2, d * 0.7, base + Vector3.new(0, 0.1, 0), C.porcelain)
end

return Sushi
