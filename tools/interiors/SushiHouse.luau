--[[
	Interior da Sushi House — diorama isométrico de dois andares.

	Mesmo esqueleto da Candy Mansion (caixa gigante de fundo, cômodo em corte com
	paredes só em -X e +Z, mezanino na metade do fundo e "AndarSuperior" escondido
	pelo FloorCutawayController). Cores do exterior: paredes brancas, vigas vermelho
	laca e grafite, madeira clara do barco de sushi.

	Térreo: balcão de esteira (kaiten) com pratinhos, mesa baixa com barco de sushi
	e almofadas de nigiri, cozinha de arroz, aquário de peixinhos, lanternas.
	Escada de tamago com corrimão de hashi.
	Mezanino: cama de nigiri de salmão, criado-mudo de maki, guarda-roupa de bentô,
	tapete de maki cortado, pelúcia de ebi.

	Partes especiais (as mesmas da Candy Mansion):
	  SpawnInterior, SaidaCasa (prompt "Sair de casa"), CasaTrigger,
	  AndarSuperior/PisoSuperior, Barreiras
]]

local Kit = require("./Kit")
local Sushi = require("./Sushi")

return function(rbx)
	local k = Kit.new(rbx, 1)
	local Vector3, CFrame, Enum = k.Vector3, k.CFrame, k.Enum
	local V, CF = Vector3.new, CFrame.new
	local rad = math.rad

	local S = Sushi.colors(k)
	local C = {
		boxWall = k:rgb(255, 226, 214),
		boxFloor = k:rgb(240, 160, 140),
		plaster = k:rgb(250, 247, 240),
		red = k:rgb(150, 24, 30),
		redLight = k:rgb(200, 52, 58),
		charcoal = k:rgb(52, 48, 50),
		tatami = k:rgb(214, 204, 150),
		tatamiDark = k:rgb(196, 186, 130),
		tatamiEdge = k:rgb(46, 74, 54),
		glass = k:rgb(190, 230, 255),
		water = k:rgb(110, 190, 240),
		white = k:rgb(255, 255, 255),
		sky = k:rgb(150, 210, 255),
	}
	local NEON, GLASS = Enum.Material.Neon, Enum.Material.Glass
	local PLATES = { k:rgb(230, 60, 70), k:rgb(70, 130, 230), S.gold, k:rgb(90, 190, 110), k:rgb(240, 240, 240) }

	local HALF = 22
	local FLOOR = 1
	local STORY = 12
	local UP = FLOOR + STORY
	local WALL_TOP = UP + STORY

	local STAIR_X0, STAIR_X1 = -HALF, -HALF + 6
	local STEP_DEPTH = 1.6
	local STAIR_Z0 = -STORY * STEP_DEPTH

	local root = k:model("SushiHouseInterior")
	local box = k:model("CaixaResidencial", root)
	local shell = k:model("Estrutura", root)
	local ground = k:model("Terreo", root)
	local upper = k:model("AndarSuperior", root)
	local barriers = k:model("Barreiras", root)

	-- ═══════════════════════════════════════════
	-- Caixa gigante (mesmas medidas da Candy Mansion), tons de salmão
	-- ═══════════════════════════════════════════
	local BOX_X, BOX_Z, BOX_H, BOX_FLOOR = 600, 640, 110, -9
	local BOX_C = V(-220, 0, 222)
	k:box(box, "Chao", V(BOX_X, 2, BOX_Z), CF(BOX_C.X, BOX_FLOOR - 1, BOX_C.Z), C.boxFloor)
	k:box(box, "Teto", V(BOX_X, 2, BOX_Z), CF(BOX_C.X, BOX_FLOOR + BOX_H + 1, BOX_C.Z), C.boxWall)
	for _, side in ipairs({ -1, 1 }) do
		k:box(box, "Parede", V(4, BOX_H, BOX_Z), CF(BOX_C.X + side * (BOX_X / 2 + 2), BOX_FLOOR + BOX_H / 2, BOX_C.Z), C.boxWall)
		k:box(box, "Parede", V(BOX_X, BOX_H, 4), CF(BOX_C.X, BOX_FLOOR + BOX_H / 2, BOX_C.Z + side * (BOX_Z / 2 + 2)), C.boxWall)
	end

	-- ═══════════════════════════════════════════
	-- Base: tábua de sushi (geta) + tatames; nas bordas abertas, arroz com faixa de alga
	-- ═══════════════════════════════════════════
	k:box(shell, "Geta", V(HALF * 2 + 2, 9, HALF * 2 + 2), CF(0, FLOOR - 0.6 - 4.5, 0), S.wood)
	for _, z in ipairs({ -HALF + 6, HALF - 6 }) do
		k:box(shell, "GetaPe", V(HALF * 2 + 2.4, 3, 6), CF(0, FLOOR - 7.6, z), S.woodDark)
	end
	-- Tatames 4 x 8 com borda verde (fileiras alternadas, como no piso japonês)
	for i = 0, 10 do
		local x = -HALF + 2 + i * 4
		local z, j = -HALF - ((i % 2 == 0) and 0 or 4), 0
		while z < HALF do
			local z0, z1 = math.max(z, -HALF), math.min(z + 8, HALF)
			k:box(shell, "Tatame", V(3.9, 0.6, z1 - z0 - 0.1), CF(x, FLOOR - 0.3, (z0 + z1) / 2), ((i + j) % 2 == 0) and C.tatami or C.tatamiDark)
			z, j = z + 8, j + 1
		end
		k:box(shell, "TatameBorda", V(0.25, 0.62, HALF * 2), CF(x + 2, FLOOR - 0.3, 0), C.tatamiEdge)
	end
	-- Borda: camada de arroz com faixa de alga em volta (o piso vira um nigiri gigante)
	k:box(shell, "ArrozBorda", V(HALF * 2 + 2.4, 2.4, 1.4), CF(0, FLOOR - 1.8, -HALF - 1.1), S.rice)
	k:box(shell, "ArrozBorda", V(1.4, 2.4, HALF * 2 + 2.4), CF(HALF + 1.1, FLOOR - 1.8, 0), S.rice)
	Sushi.grains(k, shell, k:lookAt(V(0, FLOOR - 1.8, -HALF - 1.8), V(0, FLOOR - 1.8, -HALF - 10)), HALF * 2, 2, 60, S.riceShade, 0.8)
	Sushi.grains(k, shell, k:lookAt(V(HALF + 1.8, FLOOR - 1.8, 0), V(HALF + 10, FLOOR - 1.8, 0)), HALF * 2, 2, 60, S.riceShade, 0.8)
	for _, t in ipairs({ -12, 12 }) do
		k:box(shell, "FaixaAlga", V(4, 2.6, 1.6), CF(t, FLOOR - 1.8, -HALF - 1.1), S.nori)
		k:box(shell, "FaixaAlga", V(1.6, 2.6, 4), CF(HALF + 1.1, FLOOR - 1.8, t), S.nori)
	end

	-- ═══════════════════════════════════════════
	-- Paredes (-X e +Z): reboco branco, vigas vermelhas (como o exterior) e shoji
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
		k:box(shell, "Parede", size, cf, C.plaster)

		-- Rodapé grafite e viga vermelha no alto de cada andar
		size, cf = at(0, FLOOR + 1, 1.7, 2, length)
		k:box(shell, "Rodape", size, cf, C.charcoal)
		size, cf = at(0, UP - 0.6, 2.0, 1.8, length + 1.6)
		k:box(shell, "Viga", size, cf, C.red)
		size, cf = at(0, WALL_TOP - 0.6, 2.0, 1.4, length + 1.6)
		k:box(shell, "Viga", size, cf, C.red)

		-- Pilares de madeira escura a cada 11 studs, nos dois andares
		for s = -HALF + 0.5, HALF, 11 do
			size, cf = at(s, (FLOOR + WALL_TOP) / 2, 1.8, WALL_TOP - FLOOR, 1)
			k:box(shell, "Pilar", size, cf, S.woodDeep)
		end

		-- Ripas de shoji (grade fina) na metade de cima de cada andar
		for _, base in ipairs({ FLOOR + 5, UP + 3 }) do
			local top = base + STORY - 6.5
			size, cf = at(0, base, 1.6, 0.3, length)
			k:box(shell, "Ripa", size, cf, S.woodDark)
			size, cf = at(0, top, 1.6, 0.3, length)
			k:box(shell, "Ripa", size, cf, S.woodDark)
			for s = -HALF + 2.75, HALF - 1, 2.75 do
				size, cf = at(s, (base + top) / 2, 1.6, top - base, 0.25)
				k:box(shell, "Ripa", size, cf, S.woodDark)
			end
			size, cf = at(0, (base + top) / 2, 1.6, 0.25, length)
			k:box(shell, "Ripa", size, cf, S.woodDark)
		end

		-- Beiral grafite no topo com "telhas" redondas, como o telhado de fora
		size, cf = at(0, WALL_TOP + 0.5, 2.6, 1, length + 2.6)
		k:box(shell, "Beiral", size, cf, C.charcoal)
		for s = -HALF, HALF, 2 do
			local p = alongX and V(s, WALL_TOP + 1.1, HALF + 0.75) or V(-HALF - 0.75, WALL_TOP + 1.1, s)
			k:ball(shell, "Telha", 1.1, p, C.charcoal)
		end
	end
	wall(true)
	wall(false)
	-- Quina: maki gigante com ovas no topo
	k:vcyl(shell, "QuinaAlga", WALL_TOP - FLOOR + 1, 2.8, V(-HALF - 0.75, (FLOOR + WALL_TOP) / 2, HALF + 0.75), S.nori)
	k:vcyl(shell, "QuinaArroz", 0.3, 2.4, V(-HALF - 0.75, WALL_TOP + 1.65, HALF + 0.75), S.rice)
	for i = 0, 4 do
		local a = i / 5 * 2 * math.pi
		local r = (i == 0) and 0 or 0.6
		k:ball(shell, "QuinaOva", 0.7, V(-HALF - 0.75 + math.cos(a) * r, WALL_TOP + 2.05, HALF + 0.75 + math.sin(a) * r), S.ikura)
	end

	-- Janela redonda (como a do exterior) na parede +Z
	local function roundWindow(parent, x, y)
		k:cyl(parent, "JanelaMoldura", 0.6, 6, CF(x, y, HALF - 0.2) * CFrame.Angles(0, rad(90), 0), C.red)
		k:cyl(parent, "JanelaVidro", 0.7, 4.8, CF(x, y, HALF - 0.25) * CFrame.Angles(0, rad(90), 0), C.sky, { material = GLASS, transparency = 0.2 })
		k:box(parent, "JanelaCruz", V(0.3, 4.8, 0.5), CF(x, y, HALF - 0.6), S.woodDeep)
		k:box(parent, "JanelaCruz", V(4.8, 0.3, 0.5), CF(x, y, HALF - 0.6), S.woodDeep)
	end
	roundWindow(ground, 16, FLOOR + 7)
	roundWindow(upper, -2, UP + 6.5)

	-- Quadros com SurfaceGui (parede -X)
	local function frame(parent, z, y, title, bg, shape)
		k:box(parent, "QuadroMoldura", V(0.4, 5, 4), CF(-HALF + 0.2, y, z), S.woodDeep)
		local art = k:box(parent, "Quadro", V(0.2, 4.2, 3.2), CF(-HALF + 0.45, y, z), bg)
		k:sign(art, {
			face = Enum.NormalId.Right,
			bg = bg,
			frames = shape,
			lines = { { text = title, y = 0.74, h = 0.18, color = C.white, stroke = S.nori } },
		})
	end
	frame(ground, 8, FLOOR + 7.5, "NIGIRI", k:rgb(120, 180, 230), {
		{ x = 0.15, y = 0.32, w = 0.7, h = 0.22, color = S.rice, corner = 0.5 },
		{ x = 0.1, y = 0.18, w = 0.8, h = 0.18, color = S.salmon, corner = 0.4 },
		{ x = 0.43, y = 0.16, w = 0.14, h = 0.4, color = S.nori },
	})
	frame(upper, 14, UP + 6.5, "MAKI", k:rgb(255, 196, 120), {
		{ x = 0.2, y = 0.12, w = 0.6, h = 0.56, color = S.nori, corner = 0.5 },
		{ x = 0.27, y = 0.2, w = 0.46, h = 0.4, color = S.rice, corner = 0.5 },
		{ x = 0.4, y = 0.31, w = 0.2, h = 0.18, color = S.salmon, corner = 0.5 },
	})

	-- ═══════════════════════════════════════════
	-- Escada de tamago (degraus amarelos com faixa de alga) + corrimão de hashi
	-- ═══════════════════════════════════════════
	local stairs = k:model("Escada", ground)
	local stairCx = (STAIR_X0 + STAIR_X1) / 2
	for i = 1, STORY do
		local z0 = STAIR_Z0 + (i - 1) * STEP_DEPTH
		local top = FLOOR + i
		k:box(stairs, "Degrau", V(STAIR_X1 - STAIR_X0, top - FLOOR, STEP_DEPTH), CF(stairCx, (top + FLOOR) / 2, z0 + STEP_DEPTH / 2),
			(i % 2 == 0) and S.tamago or S.tamagoDark, { collide = false })
		k:box(stairs, "DegrauAlga", V(1.4, top - FLOOR + 0.06, STEP_DEPTH + 0.06), CF(stairCx + 1, (top + FLOOR) / 2 + 0.03, z0 + STEP_DEPTH / 2),
			S.nori, { collide = false })
	end
	local rampLowZ = STAIR_Z0 - STEP_DEPTH / 2
	local rampHighZ = STAIR_Z0 + (STORY - 0.5) * STEP_DEPTH
	k:ramp(stairs, "RampaEscada", STAIR_X0, STAIR_X1, rampLowZ, FLOOR, rampHighZ, UP)
	k:box(stairs, "RampaTopo", V(STAIR_X1 - STAIR_X0, 0.4, -rampHighZ + 0.4), CF(stairCx, UP - 0.2, rampHighZ / 2), C.white, { transparency = 1 })
	local railBottom = V(STAIR_X1 - 0.3, FLOOR + 3.5, STAIR_Z0 + 0.5)
	local railTop = V(STAIR_X1 - 0.3, UP + 3, -0.2)
	Sushi.chopstick(k, stairs, railBottom, railTop, 0.5)
	for i = 0, 4 do
		local p = railBottom:Lerp(railTop, i / 4)
		local stepTop = FLOOR + math.clamp(math.ceil((p.Z - STAIR_Z0) / STEP_DEPTH), 1, STORY)
		k:vcyl(stairs, "Pilar", p.Y - stepTop, 0.5, V(p.X, (p.Y + stepTop) / 2, p.Z), (i % 2 == 0) and C.red or S.wood)
	end

	-- ═══════════════════════════════════════════
	-- Mezanino: laje de tamago com faixa de alga + guarda-corpo de hashis
	-- ═══════════════════════════════════════════
	k:box(upper, "PisoSuperior", V(HALF * 2, 1, HALF), CF(0, UP - 0.5, HALF / 2), S.wood)
	k:box(upper, "BordaTamago", V(HALF * 2 + 0.4, 1.6, 0.8), CF(0, UP - 0.9, -0.2), S.tamago)
	k:box(upper, "BordaTamago", V(0.8, 1.6, HALF + 0.4), CF(HALF + 0.2, UP - 0.9, HALF / 2), S.tamago)
	for x = -HALF + 4, HALF - 2, 8 do
		k:box(upper, "BordaAlga", V(1.6, 1.7, 0.9), CF(x, UP - 0.9, -0.2), S.nori)
	end
	for i = 0, 7 do
		k:box(upper, "TatameCima", V(HALF * 2, 0.15, 2.6), CF(0, UP + 0.05, 1.4 + i * 2.75), (i % 2 == 0) and C.tatami or C.tatamiDark)
	end
	local function railing(from, to)
		local dir = to - from
		local n = math.max(1, math.floor(dir.Magnitude / 2.5))
		for i = 0, n do
			local p = from + dir * (i / n)
			k:vcyl(upper, "Hashi", 3, 0.45, p + V(0, 1.5, 0), (i % 2 == 0) and C.red or S.wood)
		end
		k:beam(upper, "Corrimao", from + V(0, 3.1, 0), to + V(0, 3.1, 0), 0.5, C.red)
	end
	railing(V(STAIR_X1 + 0.4, UP, 0.2), V(HALF - 0.4, UP, 0.2))
	railing(V(HALF - 0.4, UP, 0.4), V(HALF - 0.4, UP, HALF - 0.4))

	-- Lanternas vermelhas penduradas embaixo do mezanino
	for _, x in ipairs({ 0, 10 }) do
		local top = V(x, UP - 1, 2.5)
		k:vcyl(ground, "Cordao", 2, 0.15, top - V(0, 1, 0), C.charcoal)
		Sushi.lantern(k, ground, "Lanterna", top - V(0, 3.4, 0), 2.6, C.redLight, true)
	end

	-- ═══════════════════════════════════════════
	-- TÉRREO
	-- ═══════════════════════════════════════════
	-- Balcão de esteira (kaiten) encostado na parede +Z
	do
		local m = k:model("BalcaoKaiten", ground)
		local c = V(4, FLOOR, HALF - 2.6)
		k:box(m, "Balcao", V(16, 3.4, 3.4), CF(c + V(0, 1.7, 0)), S.wood)
		k:box(m, "BalcaoFaixa", V(16.1, 0.8, 3.5), CF(c + V(0, 0.8, 0)), C.red)
		k:box(m, "Esteira", V(15.4, 0.3, 2), CF(c + V(0, 3.55, -0.3)), k:rgb(170, 175, 185))
		for _, dz in ipairs({ -1.4, 0.8 }) do
			k:box(m, "Trilho", V(15.6, 0.5, 0.2), CF(c + V(0, 3.65, dz)), k:rgb(220, 224, 232))
		end
		for i = 0, 6 do
			local p = c + V(-6.6 + i * 2.2, 3.7, -0.3)
			Sushi.plate(k, m, p, 1.7, PLATES[i % #PLATES + 1])
			local kind = i % 4
			if kind == 0 then
				Sushi.nigiri(k, m, "Nigiri", CF(p + V(0, 0.2, 0)), 0.7, 0.6, 0.45, { stripes = true })
			elseif kind == 1 then
				Sushi.maki(k, m, "Maki", p + V(0, 0.2, 0), 0.8, 0.6, S.tuna)
			elseif kind == 2 then
				Sushi.gunkan(k, m, "Gunkan", p + V(0, 0.2, 0), 0.9, 0.6)
			else
				Sushi.nigiri(k, m, "NigiriTamago", CF(p + V(0, 0.2, 0)), 0.7, 0.6, 0.45, { topping = S.tamago, nori = true })
			end
		end
		-- Banquinhos de maki
		for i = -1, 1 do
			Sushi.maki(k, m, "BanquinhoMaki", c + V(i * 5, 0, -4.6), 2.6, 2.4, (i == 0) and S.tuna or S.salmon)
		end
		-- Plaquinha "SUSHI BAR" na parede
		local sign = k:box(m, "Letreiro", V(9, 1.8, 0.3), CF(c + V(0, 7.6, 2.1)), C.red)
		k:sign(sign, { face = Enum.NormalId.Front, bg = C.red, glow = true, lines = { { text = "SUSHI BAR", y = 0.12, h = 0.76, color = S.paper } } })
	end

	-- Cozinha de arroz: panela gigante, shoyu e pote de wasabi (parede +Z, à esquerda)
	do
		local m = k:model("CozinhaArroz", ground)
		local c = V(-11, FLOOR, HALF - 2.4)
		k:box(m, "Bancada", V(8, 4, 4), CF(c + V(0, 2, 0)), C.plaster)
		k:box(m, "BancadaFaixa", V(8.1, 0.8, 4.1), CF(c + V(0, 3.2, 0)), C.charcoal)
		k:box(m, "Tampo", V(8.6, 0.5, 4.6), CF(c + V(0, 4.25, 0)), S.wood)
		local pot = c + V(-1.8, 4.5, 0)
		k:vcyl(m, "Panela", 2.4, 3.2, pot + V(0, 1.2, 0), C.white)
		k:vcyl(m, "PanelaFaixa", 0.5, 3.3, pot + V(0, 1.6, 0), C.red)
		k:part(m, { name = "Arroz", shape = "Ball", size = V(3, 1.4, 3), cf = CF(pot + V(0, 2.5, 0)), color = S.rice })
		k:beam(m, "Colher", pot + V(0.4, 2.4, 0), pot + V(1.6, 4.4, 0.2), 0.3, S.woodDark)
		Sushi.soyBottle(k, m, "Shoyu", c + V(1.6, 4.5, 0.4), 2.6)
		k:vcyl(m, "PoteWasabi", 0.9, 1.4, c + V(3.2, 4.95, -0.6), S.porcelain)
		k:part(m, { name = "Wasabi", shape = "Ball", size = V(1, 0.8, 1), cf = CF(c + V(3.2, 5.5, -0.6)), color = S.wasabi })
	end

	-- Mesa baixa (chabudai) com barco de sushi e almofadas de nigiri
	do
		local m = k:model("MesaBarco", ground)
		local c = V(4, FLOOR, -6)
		k:vcyl(m, "Tapete", 0.2, 13, c + V(0, 0.1, 0), C.red)
		k:vcyl(m, "TapeteMiolo", 0.25, 11.4, c + V(0, 0.12, 0), C.charcoal)
		k:vcyl(m, "Tampo", 0.6, 7, c + V(0, 2.2, 0), S.wood)
		k:vcyl(m, "TampoBorda", 0.4, 7.2, c + V(0, 1.8, 0), S.woodDark)
		for i = 0, 3 do
			local a = i / 4 * 2 * math.pi + rad(45)
			k:box(m, "Pe", V(0.6, 1.6, 0.6), CF(c + V(math.cos(a) * 2.6, 0.8, math.sin(a) * 2.6)), S.woodDark)
		end
		-- Barco de madeira (como o do telhado da casa)
		local b = c + V(0, 2.5, 0)
		k:box(m, "Barco", V(4.4, 0.8, 1.8), CF(b + V(0, 0.4, 0)), S.wood)
		for _, side in ipairs({ -1, 1 }) do
			k:part(m, { name = "BarcoPonta", class = "WedgePart", size = V(1.8, 0.8, 1.4),
				cf = CF(b + V(side * 2.9, 0.4, 0)) * CFrame.Angles(0, side * rad(90), 0), color = S.wood })
		end
		k:box(m, "BarcoBorda", V(4.4, 0.25, 0.2), CF(b + V(0, 0.9, -0.85)), C.red)
		k:box(m, "BarcoBorda", V(4.4, 0.25, 0.2), CF(b + V(0, 0.9, 0.85)), C.red)
		Sushi.nigiri(k, m, "Nigiri", CF(b + V(-1.2, 0.8, 0)), 0.8, 0.7, 0.5, { stripes = true })
		Sushi.nigiri(k, m, "NigiriAtum", CF(b + V(0.2, 0.8, 0)), 0.8, 0.7, 0.5, { topping = S.tuna })
		Sushi.maki(k, m, "Maki", b + V(1.4, 0.8, -0.4), 0.8, 0.6)
		Sushi.maki(k, m, "Maki", b + V(1.4, 0.8, 0.4), 0.8, 0.6, S.cucumber)
		-- Pratinho de shoyu e gengibre
		k:vcyl(m, "PratoShoyu", 0.2, 1.4, c + V(-2, 2.6, 1.4), S.porcelain)
		k:vcyl(m, "Shoyu", 0.22, 1, c + V(-2, 2.62, 1.4), S.soy)
		k:vcyl(m, "PratoGengibre", 0.2, 1.4, c + V(2, 2.6, 1.6), S.porcelain)
		for i = 0, 3 do
			k:part(m, { name = "Gengibre", size = V(0.9, 0.1, 0.6), cf = CF(c + V(2, 2.75 + i * 0.06, 1.6)) * CFrame.Angles(0, i * 0.8, rad(12)), color = S.ginger })
		end
		-- Hashis apoiados na mesa
		Sushi.chopstick(k, m, c + V(-1, 2.6, -2.2), c + V(1.8, 2.6, -2.6), 0.18)
		Sushi.chopstick(k, m, c + V(-1, 2.6, -2.5), c + V(1.8, 2.6, -2.9), 0.18)
		-- Almofadas de nigiri em volta
		for i = 0, 3 do
			local a = i / 4 * 2 * math.pi
			local p = c + V(math.cos(a) * 5.2, 0.2, math.sin(a) * 5.2)
			local topping = ({ S.salmon, S.tuna, S.tamago, S.salmon })[i + 1]
			Sushi.nigiri(k, m, "AlmofadaNigiri", CF(p) * CFrame.Angles(0, -a + rad(90), 0), 1.6, 2.4, 0.9,
				{ topping = topping, stripes = topping == S.salmon, nori = topping == S.tamago })
		end
	end

	-- Aquário com peixinhos (embaixo da janela redonda, canto da frente)
	do
		local m = k:model("Aquario", ground)
		local c = V(16, FLOOR, HALF - 3)
		k:box(m, "Movel", V(6, 2.4, 3), CF(c + V(0, 1.2, 0)), C.charcoal)
		k:box(m, "Vidro", V(5.6, 3, 2.6), CF(c + V(0, 3.9, 0)), C.water, { material = GLASS, transparency = 0.45 })
		k:box(m, "Areia", V(5.4, 0.4, 2.4), CF(c + V(0, 2.6, 0)), k:rgb(250, 226, 170))
		k:box(m, "Tampa", V(5.8, 0.3, 2.8), CF(c + V(0, 5.5, 0)), C.red)
		for i = 0, 2 do
			local f = c + V(-1.6 + i * 1.6, 3.6 + (i % 2) * 0.8, 0)
			local color = (i == 1) and S.tamago or S.salmon
			k:part(m, { name = "Peixe", shape = "Ball", size = V(0.8, 0.8, 0.8), cf = CF(f), color = color })
			k:part(m, { name = "Rabo", class = "WedgePart", size = V(0.1, 0.5, 0.5), cf = CF(f + V(-0.55, 0, 0)) * CFrame.Angles(0, rad(90), 0), color = color })
		end
		for i = 0, 2 do
			k:vcyl(m, "Alga", 1.6 + i * 0.4, 0.25, c + V(-2 + i * 2, 3.6 + i * 0.2, 0.6), S.cucumber)
		end
	end

	-- Bambu num vaso e lâmpada andon
	do
		local m = k:model("Bambu", ground)
		local p = V(-12, FLOOR, -4)
		k:vcyl(m, "Vaso", 2, 3, p + V(0, 1, 0), C.charcoal)
		for i, off in ipairs({ V(-0.5, 0, 0), V(0.5, 0, 0.3), V(0, 0, -0.5) }) do
			local h = 6 + i
			for seg = 0, h - 1, 1.5 do
				k:vcyl(m, "Gomo", 1.4, 0.5, p + off + V(0, 2.75 + seg, 0), (seg % 3 == 0) and S.bamboo or S.bambooDark)
			end
			k:part(m, { name = "Folha", size = V(1.6, 0.1, 0.5), cf = CF(p + off + V(0.6, 2 + h, 0)) * CFrame.Angles(0, i, rad(20)), color = S.bamboo })
		end
	end
	Sushi.andon(k, ground, "Andon", V(HALF - 3, FLOOR, -7), 2.4, 4.4, true)
	Sushi.soyBottle(k, ground, "ShoyuGigante", V(HALF - 1.5, FLOOR, 2), 7)

	-- ═══════════════════════════════════════════
	-- MEZANINO: quarto
	-- ═══════════════════════════════════════════
	-- Cama de nigiri de salmão (arroz de colchão, fatia de cobertor, faixa de alga)
	do
		local m = k:model("CamaNigiri", upper)
		local base = V(-10, UP, 12.5)
		Sushi.nigiri(k, m, "Cama", CF(base) * CFrame.Angles(0, rad(90), 0), 8, 8.5, 2.8,
			{ stripes = true, nori = true, droop = 18, grains = 26 })
		-- Travesseiro de tamago na cabeceira (+Z)
		Sushi.nigiri(k, m, "Travesseiro", CF(base + V(0, 3.6, 4.6)), 3.2, 2, 0.8, { topping = S.tamago, nori = true })
		k:box(m, "Cabeceira", V(9.4, 6, 1), CF(base + V(0, 3, 7.2)), C.red)
		k:box(m, "CabeceiraTopo", V(10.2, 0.8, 1.4), CF(base + V(0, 6.2, 7.2)), C.charcoal)
	end

	-- Criado-mudo de maki com lanterna
	do
		local m = k:model("CriadoMaki", upper)
		local p = V(-18.5, UP, 18)
		Sushi.maki(k, m, "Maki", p, 3.6, 3, S.salmon)
		Sushi.lantern(k, m, "Lanterna", p + V(0, 4.6, 0), 1.8, C.redLight, true)
	end

	-- Guarda-roupa de bentô (caixa laqueada preta com bordas vermelhas e comidinhas)
	do
		local m = k:model("GuardaRoupaBento", upper)
		local c = V(6, UP + 5.5, HALF - 1.6)
		k:box(m, "Caixa", V(7, 11, 2.4), CF(c), C.charcoal)
		k:box(m, "Borda", V(7.3, 0.5, 2.6), CF(c + V(0, 5.3, 0)), C.red)
		k:box(m, "Borda", V(7.3, 0.5, 2.6), CF(c + V(0, -5.3, 0)), C.red)
		local cells = {
			{ -1.7, 2.6, S.rice }, { 1.7, 2.6, S.salmon },
			{ -1.7, -0.6, S.tamago }, { 1.7, -0.6, S.cucumber },
			{ -1.7, -3.6, S.ginger }, { 1.7, -3.6, S.tuna },
		}
		for _, cell in ipairs(cells) do
			local center = c + V(cell[1], cell[2], -1.25)
			k:box(m, "Gaveta", V(3.1, 2.8, 0.2), CF(center), C.red)
			k:box(m, "GavetaFundo", V(2.7, 2.4, 0.25), CF(center + V(0, 0, -0.02)), C.charcoal)
			k:ball(m, "Comidinha", 1.3, center + V(0, 0, -0.4), cell[3])
		end
		local label = k:box(m, "Rotulo", V(4, 1.2, 0.2), CF(c + V(0, 4.4, -1.3)), C.red)
		k:sign(label, { face = Enum.NormalId.Front, bg = C.red, lines = { { text = "BENTÔ", y = 0.1, h = 0.8, color = S.gold } } })
	end

	-- Tapete de maki cortado e pelúcia de ebi
	do
		local m = k:model("TapeteMaki", upper)
		local c = V(2, UP, 9)
		k:vcyl(m, "Alga", 0.2, 8.4, c + V(0, 0.15, 0), S.nori)
		k:vcyl(m, "Arroz", 0.25, 7.2, c + V(0, 0.18, 0), S.rice)
		k:vcyl(m, "Salmao", 0.3, 2.6, c + V(0, 0.2, 0), S.salmon)
		for i = 0, 4 do
			local a = i / 5 * 2 * math.pi
			k:vcyl(m, "Pepino", 0.3, 1.1, c + V(math.cos(a) * 2.2, 0.2, math.sin(a) * 2.2), S.cucumber)
		end
		for _ = 1, 16 do
			local a, r = k:rand(0, 2 * math.pi), k:rand(2.8, 3.4)
			k:box(m, "Gergelim", V(0.35, 0.1, 0.2), CF(c + V(math.cos(a) * r, 0.33, math.sin(a) * r)) * CFrame.Angles(0, a, 0), S.sesame)
		end

		-- Ebi: arroz + camarão listrado + rabinho
		local e = c + V(9, 0, 1)
		k:box(m, "EbiArroz", V(4, 1.4, 2.2), CF(e + V(0, 0.7, 0)), S.rice)
		for i = 0, 4 do
			k:box(m, "EbiGomo", V(0.8, 0.8, 2.4), CF(e + V(-1.6 + i * 0.8, 1.8, 0)), (i % 2 == 0) and S.shrimp or S.salmonFat)
		end
		k:part(m, { name = "EbiRabo", class = "WedgePart", size = V(2.4, 1.4, 1), cf = CF(e + V(2.6, 2.2, 0)) * CFrame.Angles(0, rad(90), 0), color = S.tuna })
	end

	-- Penteadeira com espelho de prato laqueado
	do
		local m = k:model("Penteadeira", upper)
		local c = V(15, UP, HALF - 2)
		k:box(m, "Mesa", V(6, 3.4, 2.6), CF(c + V(0, 1.7, 0)), S.wood)
		k:box(m, "Gaveta", V(5, 1, 0.3), CF(c + V(0, 2.2, -1.35)), C.red)
		k:cyl(m, "Espelho", 0.5, 4.6, CF(c + V(0, 6.2, 0.6)) * CFrame.Angles(0, rad(90), 0), C.red)
		k:cyl(m, "Vidro", 0.6, 3.6, CF(c + V(0, 6.2, 0.55)) * CFrame.Angles(0, rad(90), 0), C.glass, { material = GLASS, transparency = 0.1 })
		k:vcyl(m, "Bule", 1.1, 1.2, c + V(-1.8, 4, -0.3), S.wasabi)
		k:vcyl(m, "BuleTampa", 0.3, 0.7, c + V(-1.8, 4.7, -0.3), S.wasabiDark)
		k:vcyl(m, "Xicara", 0.6, 0.7, c + V(-0.6, 3.7, -0.5), S.porcelain)
	end
	Sushi.andon(k, upper, "Andon", V(HALF - 3, UP, HALF - 6.5), 2.4, 4.4, true)

	-- ═══════════════════════════════════════════
	-- Saída: esteirinha de bambu (makisu) no canto aberto do térreo
	-- ═══════════════════════════════════════════
	do
		local m = k:model("Saida", root)
		local c = V(16, FLOOR, -17)
		k:box(m, "SaidaCasa", V(6, 0.3, 4), CF(c + V(0, 0.15, 0)), S.bambooDark)
		for i = 0, 11 do
			k:box(m, "Vareta", V(0.42, 0.12, 4), CF(c + V(-2.75 + i * 0.5, 0.36, 0)), (i % 2 == 0) and S.bamboo or k:rgb(200, 220, 140), { collide = false })
		end
		for _, z in ipairs({ -1.2, 1.2 }) do
			k:box(m, "Linha", V(6.05, 0.14, 0.12), CF(c + V(0, 0.4, z)), C.red, { collide = false })
		end
		Sushi.chopstick(k, m, c + V(3.6, 0, 2.4), c + V(3.6, 3.6, 2.4), 0.4)
		local sign = k:box(m, "Placa", V(3.2, 1.4, 0.3), CF(c + V(3.6, 3.9, 2.4)) * CFrame.Angles(0, rad(-45), 0), C.red)
		k:sign(sign, { face = Enum.NormalId.Front, bg = C.red, glow = true, lines = { { text = "SAÍDA", y = 0.1, h = 0.8, color = C.white } } })
		k:sign(sign, { face = Enum.NormalId.Back, bg = C.red, glow = true, lines = { { text = "SAÍDA", y = 0.1, h = 0.8, color = C.white } } })
	end


	-- Botão "Trocar Sabor" no guarda-roupa (WardrobeBillboardController procura "wardrobe/Click" na raiz)
	do
		local m = k:model("wardrobe", root)
		k:box(m, "Click", V(0.4, 1, 2), CF(6, UP + 4, HALF - 3), C.white, { transparency = 1, collide = false })
	end

	k:box(root, "SpawnInterior", V(4, 1, 2), k:lookAt(V(12, FLOOR + 0.5, -12), V(0, FLOOR + 0.5, 0)), C.white,
		{ transparency = 1, collide = false })
	k:box(root, "CasaTrigger", V(HALF * 2, WALL_TOP - FLOOR, HALF * 2), CF(0, (FLOOR + WALL_TOP) / 2, 0), C.white,
		{ transparency = 1, collide = false })

	-- ═══════════════════════════════════════════
	-- Barreiras invisíveis
	-- ═══════════════════════════════════════════
	local barrierH = WALL_TOP - FLOOR + 6
	k:box(barriers, "BarreiraFrente", V(HALF * 2 + 4, barrierH, 1), CF(0, FLOOR + barrierH / 2, -HALF - 0.5), C.white, { transparency = 1 })
	k:box(barriers, "BarreiraLado", V(1, barrierH, HALF * 2 + 4), CF(HALF + 0.5, FLOOR + barrierH / 2, 0), C.white, { transparency = 1 })
	local railLen = HALF - STAIR_X1
	k:box(barriers, "BarreiraMezanino", V(railLen, 8, 0.6), CF(STAIR_X1 + railLen / 2, UP + 4, 0.2), C.white, { transparency = 1 })
	k:box(barriers, "BarreiraTeto", V(HALF * 2 + 4, 1, HALF * 2 + 4), CF(0, WALL_TOP + 6, 0), C.white, { transparency = 1 })

	root.WorldPivot = CF(0, FLOOR, 0)
	return root
end
