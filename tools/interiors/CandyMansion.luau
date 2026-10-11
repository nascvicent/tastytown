--[[
	Interior da Candy Mansion — diorama isométrico de dois andares.

	Como a CasaInterior: uma caixa gigante (CaixaResidencial) envolve tudo e dá o
	fundo e a luz; o cômodo fica no meio, em corte, com paredes só nos lados de
	trás da câmera isométrica (a câmera olha de +X/-Z, então as paredes ficam em
	-X e +Z).

	Andares (a mansão de fora tem dois):
	  • Térreo (sala + cozinha) ocupa o piso inteiro
	  • Mezanino (quarto) cobre só a metade do fundo (z >= 0), para não tapar a
	    câmera; sobe-se pela escada de doce encostada na parede -X
	  • O Model "AndarSuperior" some localmente quando o jogador está no térreo
	    (FloorCutawayController), estilo The Sims — a câmera não é alterada

	Medidas já na escala do jogo (Kit com escala 1), seguindo a CasaInterior.

	Partes especiais:
	  • SpawnInterior — onde o jogador aparece
	  • SaidaCasa — capacho de saída; recebe o prompt "Sair de casa"
	  • CasaTrigger — volume do cômodo (mesmo papel da CasaInterior)
	  • AndarSuperior/PisoSuperior — referência de altura do mezanino
	  • Barreiras — paredes invisíveis nos lados abertos
]]

local Kit = require("./Kit")

