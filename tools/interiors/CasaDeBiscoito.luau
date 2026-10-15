--[[
	Interior da Casa de Biscoito (casa inicial) — diorama isométrico de um andar.

	Mesmo esqueleto dos outros interiores (caixa gigante de fundo, cômodo em corte com
	paredes só em -X e +Z, barreiras invisíveis nos lados abertos). Cores do exterior:
	paredes de chocolate com crackers furadinhos, recheio rosa, pilares de bala laranja
	e donuts de chocolate.

	Um andar só: quarto (cama de biscoito recheado), sala (TV de barra de chocolate,
	sofá de wafer, tapete de cookie), cozinha (balcão de cracker, geladeira de caixa de
	leite), mesa de donut e guarda-roupa de wafer.

	Partes especiais:
	  SpawnInterior, SaidaCasa (prompt "Sair de casa"), CasaTrigger, Barreiras
	  wardrobe/Click — onde flutua o botão "Trocar Sabor" (WardrobeBillboardController)
]]

local Kit = require("./Kit")

return function(rbx)
	local k = Kit.new(rbx, 1)
	local Vector3, CFrame, Enum = k.Vector3, k.CFrame, k.Enum
	local V, CF = Vector3.new, CFrame.new
	local rad = math.rad

	local C = {
		boxWall = k:rgb(255, 228, 210),
		boxFloor = k:rgb(222, 160, 120),
		choco = k:rgb(98, 36, 40),
		chocoLight = k:rgb(132, 56, 52),
		chocoChip = k:rgb(80, 44, 30),
		cookie = k:rgb(196, 132, 80),
		cracker = k:rgb(234, 192, 128),
		crackerDark = k:rgb(208, 160, 98),
		crackerHole = k:rgb(170, 118, 66),
		wafer = k:rgb(246, 210, 150),
		waferDark = k:rgb(226, 182, 118),
		pink = k:rgb(255, 162, 188),
		pinkLight = k:rgb(255, 208, 222),
		cream = k:rgb(255, 242, 228),
		white = k:rgb(255, 252, 248),
		orange = k:rgb(255, 146, 40),
		yellow = k:rgb(255, 214, 80),
		donut = k:rgb(226, 166, 96),
		glaze = k:rgb(112, 58, 40),
		red = k:rgb(232, 60, 74),
		mint = k:rgb(150, 228, 200),
		sky = k:rgb(150, 210, 255),
		milkBlue = k:rgb(90, 150, 235),
		lilac = k:rgb(196, 165, 245),
		black = k:rgb(40, 30, 40),
		green = k:rgb(110, 210, 120),
		glass = k:rgb(205, 235, 255),
	}
	local NEON, GLASS = Enum.Material.Neon, Enum.Material.Glass
	local SPRINKLES = { C.pink, C.mint, C.yellow, C.sky, C.lilac, C.white, C.red }

	local HALF = 18
	local FLOOR = 1
	local WALL_TOP = FLOOR + 14

	local root = k:model("CasaDeBiscoitoInterior")
	local box = k:model("CaixaResidencial", root)
	local shell = k:model("Estrutura", root)
	local room = k:model("Comodo", root)
	local barriers = k:model("Barreiras", root)

	-- ═══════════════════════════════════════════
	-- Caixa gigante (mesmas proporções dos outros interiores)
	-- ═══════════════════════════════════════════
	local BOX_X, BOX_Z, BOX_H, BOX_FLOOR = 600, 640, 110, -9
	local BOX_C = V(-220, 0, 222)
	k:box(box, "Chao", V(BOX_X, 2, BOX_Z), CF(BOX_C.X, BOX_FLOOR - 1, BOX_C.Z), C.boxFloor)
	k:box(box, "Teto", V(BOX_X, 2, BOX_Z), CF(BOX_C.X, BOX_FLOOR + BOX_H + 1, BOX_C.Z), C.boxWall)
	for _, side in ipairs({ -1, 1 }) do
		k:box(box, "Parede", V(4, BOX_H, BOX_Z), CF(BOX_C.X + side * (BOX_X / 2 + 2), BOX_FLOOR + BOX_H / 2, BOX_C.Z), C.boxWall)
		k:box(box, "Parede", V(BOX_X, BOX_H, 4), CF(BOX_C.X, BOX_FLOOR + BOX_H / 2, BOX_C.Z + side * (BOX_Z / 2 + 2)), C.boxWall)
	end

	-- Furinhos de cracker numa face (faceCf com o LookVector para fora)
	local function holes(parent, faceCf, w, h)
		for _, x in ipairs({ -w / 4, w / 4 }) do
			for _, y in ipairs({ -h / 4, h / 4 }) do
				k:cyl(parent, "Furo", 0.12, math.min(w, h) * 0.12, faceCf * CF(x, y, 0) * CFrame.Angles(0, rad(90), 0), C.crackerHole, { collide = false })
			end
		end
	end

	-- ═══════════════════════════════════════════
	-- Base: biscoito recheado (chocolate + recheio rosa) e piso de cracker
	-- ═══════════════════════════════════════════
	k:box(shell, "BiscoitoBaixo", V(HALF * 2 + 2, 4, HALF * 2 + 2), CF(0, FLOOR - 3.6 - 2, 0), C.choco)
	k:box(shell, "Recheio", V(HALF * 2 + 2.6, 2.2, HALF * 2 + 2.6), CF(0, FLOOR - 0.6 - 1.4, 0), C.pinkLight)
	k:box(shell, "BiscoitoCima", V(HALF * 2 + 2, 0.8, HALF * 2 + 2), CF(0, FLOOR - 0.6 - 0.2, 0), C.choco)
	-- Recheio escorrendo nas bordas abertas
	for t = -HALF, HALF, 3 do
		local d1 = k:rand(1, 2.4)
		k:vcyl(shell, "Gota", d1, 1.1, V(t, FLOOR - 2.6 - d1 / 2, -HALF - 1.3), C.pinkLight)
		k:ball(shell, "GotaPonta", 1.1, V(t, FLOOR - 2.6 - d1, -HALF - 1.3), C.pinkLight)
		local d2 = k:rand(1, 2.4)
		k:vcyl(shell, "Gota", d2, 1.1, V(HALF + 1.3, FLOOR - 2.6 - d2 / 2, t), C.pinkLight)
		k:ball(shell, "GotaPonta", 1.1, V(HALF + 1.3, FLOOR - 2.6 - d2, t), C.pinkLight)
	end
	-- Piso: crackers de 6 x 6 com quatro furinhos
	for i = 0, 5 do
		for j = 0, 5 do
			local c = V(-HALF + 3 + i * 6, FLOOR - 0.3, -HALF + 3 + j * 6)
			k:box(shell, "Cracker", V(5.9, 0.6, 5.9), CF(c), ((i + j) % 2 == 0) and C.cracker or C.crackerDark)
			holes(shell, k:lookAt(c + V(0, 0.3, 0), c + V(0, 5, 0)), 5.9, 5.9)
		end
	end

	-- ═══════════════════════════════════════════
	-- Paredes (-X e +Z): chocolate com crackers, rodapé de glacê e recheio rosa no topo
	-- ═══════════════════════════════════════════
	local function wall(alongX)
		local length = HALF * 2
		local inner = HALF - 0.05 -- face interna da parede
		local function at(offset, y, thickness, h, len)
			if alongX then
				return V(len, h, thickness), CF(offset, y, HALF + 0.75)
			end
			return V(thickness, h, len), CF(-HALF - 0.75, y, offset)
		end
		-- Centro de uma peça colada na face interna, com o LookVector para dentro
		local function faceCf(offset, y)
			if alongX then
				return k:lookAt(V(offset, y, inner), V(offset, y, 0))
			end
			return k:lookAt(V(-inner, y, offset), V(0, y, offset))
		end

		local size, cf = at(0, (FLOOR + WALL_TOP) / 2, 1.5, WALL_TOP - FLOOR, length + 1.5)
		k:box(shell, "Parede", size, cf, C.choco)

		-- Duas fileiras de crackers (o chocolate aparece entre eles, como no exterior)
		for row = 0, 1 do
			local y = FLOOR + 4.6 + row * 5.8
			for s = -HALF + 3, HALF - 2, 6 do
				local tile = faceCf(s, y)
				k:box(shell, "CrackerParede", V(5.4, 5.2, 0.5), tile * CF(0, 0, -0.25), ((s + row * 6) % 12 == 3) and C.cracker or C.crackerDark)
				holes(shell, tile * CF(0, 0, -0.5), 5.4, 5.2)
			end
		end

		-- Rodapé de glacê branco com bolinhas
		size, cf = at(0, FLOOR + 0.8, 1.9, 1.6, length)
		k:box(shell, "Rodape", size, cf, C.cream)
		for s = -HALF + 1, HALF - 1, 2 do
			local p = alongX and V(s, FLOOR + 1.7, HALF - 0.2) or V(-HALF + 0.2, FLOOR + 1.7, s)
			k:ball(shell, "GlaceRodape", 0.8, p, (s % 4 == 1) and C.pink or C.white)
		end

		-- Recheio rosa no topo, escorrendo para dentro
		size, cf = at(0, WALL_TOP - 0.6, 2.2, 1.6, length + 2.2)
		k:box(shell, "RecheioTopo", size, cf, C.pink)
		for s = -HALF, HALF, 2.5 do
			local drop = k:rand(0.8, 2)
			local p = alongX and V(s, WALL_TOP - 1.4 - drop / 2, HALF - 0.1) or V(-HALF + 0.1, WALL_TOP - 1.4 - drop / 2, s)
			k:vcyl(shell, "GotaRecheio", drop, 0.9, p, C.pink)
			k:ball(shell, "GotaRecheioPonta", 0.9, p - V(0, drop / 2, 0), C.pink)
		end
		-- Telhado de wafer no topo com donuts de chocolate (como o telhado de fora)
		size, cf = at(0, WALL_TOP + 0.4, 2.8, 0.8, length + 2.8)
		k:box(shell, "Wafer", size, cf, C.wafer)
		for s = -HALF + 4, HALF - 2, 8 do
			local p = alongX and V(s, WALL_TOP + 1.2, HALF + 0.75) or V(-HALF - 0.75, WALL_TOP + 1.2, s)
			k:vcyl(shell, "Donut", 0.8, 2.4, p, C.donut)
			k:vcyl(shell, "DonutCobertura", 0.3, 2.2, p + V(0, 0.45, 0), C.glaze)
			k:vcyl(shell, "DonutFuro", 0.4, 0.8, p + V(0, 0.5, 0), C.wafer)
		end
	end
	wall(true)
	wall(false)

	-- Pilar de bala laranja na quina (como os do exterior) com donut no topo
	do
		local p = V(-HALF - 0.75, FLOOR, HALF + 0.75)
		local h = WALL_TOP - FLOOR + 1
		for seg = 0, h - 1, 1.5 do
			k:vcyl(shell, "PilarBala", 1.5, 2.8, p + V(0, seg + 0.75, 0), (seg % 3 == 0) and C.orange or C.yellow)
		end
		k:vcyl(shell, "PilarDonut", 1, 3.4, p + V(0, h + 0.5, 0), C.donut)
		k:vcyl(shell, "PilarCobertura", 0.4, 3.2, p + V(0, h + 1.1, 0), C.pink)
	end

	-- Janela com moldura de glacê (parede +Z)
	do
		local x, y = 9.5, FLOOR + 8.5
		k:box(room, "JanelaMoldura", V(6.4, 5.4, 0.6), CF(x, y, HALF - 0.3), C.pink)
		k:box(room, "JanelaVidro", V(5.4, 4.4, 0.3), CF(x, y, HALF - 0.55), C.sky, { material = GLASS, transparency = 0.2 })
		k:box(room, "JanelaCruz", V(0.3, 4.4, 0.4), CF(x, y, HALF - 0.65), C.white)
		k:box(room, "JanelaCruz", V(5.4, 0.3, 0.4), CF(x, y, HALF - 0.65), C.white)
		for i = -3, 3 do
			k:ball(room, "GlaceJanela", 0.7, V(x + i * 0.9, y + 2.9, HALF - 0.6), (i % 2 == 0) and C.white or C.pinkLight)
		end
	end

	-- Quadro (parede -X)
	do
		local z, y = 9, FLOOR + 8.5
		k:box(room, "QuadroMoldura", V(0.4, 5, 4), CF(-HALF + 0.3, y, z), C.yellow)
		local art = k:box(room, "Quadro", V(0.2, 4.2, 3.2), CF(-HALF + 0.55, y, z), C.mint)
		k:sign(art, {
			face = Enum.NormalId.Right,
			bg = C.mint,
			frames = {
				{ x = 0.2, y = 0.14, w = 0.6, h = 0.52, color = C.cookie, corner = 0.5 },
				{ x = 0.32, y = 0.26, w = 0.1, h = 0.09, color = C.chocoChip, corner = 0.5 },
				{ x = 0.55, y = 0.32, w = 0.1, h = 0.09, color = C.chocoChip, corner = 0.5 },
				{ x = 0.42, y = 0.48, w = 0.1, h = 0.09, color = C.chocoChip, corner = 0.5 },
			},
			lines = { { text = "COOKIE", y = 0.74, h = 0.18, color = C.white, stroke = C.choco } },
		})
	end

	-- ═══════════════════════════════════════════
	-- Quarto: cama de biscoito recheado (canto -X/+Z)
	-- ═══════════════════════════════════════════
	do
		local m = k:model("CamaBiscoito", room)
		local c = V(-10.5, FLOOR, 10.5)
		k:box(m, "BiscoitoBaixo", V(7.4, 1.4, 11), CF(c + V(0, 0.7, 0)), C.choco)
		k:box(m, "Recheio", V(7, 1.6, 10.6), CF(c + V(0, 2.2, 0)), C.cream)
		for _, side in ipairs({ -1, 1 }) do
			for t = -4.5, 4.5, 1.5 do
				k:ball(m, "RecheioBorda", 0.9, c + V(side * 3.5, 2.2, t), C.white)
			end
		end
		-- Cobertor de geleia de morango com bolinhas de açúcar
		k:box(m, "Cobertor", V(7.2, 0.5, 7), CF(c + V(0, 3.2, -1.8)), C.red)
		k:box(m, "CobertorDobra", V(7.2, 0.6, 1), CF(c + V(0, 3.3, 1.8)), C.pinkLight)
		for _ = 1, 12 do
			k:ball(m, "Acucar", 0.4, c + V(k:rand(-3.2, 3.2), 3.5, k:rand(-5, 1.2)), C.white)
		end
		-- Travesseiros de marshmallow
		for _, x in ipairs({ -1.7, 1.7 }) do
			k:cyl(m, "Marshmallow", 2.6, 1.6, CF(c + V(x, 3.6, 3.8)) * CFrame.Angles(0, rad(90), 0), C.white)
		end
		-- Cabeceira: cracker grande em pé
		local head = c + V(0, 4.5, 6)
		k:box(m, "Cabeceira", V(8, 7, 0.8), CF(head), C.cracker)
		holes(m, k:lookAt(head - V(0, 0, 0.4), head - V(0, 0, 5)), 8, 7)
		for i = -3, 3 do
			k:ball(m, "GlaceCabeceira", 0.8, head + V(i * 1.15, 3.6, 0), (i % 2 == 0) and C.pink or C.white)
		end
	end

	-- Criado-mudo de biscoitos empilhados com abajur de bala
	do
		local m = k:model("CriadoBiscoito", room)
		local p = V(-16, FLOOR, 15.5)
		for i = 0, 2 do
			k:vcyl(m, "Biscoito", 0.9, 3, p + V(0, 0.45 + i * 1.3, 0), C.choco)
			k:vcyl(m, "Recheio", 0.4, 2.8, p + V(0, 1.1 + i * 1.3, 0), C.cream)
		end
		k:vcyl(m, "AbajurPe", 2, 0.4, p + V(0, 4.9, 0), C.orange)
		local bulb = k:part(m, { name = "AbajurBala", shape = "Ball", size = V(2, 1.6, 2), cf = CF(p + V(0, 6.4, 0)), color = C.yellow, material = NEON })
		k:light(bulb, { range = 13, brightness = 0.8, color = k:rgb(255, 222, 170) })
	end

	-- Guarda-roupa de wafer (parede -X)
	do
		local m = k:model("GuardaRoupaWafer", room)
		local c = V(-HALF + 1.4, FLOOR + 5.5, -1)
		k:box(m, "Wafer", V(2.4, 11, 7), CF(c), C.wafer)
		for y = -4.5, 4.5, 1.5 do
			k:box(m, "Linha", V(2.45, 0.15, 7.05), CF(c + V(0, y, 0)), C.waferDark)
		end
		for z = -2.6, 2.6, 1.3 do
			k:box(m, "Linha", V(2.45, 11.05, 0.15), CF(c + V(0, 0, z)), C.waferDark)
		end
		k:box(m, "Porta", V(0.2, 10, 0.2), CF(c + V(1.3, 0, 0)), C.choco)
		for _, z in ipairs({ -0.6, 0.6 }) do
			k:ball(m, "Macaneta", 0.6, c + V(1.35, 0, z), C.choco)
		end
		k:box(m, "Cobertura", V(2.8, 0.8, 7.4), CF(c + V(0, 5.9, 0)), C.choco)
		for z = -3, 3, 1.5 do
			k:ball(m, "Granulado", 0.5, c + V(0, 6.4, z), k:pick(SPRINKLES))
		end
	end

	-- Estante de wafer com "livros" de cracker (parede -X, perto da frente)
	do
		local m = k:model("Estante", room)
		local c = V(-HALF + 1.2, FLOOR, -11)
		k:box(m, "Costas", V(0.4, 7, 6), CF(c + V(-0.6, 3.5, 0)), C.waferDark)
		for i = 0, 2 do
			local y = 0.4 + i * 2.6
			k:box(m, "Prateleira", V(2, 0.4, 6), CF(c + V(0, y, 0)), C.wafer)
			for b = 0, 3 do
				local h = k:rand(1.4, 2)
				k:box(m, "Livro", V(1.4, h, 0.9), CF(c + V(0.1, y + 0.2 + h / 2, -2.2 + b * 1.25)), k:pick({ C.pink, C.mint, C.cracker, C.lilac, C.sky }))
			end
		end
		k:box(m, "Prateleira", V(2, 0.4, 6), CF(c + V(0, 7.2, 0)), C.wafer)
		k:vcyl(m, "PoteCookies", 1.4, 1.4, c + V(0, 8.1, 1.6), C.glass, { material = GLASS, transparency = 0.4 })
	end

	-- ═══════════════════════════════════════════
	-- Sala: TV de barra de chocolate, sofá de wafer, tapete de cookie
	-- ═══════════════════════════════════════════
	do
		local m = k:model("TV", room)
		local c = V(1, FLOOR, HALF - 2.2)
		k:box(m, "RackCracker", V(9, 2.4, 3), CF(c + V(0, 1.2, 0)), C.cracker)
		holes(m, k:lookAt(c + V(0, 1.2, -1.5), c + V(0, 1.2, -5)), 9, 2.4)
		k:box(m, "TVBarra", V(8, 5, 1), CF(c + V(0, 5.2, 0.3)), C.choco)
		for i = -1, 1, 2 do
			k:box(m, "TVGomo", V(0.3, 5.1, 1.05), CF(c + V(i * 3.6, 5.2, 0.3)), C.chocoLight)
		end
		local screen = k:box(m, "Tela", V(6.6, 3.8, 0.3), CF(c + V(0, 5.2, -0.3)), C.black)
		k:sign(screen, {
			face = Enum.NormalId.Front,
			bg = k:rgb(255, 196, 120),
			glow = true,
			frames = {
				{ x = 0.36, y = 0.1, w = 0.28, h = 0.5, color = C.donut, corner = 0.5 },
				{ x = 0.44, y = 0.24, w = 0.12, h = 0.22, color = k:rgb(255, 196, 120), corner = 0.5 },
			},
			lines = { { text = "BISCOITO TV", y = 0.68, h = 0.22, color = C.white, stroke = C.choco } },
		})
		k:box(m, "Embalagem", V(8.3, 1.4, 1.2), CF(c + V(0, 8, 0.3)), C.red)
		k:box(m, "Papel", V(8.35, 0.3, 1.25), CF(c + V(0, 7.25, 0.3)), C.yellow)
	end

	do
		local m = k:model("TapeteCookie", room)
		local c = V(1, FLOOR, 8)
		k:vcyl(m, "Cookie", 0.3, 10, c + V(0, 0.15, 0), C.cookie)
		for _ = 1, 14 do
			local a, r = k:rand(0, 2 * math.pi), k:rand(0.6, 4.2)
			k:vcyl(m, "GotaChocolate", 0.35, k:rand(0.6, 1), c + V(math.cos(a) * r, 0.3, math.sin(a) * r), C.chocoChip)
		end
	end

	do
		local m = k:model("SofaWafer", room)
		local c = V(1, FLOOR, 2.5)
		k:box(m, "Base", V(10, 1.8, 3.6), CF(c + V(0, 0.9, 0)), C.wafer)
		for y = 0.4, 1.6, 0.6 do
			k:box(m, "Linha", V(10.05, 0.12, 3.65), CF(c + V(0, y, 0)), C.waferDark)
		end
		for i = -1, 1 do
			k:box(m, "Almofada", V(3.1, 1, 3.2), CF(c + V(i * 3.2, 2.3, 0.1)), (i == 0) and C.pink or C.cream)
			k:box(m, "Encosto", V(3.1, 3, 1), CF(c + V(i * 3.2, 3.3, -1.4)), C.cracker)
			holes(m, k:lookAt(c + V(i * 3.2, 3.3, -1.9), c + V(i * 3.2, 3.3, -6)), 3.1, 3)
		end
		for _, side in ipairs({ -1, 1 }) do
			k:box(m, "Braco", V(1.2, 2.8, 3.6), CF(c + V(side * 5.6, 1.4, 0)), C.choco)
			k:ball(m, "BracoGlace", 1.2, c + V(side * 5.6, 2.9, 0), C.pink)
		end
	end

	-- ═══════════════════════════════════════════
	-- Cozinha: balcão de cracker, geladeira de caixa de leite
	-- ═══════════════════════════════════════════
	do
		local m = k:model("Cozinha", room)
		local c = V(10, FLOOR, HALF - 2.4)
		k:box(m, "Balcao", V(6, 4, 3.8), CF(c + V(0, 2, 0)), C.cracker)
		holes(m, k:lookAt(c + V(0, 2, -1.9), c + V(0, 2, -6)), 6, 4)
		k:box(m, "Tampo", V(6.6, 0.5, 4.4), CF(c + V(0, 4.25, 0)), C.choco)
		k:vcyl(m, "Prato", 0.2, 2.4, c + V(-1.4, 4.6, 0), C.white)
		for i = 0, 2 do
			k:vcyl(m, "Cookie", 0.3, 1.5, c + V(-1.4, 4.85 + i * 0.32, 0), C.cookie)
		end
		k:vcyl(m, "CopoLeite", 1.4, 0.9, c + V(1.2, 5.2, 0.2), C.glass, { material = GLASS, transparency = 0.3 })
		k:vcyl(m, "Leite", 1.1, 0.75, c + V(1.2, 5.05, 0.2), C.white)
	end

	do
		local m = k:model("GeladeiraLeite", room)
		local c = V(15.6, FLOOR, HALF - 2.2)
		k:box(m, "Caixa", V(3.8, 8, 3.4), CF(c + V(0, 4, 0)), C.white)
		k:box(m, "Faixa", V(3.85, 2.4, 3.45), CF(c + V(0, 4.6, 0)), C.milkBlue)
		for _, side in ipairs({ -1, 1 }) do
			k:part(m, { name = "Telhadinho", class = "WedgePart", size = V(3.8, 1.4, 1.7),
				cf = CF(c + V(0, 8.7, side * 0.85)) * CFrame.Angles(0, (side == 1) and math.pi or 0, 0), color = C.milkBlue })
		end
		local label = k:box(m, "Rotulo", V(3, 1.4, 0.2), CF(c + V(0, 4.6, -1.8)), C.milkBlue)
		k:sign(label, { face = Enum.NormalId.Front, bg = C.milkBlue, lines = { { text = "LEITE", y = 0.1, h = 0.8, color = C.white } } })
		k:box(m, "Puxador", V(0.3, 2.4, 0.3), CF(c + V(-1.4, 3, -1.8)), C.milkBlue)
	end

	-- ═══════════════════════════════════════════
	-- Mesa de donut com banquinhos de cookie (área da frente)
	-- ═══════════════════════════════════════════
	do
		local m = k:model("MesaDonut", room)
		local c = V(-5, FLOOR, -7)
		k:vcyl(m, "Pe", 2.6, 1, c + V(0, 1.3, 0), C.choco)
		k:vcyl(m, "Massa", 1, 6, c + V(0, 3, 0), C.donut)
		k:vcyl(m, "Cobertura", 0.4, 5.6, c + V(0, 3.6, 0), C.pink)
		k:vcyl(m, "Furo", 0.5, 1.6, c + V(0, 3.65, 0), C.choco)
		for _ = 1, 18 do
			local a, r = k:rand(0, 2 * math.pi), k:rand(1.2, 2.6)
			k:box(m, "Granulado", V(0.5, 0.12, 0.18), CF(c + V(math.cos(a) * r, 3.85, math.sin(a) * r)) * CFrame.Angles(0, k:rand(0, 6.28), 0), k:pick(SPRINKLES))
		end
		k:vcyl(m, "Caneca", 1, 0.9, c + V(1.6, 4.3, 0.6), C.white)
		k:vcyl(m, "CanecaLeite", 0.2, 0.75, c + V(1.6, 4.75, 0.6), C.cream)
		for i = 0, 2 do
			local a = i / 3 * 2 * math.pi + 0.4
			local p = c + V(math.cos(a) * 4.6, 0, math.sin(a) * 4.6)
			k:vcyl(m, "BanquinhoCookie", 1.8, 2.6, p + V(0, 0.9, 0), C.cookie)
			for _ = 1, 4 do
				local b, r = k:rand(0, 2 * math.pi), k:rand(0.3, 0.9)
				k:vcyl(m, "Gota", 0.2, 0.45, p + V(math.cos(b) * r, 1.85, math.sin(b) * r), C.chocoChip)
			end
		end
	end

	-- Árvore de pirulito num vaso de forminha (canto da frente, -X)
	do
		local m = k:model("ArvorePirulito", room)
		local p = V(-12, FLOOR, -15.5)
		k:vcyl(m, "Vaso", 2, 2.8, p + V(0, 1, 0), C.pink)
		k:vcyl(m, "VasoBorda", 0.4, 3.1, p + V(0, 2, 0), C.white)
		k:vcyl(m, "Palito", 4, 0.35, p + V(0, 4, 0), C.white)
		local center = CF(p + V(0, 7, 0)) * CFrame.Angles(0, rad(45), 0)
		k:cyl(m, "Pirulito", 0.6, 3.6, center, C.orange)
		k:cyl(m, "PirulitoAnel", 0.7, 2.4, center, C.yellow)
		k:cyl(m, "PirulitoMiolo", 0.8, 1.2, center, C.pink, { material = NEON })
	end

	-- ═══════════════════════════════════════════
	-- Saída: capacho de cracker no canto aberto
	-- ═══════════════════════════════════════════
	do
		local m = k:model("Saida", root)
		local c = V(12.5, FLOOR, -14)
		k:box(m, "SaidaCasa", V(6, 0.3, 4), CF(c + V(0, 0.15, 0)), C.cracker)
		holes(m, k:lookAt(c + V(0, 0.3, 0), c + V(0, 5, 0)), 6, 4)
		k:box(m, "CapachoBorda", V(6.4, 0.2, 4.4), CF(c + V(0, 0.1, 0)), C.choco)
		k:vcyl(m, "PlacaPoste", 3.6, 0.4, c + V(3.6, 1.8, 2.4), C.orange)
		local sign = k:box(m, "Placa", V(3.2, 1.4, 0.3), CF(c + V(3.6, 3.9, 2.4)) * CFrame.Angles(0, rad(-45), 0), C.pink)
		k:sign(sign, { face = Enum.NormalId.Front, bg = C.pink, glow = true, lines = { { text = "SAÍDA", y = 0.1, h = 0.8, color = C.white } } })
		k:sign(sign, { face = Enum.NormalId.Back, bg = C.pink, glow = true, lines = { { text = "SAÍDA", y = 0.1, h = 0.8, color = C.white } } })
	end

	-- Botão "Trocar Sabor" na frente do guarda-roupa de wafer (WardrobeBillboardController
	-- procura "wardrobe/Click" na raiz)
	do
		local m = k:model("wardrobe", root)
		k:box(m, "Click", V(0.4, 1, 2), CF(-HALF + 2.8, FLOOR + 4, -1), C.white, { transparency = 1, collide = false })
	end

	k:box(root, "SpawnInterior", V(4, 1, 2), k:lookAt(V(9, FLOOR + 0.5, -9), V(0, FLOOR + 0.5, 0)), C.white,
		{ transparency = 1, collide = false })
	k:box(root, "CasaTrigger", V(HALF * 2, WALL_TOP - FLOOR, HALF * 2), CF(0, (FLOOR + WALL_TOP) / 2, 0), C.white,
		{ transparency = 1, collide = false })

	local barrierH = WALL_TOP - FLOOR + 6
	k:box(barriers, "BarreiraFrente", V(HALF * 2 + 4, barrierH, 1), CF(0, FLOOR + barrierH / 2, -HALF - 0.5), C.white, { transparency = 1 })
	k:box(barriers, "BarreiraLado", V(1, barrierH, HALF * 2 + 4), CF(HALF + 0.5, FLOOR + barrierH / 2, 0), C.white, { transparency = 1 })
	k:box(barriers, "BarreiraTeto", V(HALF * 2 + 4, 1, HALF * 2 + 4), CF(0, WALL_TOP + 6, 0), C.white, { transparency = 1 })

	root.WorldPivot = CF(0, FLOOR, 0)
	return root
end