return function(rbx)
	local k = Kit.new(rbx, 1)
	local Vector3, CFrame, Enum = k.Vector3, k.CFrame, k.Enum
	local V, CF = Vector3.new, CFrame.new
	local rad = math.rad

	local C = {
		boxWall = k:rgb(255, 214, 232),
		boxFloor = k:rgb(226, 150, 190),
		cookie = k:rgb(196, 132, 80),
		wafer = k:rgb(246, 210, 150),
		waferDark = k:rgb(228, 186, 122),
		pink = k:rgb(255, 150, 196),
		pinkLight = k:rgb(255, 205, 225),
		white = k:rgb(255, 250, 246),
		cream = k:rgb(255, 238, 214),
		mint = k:rgb(150, 228, 200),
		mintDark = k:rgb(110, 200, 170),
		lilac = k:rgb(196, 165, 245),
		lilacLight = k:rgb(225, 210, 255),
		sky = k:rgb(150, 210, 255),
		lemon = k:rgb(255, 228, 110),
		red = k:rgb(235, 60, 80),
		choco = k:rgb(110, 62, 40),
		chocoLight = k:rgb(140, 84, 54),
		gold = k:rgb(245, 196, 70),
		glass = k:rgb(205, 235, 255),
		black = k:rgb(40, 30, 45),
		green = k:rgb(110, 210, 120),
	}
	local NEON, GLASS = Enum.Material.Neon, Enum.Material.Glass
	local SPRINKLES = { C.pink, C.mint, C.lemon, C.sky, C.lilac, C.white, C.red }

	local HALF = 22          -- cômodo de 44 x 44
	local FLOOR = 1          -- topo do piso do térreo
	local STORY = 12         -- pé-direito de cada andar
	local UP = FLOOR + STORY -- topo do piso do mezanino
	local WALL_TOP = UP + STORY

	-- Escada (encostada na parede -X): 12 degraus de 1 stud, subindo de -Z para +Z
	local STAIR_X0, STAIR_X1 = -HALF, -HALF + 6
	local STEP_DEPTH = 1.6
	local STAIR_Z0 = -STORY * STEP_DEPTH

	local root = k:model("CandyMansionInterior")
	local box = k:model("CaixaResidencial", root)
	local shell = k:model("Estrutura", root)
	local ground = k:model("Terreo", root)
	local upper = k:model("AndarSuperior", root)
	local barriers = k:model("Barreiras", root)
	local lights = k:model("Luzes", root)

	-- ═══════════════════════════════════════════
	-- Caixa gigante em volta (fundo + luz, como a CaixaResidencial do interior inicial)
	-- ═══════════════════════════════════════════
	local BOX, BOX_H, BOX_FLOOR = 420, 110, -8
	k:box(box, "Chao", V(BOX, 2, BOX), CF(0, BOX_FLOOR - 1, 0), C.boxFloor)
	k:box(box, "Teto", V(BOX, 2, BOX), CF(0, BOX_FLOOR + BOX_H + 1, 0), C.boxWall)
	for _, side in ipairs({ -1, 1 }) do
		k:box(box, "Parede", V(4, BOX_H, BOX), CF(side * (BOX / 2 + 2), BOX_FLOOR + BOX_H / 2, 0), C.boxWall)
		k:box(box, "Parede", V(BOX, BOX_H, 4), CF(0, BOX_FLOOR + BOX_H / 2, side * (BOX / 2 + 2)), C.boxWall)
	end

	-- ═══════════════════════════════════════════
	-- Base: biscoito + piso de wafer + glacê escorrendo nas bordas abertas
	-- ═══════════════════════════════════════════
	k:box(shell, "Biscoito", V(HALF * 2 + 2, 9, HALF * 2 + 2), CF(0, FLOOR - 0.6 - 4.5, 0), C.cookie)
	for i = 0, 10 do
		k:box(shell, "Wafer", V(4, 0.6, HALF * 2), CF(-HALF + 2 + i * 4, FLOOR - 0.3, 0), (i % 2 == 0) and C.wafer or C.waferDark)
	end
	k:box(shell, "Glace", V(HALF * 2 + 2.4, 1.2, 1.4), CF(0, FLOOR - 1.1, -HALF - 1.1), C.pink)
	k:box(shell, "Glace", V(1.4, 1.2, HALF * 2 + 2.4), CF(HALF + 1.1, FLOOR - 1.1, 0), C.pink)
	for t = -HALF, HALF, 3 do
		local dz = k:rand(1.2, 3)
		k:vcyl(shell, "Gota", dz, 1.2, V(t, FLOOR - 1.4 - dz / 2, -HALF - 1.6), C.pink)
		k:ball(shell, "GotaPonta", 1.2, V(t, FLOOR - 1.4 - dz, -HALF - 1.6), C.pink)
		local dx = k:rand(1.2, 3)
		k:vcyl(shell, "Gota", dx, 1.2, V(HALF + 1.6, FLOOR - 1.4 - dx / 2, t), C.pink)
		k:ball(shell, "GotaPonta", 1.2, V(HALF + 1.6, FLOOR - 1.4 - dx, t), C.pink)
	end

	-- ═══════════════════════════════════════════
	-- Paredes (-X e +Z) dos dois andares: como um bolo de dois andares
	-- ═══════════════════════════════════════════
	local function wall(alongX)
		local length = HALF * 2
		local function at(offset, y, thickness, h, len)
			if alongX then
				return V(len, h, thickness), CF(offset, y, HALF + 0.75)
			end
			return V(thickness, h, len), CF(-HALF - 0.75, y, offset)
		end
		local size, cf = at(0, (FLOOR + WALL_TOP) / 2, 1.5, WALL_TOP - FLOOR, length + 1.5)
		k:box(shell, "Parede", size, cf, C.white)

		-- Térreo: barra de menta + listras rosa
		size, cf = at(0, FLOOR + 2, 1.7, 4, length)
		k:box(shell, "Barra", size, cf, C.mint)
		size, cf = at(0, FLOOR + 4.1, 1.9, 0.4, length)
		k:box(shell, "Friso", size, cf, C.white)
		for s = -HALF + 1, HALF - 1, 4 do
			size, cf = at(s, FLOOR + 4.3 + (STORY - 5) / 2, 1.6, STORY - 5, 2)
			k:box(shell, "Listra", size, cf, C.pinkLight)
		end

		-- Faixa entre andares: "camada de recheio" do bolo
		size, cf = at(0, UP - 0.4, 2.0, 1.6, length + 1.6)
		k:box(shell, "Recheio", size, cf, C.pink)
		for s = -HALF, HALF, 2 do
			local p = alongX and V(s, UP - 1.3, HALF - 0.2) or V(-HALF + 0.2, UP - 1.3, s)
			k:ball(shell, "GotaRecheio", 0.9, p, C.pink)
		end

		-- Mezanino: listras lilás
		for s = -HALF + 1, HALF - 1, 4 do
			size, cf = at(s, UP + 1 + (STORY - 2) / 2, 1.6, STORY - 2, 2)
			k:box(shell, "ListraCima", size, cf, C.lilacLight)
		end

		-- Cobertura de bolo no topo com bolinhas de glacê
		size, cf = at(0, WALL_TOP + 0.4, 2.4, 0.8, length + 2.4)
		k:box(shell, "Cobertura", size, cf, C.cream)
		for s = -HALF, HALF, 2 do
			local p = alongX and V(s, WALL_TOP + 0.9, HALF + 0.75) or V(-HALF - 0.75, WALL_TOP + 0.9, s)
			k:ball(shell, "Glace", 1.3, p, (s % 4 == 0) and C.pink or C.white)
		end
	end
	wall(true)  -- +Z
	wall(false) -- -X
	k:vcyl(shell, "Quina", WALL_TOP - FLOOR + 1, 2.6, V(-HALF - 0.75, (FLOOR + WALL_TOP) / 2, HALF + 0.75), C.pink)
	k:ball(shell, "QuinaCereja", 2.2, V(-HALF - 0.75, WALL_TOP + 1.7, HALF + 0.75), C.red)

	-- Janelas (térreo e mezanino) na parede +Z
	local function window(parent, x, y)
		k:box(parent, "JanelaMoldura", V(6, 5, 0.6), CF(x, y, HALF - 0.2), C.white)
		k:box(parent, "JanelaVidro", V(5, 4, 0.3), CF(x, y, HALF - 0.45), C.sky, { material = GLASS, transparency = 0.2 })
		k:box(parent, "JanelaCruz", V(0.3, 4, 0.4), CF(x, y, HALF - 0.55), C.white)
		for _, side in ipairs({ -1, 1 }) do
			k:box(parent, "Cortina", V(1.4, 5.6, 0.5), CF(x + side * 3.4, y - 0.1, HALF - 0.6), C.pink)
		end
		k:box(parent, "Bando", V(7.4, 0.8, 0.8), CF(x, y + 2.8, HALF - 0.6), C.pink)
	end
	window(ground, 16, FLOOR + 7.5)
	window(upper, -2, UP + 7)

	-- Quadros com SurfaceGui (parede -X do térreo, atrás de onde a escada não chega)
	local function frame(parent, z, y, title, bg)
		k:box(parent, "QuadroMoldura", V(0.4, 5, 4), CF(-HALF + 0.2, y, z), C.gold)
		local art = k:box(parent, "Quadro", V(0.2, 4.2, 3.2), CF(-HALF + 0.45, y, z), bg)
		k:sign(art, {
			face = Enum.NormalId.Right,
			bg = bg,
			frames = { { x = 0.25, y = 0.18, w = 0.5, h = 0.45, color = C.white, corner = 0.5 } },
			lines = { { text = title, y = 0.72, h = 0.18, color = C.white } },
		})
	end
	frame(ground, 8, FLOOR + 7.5, "CUPCAKE", C.lilac)
	frame(upper, 14, UP + 7, "DONUT", C.mintDark)

	-- ═══════════════════════════════════════════
	-- Escada de doce (degraus de wafer com nariz de glacê) + corrimão de bengala
	-- ═══════════════════════════════════════════
	local stairs = k:model("Escada", ground)
	for i = 1, STORY do
		local z0 = STAIR_Z0 + (i - 1) * STEP_DEPTH
		local top = FLOOR + i
		k:box(stairs, "Degrau", V(STAIR_X1 - STAIR_X0, top - FLOOR, STEP_DEPTH), CF((STAIR_X0 + STAIR_X1) / 2, (top + FLOOR) / 2, z0 + STEP_DEPTH / 2),
			(i % 2 == 0) and C.wafer or C.cream)
		k:box(stairs, "Nariz", V(STAIR_X1 - STAIR_X0, 0.35, 0.35), CF((STAIR_X0 + STAIR_X1) / 2, top - 0.15, z0 + 0.1), C.pink)
	end
	-- Corrimão no lado aberto da escada
	local railBottom = V(STAIR_X1 - 0.3, FLOOR + 3.5, STAIR_Z0 + 0.5)
	local railTop = V(STAIR_X1 - 0.3, UP + 3, -0.2)
	k:beam(stairs, "Corrimao", railBottom, railTop, 0.5, C.red)
	for i = 0, 4 do
		local t = i / 4
		local p = railBottom:Lerp(railTop, t)
		local stepTop = FLOOR + math.clamp(math.ceil((p.Z - STAIR_Z0) / STEP_DEPTH), 1, STORY)
		k:vcyl(stairs, "Pilar", p.Y - stepTop, 0.5, V(p.X, (p.Y + stepTop) / 2, p.Z), (i % 2 == 0) and C.red or C.white)
	end

	-- ═══════════════════════════════════════════
	-- Mezanino: laje com cara de camada de bolo + guarda-corpo de bengalinhas
	-- ═══════════════════════════════════════════
	k:box(upper, "PisoSuperior", V(HALF * 2, 1, HALF), CF(0, UP - 0.5, HALF / 2), C.wafer)
	k:box(upper, "BordaBolo", V(HALF * 2 + 0.4, 1.4, 0.8), CF(0, UP - 0.9, -0.2), C.cream)
	k:box(upper, "BordaBolo", V(0.8, 1.4, HALF + 0.4), CF(HALF + 0.2, UP - 0.9, HALF / 2), C.cream)
	for x = -HALF + 1, HALF - 1, 2 do
		k:ball(upper, "GotaBorda", 0.8, V(x, UP - 1.7, -0.3), (x % 4 == 1) and C.pink or C.white)
	end
	for i = 0, 7 do
		k:box(upper, "TabuaCima", V(HALF * 2, 0.15, 2.6), CF(0, UP + 0.05, 1.4 + i * 2.75), (i % 2 == 0) and C.wafer or C.waferDark)
	end

	-- Guarda-corpo na frente do mezanino (abre na chegada da escada) e no lado +X
	local function railing(from, to)
		local dir = (to - from)
		local n = math.max(1, math.floor(dir.Magnitude / 2.5))
		for i = 0, n do
			local p = from + dir * (i / n)
			k:vcyl(upper, "Bengala", 3, 0.5, p + V(0, 1.5, 0), (i % 2 == 0) and C.red or C.white)
		end
		k:beam(upper, "Corrimao", from + V(0, 3.1, 0), to + V(0, 3.1, 0), 0.5, C.pink)
	end
	railing(V(STAIR_X1 + 0.4, UP, 0.2), V(HALF - 0.4, UP, 0.2))
	railing(V(HALF - 0.4, UP, 0.4), V(HALF - 0.4, UP, HALF - 0.4))

	-- ═══════════════════════════════════════════
	-- Móveis de doce (reutilizáveis)
	-- ═══════════════════════════════════════════
	local function lollipopLamp(parent, base, stickH, discD, withLight)
		k:vcyl(parent, "Palito", stickH, 0.4, base + V(0, stickH / 2, 0), C.white)
		local center = CF(base + V(0, stickH + discD / 2 - 0.2, 0)) * CFrame.Angles(0, rad(45), 0)
		local disc = k:cyl(parent, "Pirulito", 0.6, discD, center, C.pink)
		k:cyl(parent, "PirulitoAnel", 0.7, discD * 0.66, center, C.white)
		k:cyl(parent, "PirulitoMiolo", 0.8, discD * 0.33, center, C.mint, { material = NEON })
		if withLight then k:light(disc, { range = 18, brightness = 1.3, color = k:rgb(255, 215, 235) }) end
	end

	local function gumdrop(parent, p, color)
		k:part(parent, { name = "PufeGoma", shape = "Ball", size = V(3.4, 3.2, 3.4), cf = CF(p + V(0, 1.2, 0)), color = color })
	end

	local function candyCane(parent, p)
		for seg = 0, 5 do
			k:vcyl(parent, "Bengala", 1, 0.8, p + V(0, 0.5 + seg, 0), (seg % 2 == 0) and C.red or C.white)
		end
		k:ball(parent, "BengalaTopo", 0.9, p + V(0, 6.3, 0), C.red)
	end

	-- ═══════════════════════════════════════════
	-- TÉRREO: sala de TV, cozinha, algodão-doce
	-- ═══════════════════════════════════════════
	-- TV de bombom no rack de wafer (encostada na parede +Z, embaixo do mezanino)
	do
		local m = k:model("TV", ground)
		local c = V(5, FLOOR, HALF - 2.4)
		k:box(m, "RackWafer", V(9, 2.6, 3), CF(c + V(0, 1.3, 0)), C.wafer)
		for i = 0, 2 do
			k:box(m, "RackListra", V(9.05, 0.3, 3.05), CF(c + V(0, 0.6 + i * 0.8, 0)), C.waferDark)
		end
		k:box(m, "TVCaixa", V(7.6, 4.6, 1.2), CF(c + V(0, 5, 0.2)), C.pink)
		local screen = k:box(m, "Tela", V(6.6, 3.8, 0.3), CF(c + V(0, 5, -0.45)), C.black)
		k:sign(screen, {
			face = Enum.NormalId.Front,
			bg = k:rgb(255, 196, 120),
			glow = true,
			frames = { { x = 0.36, y = 0.12, w = 0.28, h = 0.5, color = C.pink, corner = 0.5 } },
			lines = { { text = "TASTY TV", y = 0.68, h = 0.22, color = C.white, stroke = C.choco } },
		})
		k:beam(m, "Antena", c + V(-0.8, 7.3, 0.2), c + V(-2.2, 9.2, 0.2), 0.2, C.white)
		k:beam(m, "Antena", c + V(0.8, 7.3, 0.2), c + V(2.2, 9.2, 0.2), 0.2, C.white)
		k:ball(m, "AntenaPonta", 0.6, c + V(-2.2, 9.3, 0.2), C.red)
		k:ball(m, "AntenaPonta", 0.6, c + V(2.2, 9.3, 0.2), C.mint)
	end

	-- Tapete de donut + mesinha de sorvete-sanduíche
	do
		local m = k:model("TapeteDonut", ground)
		local c = V(5, FLOOR, 10)
		k:vcyl(m, "Massa", 0.25, 11, c + V(0, 0.12, 0), C.wafer)
		k:vcyl(m, "Glace", 0.3, 10, c + V(0, 0.18, 0), C.pink)
		k:vcyl(m, "Furo", 0.35, 3.4, c + V(0, 0.2, 0), C.waferDark)
		for _ = 1, 30 do
			local a, r = k:rand(0, 2 * math.pi), k:rand(2.2, 4.6)
			k:box(m, "Granulado", V(0.6, 0.12, 0.22), CF(c + V(math.cos(a) * r, 0.38, math.sin(a) * r)) * CFrame.Angles(0, k:rand(0, 6.28), 0), k:pick(SPRINKLES))
		end
		k:box(m, "MesaBiscoitoBaixo", V(5, 0.8, 3), CF(c + V(0, 1.6, 0)), C.choco)
		k:box(m, "MesaSorvete", V(4.7, 1.2, 2.7), CF(c + V(0, 2.6, 0)), C.cream)
		k:box(m, "MesaBiscoitoCima", V(5, 0.8, 3), CF(c + V(0, 3.6, 0)), C.choco)
		k:vcyl(m, "MesaPe", 1.2, 1.2, c + V(0, 0.6, 0), C.choco)
		k:vcyl(m, "Prato", 0.2, 1.8, c + V(0.8, 4.1, 0), C.white)
		k:vcyl(m, "MiniCupcake", 0.8, 1, c + V(0.8, 4.6, 0), C.pink)
		k:ball(m, "MiniCobertura", 1.1, c + V(0.8, 5.1, 0), C.white)
	end

	-- Sofá de marshmallow virado para a TV
	do
		local m = k:model("SofaMarshmallow", ground)
		local c = V(5, FLOOR, 2.5)
		k:box(m, "Base", V(10, 1.6, 3.6), CF(c + V(0, 0.8, 0)), C.lilac)
		for i = -1, 1 do
			k:cyl(m, "Almofada", 3.6, 3, CF(c + V(i * 3.1, 2.4, 0.2)) * CFrame.Angles(0, rad(90), 0), (i == 0) and C.white or C.pinkLight)
			k:vcyl(m, "Encosto", 3.4, 3, c + V(i * 3.1, 3.5, -1.6), (i == 0) and C.pinkLight or C.white)
		end
		for _, side in ipairs({ -1, 1 }) do
			k:vcyl(m, "Braco", 3.6, 2.4, c + V(side * 5.6, 2, 0), C.mint)
		end
	end
	gumdrop(ground, V(12.5, FLOOR, 8), C.lemon)
	gumdrop(ground, V(-2.5, FLOOR, 10), C.sky)

	-- Cozinha: balcão com bolo de andares (parede +Z, à esquerda da TV)
	do
		local m = k:model("CantinhoBolo", ground)
		local c = V(-10, FLOOR, HALF - 2.4)
		k:box(m, "Balcao", V(9, 4, 4), CF(c + V(0, 2, 0)), C.white)
		k:box(m, "BalcaoFaixa", V(9.1, 1, 4.1), CF(c + V(0, 3, 0)), C.mint)
		k:box(m, "Tampo", V(9.6, 0.5, 4.6), CF(c + V(0, 4.25, 0)), C.pinkLight)
		local b = c + V(-1.5, 4.5, 0)
		k:vcyl(m, "Suporte", 0.3, 3.6, b + V(0, 0.15, 0), C.white)
		k:vcyl(m, "BoloAndar1", 1.4, 3.2, b + V(0, 1, 0), C.pink)
		k:vcyl(m, "BoloAndar2", 1.2, 2.3, b + V(0, 2.3, 0), C.white)
		k:vcyl(m, "BoloAndar3", 1, 1.5, b + V(0, 3.4, 0), C.pink)
		k:ball(m, "Morango", 0.9, b + V(0, 4.2, 0), C.red)
		for i = 0, 7 do
			local a = i / 8 * 2 * math.pi
			k:ball(m, "GotaBolo", 0.5, b + V(math.cos(a) * 1.55, 1.45, math.sin(a) * 1.55), C.white)
		end
		k:vcyl(m, "PoteBalas", 1.8, 1.6, c + V(2.6, 5.4, 0), C.glass, { material = GLASS, transparency = 0.5 })
		for _ = 1, 8 do
			k:ball(m, "Bala", 0.45, c + V(2.6 + k:rand(-0.5, 0.5), 4.8 + k:rand(0, 1), k:rand(-0.5, 0.5)), k:pick(SPRINKLES))
		end
	end

	-- Árvore de algodão-doce num vaso (canto da frente)
	do
		local m = k:model("ArvoreAlgodaoDoce", ground)
		local p = V(HALF - 3.5, FLOOR, HALF - 3.5)
		k:vcyl(m, "Vaso", 2.2, 3, p + V(0, 1.1, 0), C.lilac)
		k:vcyl(m, "Palito", 5, 0.4, p + V(0, 4.5, 0), C.white)
		for _ = 1, 7 do
			k:ball(m, "Algodao", k:rand(2.2, 3.2), p + V(k:rand(-1.2, 1.2), 7.5 + k:rand(-0.8, 1), k:rand(-1.2, 1.2)), k:pick({ C.pinkLight, C.sky, C.pink }))
		end
	end

	lollipopLamp(ground, V(-12, FLOOR, -4), 7, 3.4, true)
	candyCane(ground, V(HALF - 1, FLOOR, -HALF + 1))

	-- ═══════════════════════════════════════════
	-- MEZANINO: quarto
	-- ═══════════════════════════════════════════
	-- Cama de cupcake (forminha plissada + cobertura fofa + cereja)
	do
		local m = k:model("CamaCupcake", upper)
		local base = V(-10, UP, 13)
		local radius, height, slats = 5.2, 3, 22
		local tilt = rad(10)
		local topR = radius + math.sin(tilt) * height
		local width = 2 * math.pi * topR / slats * 1.05
		for i = 0, slats - 1 do
			local a = i / slats * 2 * math.pi
			local radial = V(math.cos(a), 0, math.sin(a))
			local tangent = V(-math.sin(a), 0, math.cos(a))
			local up = V(0, math.cos(tilt), 0) + radial * math.sin(tilt)
			local out = radial * math.cos(tilt) - V(0, math.sin(tilt), 0)
			local center = base + radial * (radius + math.sin(tilt) * height / 2) + V(0, height / 2, 0)
			k:part(m, { name = "Forminha", size = V(width, height, 0.35), cf = CFrame.fromMatrix(center, tangent, up, -out),
				color = (i % 2 == 0) and C.pink or C.white })
		end
		k:vcyl(m, "Fundo", 2.8, radius * 2, base + V(0, 1.4, 0), C.cookie)
		k:part(m, { name = "Cobertura", shape = "Ball", size = V(topR * 2.1, 2.6, topR * 2.1), cf = CF(base + V(0, height + 0.4, 0)), color = C.white })
		for i = 0, 9 do
			local a = i / 10 * 2 * math.pi
			k:ball(m, "Chantili", 2.2, base + V(math.cos(a) * (topR - 0.6), height + 0.6, math.sin(a) * (topR - 0.6)), C.pinkLight)
		end
		k:part(m, { name = "Travesseiro", shape = "Ball", size = V(3.2, 1.2, 2.2), cf = CF(base + V(-1.8, height + 1.7, 2.6)), color = C.lilac })
		k:part(m, { name = "Travesseiro", shape = "Ball", size = V(3.2, 1.2, 2.2), cf = CF(base + V(1.8, height + 1.7, 2.6)), color = C.mint })
		k:ball(m, "Cereja", 2.4, base + V(0, height + 2.6, 4.2), C.red)
		k:beam(m, "CabinhoCereja", base + V(0, height + 3.6, 4.2), base + V(0.6, height + 5.2, 4.9), 0.25, C.green)
		for _ = 1, 22 do
			local a, r = k:rand(0, 2 * math.pi), k:rand(0, topR - 1)
			k:box(m, "Granulado", V(0.5, 0.2, 0.2), CF(base + V(math.cos(a) * r, height + 1.65, math.sin(a) * r)) * CFrame.Angles(0, k:rand(0, 6.28), 0), k:pick(SPRINKLES))
		end
	end

	-- Criado-mudo de macaron com abajur de pirulito
	do
		local m = k:model("CriadoMacaron", upper)
		local p = V(-18.5, UP, 18)
		k:vcyl(m, "Base", 1.4, 3.6, p + V(0, 0.7, 0), C.lilac)
		k:vcyl(m, "Recheio", 0.7, 3.3, p + V(0, 1.75, 0), C.cream)
		k:vcyl(m, "Topo", 1.4, 3.6, p + V(0, 2.8, 0), C.lilac)
		lollipopLamp(m, p + V(0, 3.5, 0), 1.6, 2.4, true)
	end

	-- Guarda-roupa de barra de chocolate meio desembrulhada
	do
		local m = k:model("GuardaRoupaChocolate", upper)
		local c = V(6, UP + 5.5, HALF - 1.6)
		k:box(m, "Barra", V(7, 11, 2.4), CF(c), C.choco)
		for row = 0, 2 do
			for col = 0, 1 do
				k:box(m, "Gomo", V(2.8, 2.6, 0.5), CF(c + V(-1.7 + col * 3.4, -3.8 + row * 3, -1.3)), C.chocoLight)
			end
		end
		k:box(m, "Embalagem", V(7.3, 3.4, 2.7), CF(c + V(0, 4, 0)), C.red)
		k:box(m, "Papel", V(7.35, 0.6, 2.75), CF(c + V(0, 2.4, 0)), C.gold)
		local label = k:box(m, "Rotulo", V(5, 1.6, 0.2), CF(c + V(0, 4, -1.45)), C.red)
		k:sign(label, { face = Enum.NormalId.Front, bg = C.red, lines = { { text = "CHOCO", y = 0.1, h = 0.8, color = C.gold } } })
	end

	-- Penteadeira com espelho de donut
	do
		local m = k:model("PenteadeiraDonut", upper)
		local c = V(15, UP, HALF - 2)
		k:box(m, "Mesa", V(6, 3.4, 2.6), CF(c + V(0, 1.7, 0)), C.pinkLight)
		k:box(m, "Gaveta", V(5, 1, 0.3), CF(c + V(0, 2.2, -1.35)), C.white)
		k:cyl(m, "Espelho", 0.5, 4.6, CF(c + V(0, 6.2, 0.6)) * CFrame.Angles(0, rad(90), 0), C.wafer)
		k:cyl(m, "EspelhoGlace", 0.6, 4, CF(c + V(0, 6.2, 0.55)) * CFrame.Angles(0, rad(90), 0), C.lilac)
		k:cyl(m, "Vidro", 0.7, 2.4, CF(c + V(0, 6.2, 0.5)) * CFrame.Angles(0, rad(90), 0), C.glass, { material = GLASS, transparency = 0.1 })
		k:vcyl(m, "Perfume", 1.2, 0.8, c + V(-1.8, 4, -0.3), C.mint)
		k:ball(m, "PerfumeTampa", 0.6, c + V(-1.8, 4.8, -0.3), C.gold)
	end

	-- Tapete de morango e baú de bombom
	do
		local m = k:model("TapeteMorango", upper)
		local c = V(2, UP, 9)
		k:vcyl(m, "Tapete", 0.2, 8, c + V(0, 0.15, 0), C.red)
		for _ = 1, 14 do
			local a, r = k:rand(0, 2 * math.pi), k:rand(0.8, 3.4)
			k:vcyl(m, "Semente", 0.25, 0.35, c + V(math.cos(a) * r, 0.3, math.sin(a) * r), C.lemon)
		end
		k:box(m, "BauBombom", V(4, 2.6, 2.6), CF(c + V(9, 1.3, 2)), C.choco)
		k:box(m, "BauLaco", V(0.6, 2.7, 2.7), CF(c + V(9, 1.35, 2)), C.pink)
		k:ball(m, "BauLacoTopo", 1.2, c + V(9, 2.9, 2), C.pink)
	end
	lollipopLamp(upper, V(HALF - 3, UP, HALF - 6.5), 7, 3.4, true)

	-- ═══════════════════════════════════════════
	-- Saída: capacho no canto aberto do térreo (prompt "Sair de casa" do HouseService)
	-- ═══════════════════════════════════════════
	do
		local m = k:model("Saida", root)
		local c = V(16, FLOOR, -17)
		local mat = k:box(m, "SaidaCasa", V(6, 0.3, 4), CF(c + V(0, 0.15, 0)), C.pink)
		k:sign(mat, {
			face = Enum.NormalId.Top,
			bg = C.pink,
			frames = {
				{ x = 0.06, y = 0.1, w = 0.88, h = 0.8, color = C.white, corner = 0.3 },
				{ x = 0.3, y = 0.3, w = 0.4, h = 0.4, color = C.pink, corner = 0.5 },
			},
		})
		k:box(m, "CapachoBorda", V(6.4, 0.2, 4.4), CF(c + V(0, 0.1, 0)), C.white)
		k:vcyl(m, "PlacaPoste", 3.6, 0.4, c + V(3.6, 1.8, 2.4), C.white)
		local sign = k:box(m, "Placa", V(3.2, 1.4, 0.3), CF(c + V(3.6, 3.9, 2.4)) * CFrame.Angles(0, rad(-45), 0), C.mint)
		k:sign(sign, { face = Enum.NormalId.Front, bg = C.mint, glow = true, lines = { { text = "SAÍDA", y = 0.1, h = 0.8, color = C.white } } })
		k:sign(sign, { face = Enum.NormalId.Back, bg = C.mint, glow = true, lines = { { text = "SAÍDA", y = 0.1, h = 0.8, color = C.white } } })
	end

	k:box(root, "SpawnInterior", V(4, 1, 2), CFrame.lookAt(V(12, FLOOR + 0.5, -12), V(0, FLOOR + 0.5, 0)), C.white,
		{ transparency = 1, collide = false })
	k:box(root, "CasaTrigger", V(HALF * 2, WALL_TOP - FLOOR, HALF * 2), CF(0, (FLOOR + WALL_TOP) / 2, 0), C.white,
		{ transparency = 1, collide = false })

	-- ═══════════════════════════════════════════
	-- Barreiras invisíveis: onde "seria a parede" nos lados abertos
	-- ═══════════════════════════════════════════
	local barrierH = WALL_TOP - FLOOR + 6
	k:box(barriers, "BarreiraFrente", V(HALF * 2 + 4, barrierH, 1), CF(0, FLOOR + barrierH / 2, -HALF - 0.5), C.white, { transparency = 1 })
	k:box(barriers, "BarreiraLado", V(1, barrierH, HALF * 2 + 4), CF(HALF + 0.5, FLOOR + barrierH / 2, 0), C.white, { transparency = 1 })
	-- Mezanino: não deixa pular o guarda-corpo (a abertura da escada fica livre)
	local railLen = HALF - STAIR_X1
	k:box(barriers, "BarreiraMezanino", V(railLen, 8, 0.6), CF(STAIR_X1 + railLen / 2, UP + 4, 0.2), C.white, { transparency = 1 })
	-- Teto invisível para ninguém subir em cima das paredes
	k:box(barriers, "BarreiraTeto", V(HALF * 2 + 4, 1, HALF * 2 + 4), CF(0, WALL_TOP + 6, 0), C.white, { transparency = 1 })

	-- Luz geral suave e quente
	local fill = k:box(lights, "LuzGeral", V(1, 1, 1), CF(0, WALL_TOP + 10, 0), C.white, { transparency = 1, collide = false })
	k:light(fill, { range = 60, brightness = 0.8, color = k:rgb(255, 225, 235) })

	root.WorldPivot = CF(0, FLOOR, 0)
	return root
end
