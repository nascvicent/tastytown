--[[
	Interior do CineCorn — cinema temático de pipoca.

	Espaço local (o InteriorService posiciona o modelo no mundo):
	  • x ∈ [-36, 36], entrada em z = 0, tela em z = 120
	  • Lobby: z ∈ [0, 36], piso em y = 0
	  • Sala: z ∈ [36, 121], arquibancada descendo em direção à tela
	Partes especiais (usadas pelo InteriorService):
	  • SpawnInterior — onde o jogador aparece ao entrar
	  • Saida — gatilho invisível na porta; tocar leva de volta para fora
]]

local Kit = require("./Kit")

-- Os personagens do jogo têm ~3,7 studs (o rig padrão tem ~5,3): o código usa
-- medidas de rig padrão e o Kit escala tudo por este fator.
local SCALE = 0.7

return function(rbx)
	local k = Kit.new(rbx, SCALE)
	local Vector3, CFrame, Enum = k.Vector3, k.CFrame, k.Enum
	local V, CF = Vector3.new, CFrame.new
	local rad = math.rad

	-- ═══════════════════════════════════════════
	-- Paleta (mesmas cores vivas do exterior: listras vermelhas/brancas e pipoca)
	-- ═══════════════════════════════════════════
	local C = {
		red = k:rgb(232, 62, 70),
		redDark = k:rgb(185, 35, 50),
		white = k:rgb(252, 248, 240),
		cream = k:rgb(255, 240, 212),
		butter = k:rgb(255, 222, 130),
		popcorn = k:rgb(255, 246, 215),
		popcornButter = k:rgb(255, 214, 100),
		gold = k:rgb(245, 190, 60),
		wood = k:rgb(196, 128, 78),
		woodDark = k:rgb(140, 85, 50),
		purple = k:rgb(86, 48, 118),
		purpleDark = k:rgb(58, 32, 84),
		navy = k:rgb(34, 26, 62),
		carpet = k:rgb(128, 30, 52),
		seat = k:rgb(210, 45, 62),
		seatDark = k:rgb(70, 40, 55),
		metal = k:rgb(205, 210, 220),
		glass = k:rgb(200, 235, 255),
		mint = k:rgb(140, 225, 190),
		pink = k:rgb(255, 160, 200),
		lavender = k:rgb(190, 160, 240),
		sky = k:rgb(110, 190, 245),
		green = k:rgb(70, 210, 110),
		black = k:rgb(30, 24, 36),
	}
	local NEON = Enum.Material.Neon
	local GLASS = Enum.Material.Glass

	local W, L, H = 72, 120, 30
	local HALF = W / 2
	local LOBBY = 36
	local BOTTOM = -10 -- fundo da sala rebaixada

	local root = k:model("CineCornInterior")
	root:SetAttribute("BuildScale", SCALE)
	local shell = k:model("Estrutura", root)
	local lobby = k:model("Lobby", root)
	local snack = k:model("Lanchonete", root)
	local hall = k:model("Sala", root)
	local seats = k:model("Poltronas", root)
	local decor = k:model("Decoracao", root)
	local lights = k:model("Luzes", root)
	local gates = k:model("Portas", root)

	-- ═══════════════════════════════════════════
	-- Props de comida reutilizáveis
	-- ═══════════════════════════════════════════

	-- Balde de pipoca listrado (ripas inclinadas para fora) com pipoca em cúpula
	local function popcornBucket(parent, base, radius, height, slats, kernels)
		local m = k:model("BaldePipoca", parent)
		local tilt = rad(8)
		local topRadius = radius + math.sin(tilt) * height
		local width = 2 * math.pi * topRadius / slats * 1.04
		k:vcyl(m, "Fundo", 0.3, radius * 2, base + V(0, 0.15, 0), C.white)
		for i = 0, slats - 1 do
			local a = i / slats * 2 * math.pi
			local radial = V(math.cos(a), 0, math.sin(a))
			local tangent = V(-math.sin(a), 0, math.cos(a))
			local up = V(0, math.cos(tilt), 0) + radial * math.sin(tilt)
			local out = radial * math.cos(tilt) - V(0, math.sin(tilt), 0)
			local center = base + radial * (radius + math.sin(tilt) * height / 2) + V(0, height / 2, 0)
			k:part(m, {
				name = "Ripa",
				size = V(width, height, math.max(radius * 0.08, 0.2)),
				cf = CFrame.fromMatrix(center, tangent, up, -out),
				color = (i % 2 == 0) and C.red or C.white,
			})
		end
		-- Pipoca: bolinhas numa cúpula acima da borda
		local top = base + V(0, height, 0)
		local dome = topRadius * 0.7
		for _ = 1, kernels do
			local a = k:rand(0, 2 * math.pi)
			local r = math.sqrt(k:rand()) * topRadius * 0.95
			local h = (1 - (r / topRadius) ^ 2) * dome * k:rand(0.55, 1)
			local d = topRadius * k:rand(0.28, 0.42)
			k:ball(m, "Pipoca", d, top + V(math.cos(a) * r, h - d * 0.15, math.sin(a) * r),
				k:pick({ C.popcorn, C.popcorn, C.popcornButter, C.cream }))
		end
		return m
	end

	-- Copo de refrigerante gigante com tampa e canudo
	local function sodaCup(parent, base, scale, band)
		local m = k:model("CopoRefri", parent)
		local h, d = 6 * scale, 3.6 * scale
		k:vcyl(m, "Copo", h, d, base + V(0, h / 2, 0), C.white)
		k:vcyl(m, "Faixa", h * 0.32, d * 1.02, base + V(0, h * 0.5, 0), band)
		k:vcyl(m, "Tampa", 0.45 * scale, d * 1.08, base + V(0, h + 0.2 * scale, 0), C.white)
		k:vcyl(m, "Domo", 0.5 * scale, d * 0.7, base + V(0, h + 0.6 * scale, 0), C.white)
		local strawBase = base + V(0.4 * scale, h + 0.6 * scale, 0)
		k:beam(m, "Canudo", strawBase, strawBase + V(0.9 * scale, 3.2 * scale, 0.3 * scale), 0.38 * scale, C.red)
		return m
	end

	-- Cachorro-quente (pão, salsicha e mostarda em zigue-zague)
	local function hotDog(parent, cf, scale)
		local m = k:model("CachorroQuente", parent)
		local s = scale
		for _, side in ipairs({ -1, 1 }) do
			k:cyl(m, "Pao", 6 * s, 1.6 * s, cf * CF(0, 0, side * 0.75 * s), k:rgb(232, 170, 95))
		end
		k:cyl(m, "Salsicha", 7 * s, 1.3 * s, cf * CF(0, 0.55 * s, 0), k:rgb(200, 80, 60))
		for i = -2, 2 do
			k:box(m, "Mostarda", V(1.1 * s, 0.25 * s, 0.35 * s),
				cf * CF(i * 1.1 * s, 1.25 * s, 0) * CFrame.Angles(0, (i % 2 == 0) and rad(35) or rad(-35), 0),
				k:rgb(255, 215, 40))
		end
		return m
	end

	-- Bandeja de nachos com potinho de cheddar
	local function nachos(parent, cf, scale)
		local m = k:model("Nachos", parent)
		local s = scale
		k:box(m, "Bandeja", V(5 * s, 0.6 * s, 3.5 * s), cf, C.red)
		for i = 1, 9 do
			local x, z = k:rand(-1.8, 1.0) * s, k:rand(-1.2, 1.2) * s
			k:part(m, {
				name = "Chip",
				class = "WedgePart",
				size = V(0.25 * s, 1.1 * s, 1.4 * s),
				cf = cf * CF(x, 0.75 * s, z) * CFrame.Angles(rad(k:rand(-25, 25)), rad(k:rand(0, 360)), rad(k:rand(60, 110))),
				color = k:rgb(250, 200, 70),
			})
		end
		k:vcyl(m, "Cheddar", 0.9 * s, 1.4 * s, (cf * CF(1.7 * s, 0.6 * s, 0)).Position, k:rgb(255, 165, 30))
		return m
	end

	-- Pufe de macaron (assento do lobby)
	local function macaron(parent, base, color)
		local m = k:model("PufeMacaron", parent)
		k:vcyl(m, "Base", 1, 3.4, base + V(0, 0.5, 0), color)
		k:vcyl(m, "Recheio", 0.55, 3.1, base + V(0, 1.25, 0), C.white)
		k:vcyl(m, "Topo", 1, 3.4, base + V(0, 2.0, 0), color)
		return m
	end

	-- Moldura dourada com cartaz de filme "comestível"
	local function poster(parent, cf, title, subtitle, bg, accent)
		local m = k:model("Cartaz", parent)
		k:box(m, "Moldura", V(6, 8.4, 0.4), cf, C.gold)
		local face = k:box(m, "Cartaz", V(5.2, 7.6, 0.2), cf * CF(0, 0, -0.25), bg)
		k:sign(face, {
			face = Enum.NormalId.Front,
			bg = bg,
			glow = true,
			frames = {
				{ x = 0.2, y = 0.12, w = 0.6, h = 0.4, color = accent, corner = 0.5 },
			},
			lines = {
				{ text = "★ CINECORN ★", y = 0.03, h = 0.07, color = C.butter },
				{ text = title, y = 0.58, h = 0.2, color = C.white, stroke = C.black },
				{ text = subtitle, y = 0.84, h = 0.08, color = C.butter },
			},
		})
		return m
	end

	-- ═══════════════════════════════════════════
	-- Estrutura: pisos, paredes, teto
	-- ═══════════════════════════════════════════

	-- Piso do lobby: xadrez creme/manteiga
	for ix = 0, 11 do
		for iz = 0, 5 do
			k:box(shell, "PisoLobby", V(6, 1, 6), CF(-HALF + 3 + ix * 6, -0.5, 3 + iz * 6),
				((ix + iz) % 2 == 0) and C.cream or C.butter)
		end
	end

	-- Paredes externas (lado de fora) — o acabamento interno vem por cima
	local function wall(name, size, center, color)
		return k:box(shell, name, size, CF(center), color)
	end
	-- Lobby
	wall("ParedeLobbyEsq", V(2, H, LOBBY), V(-HALF - 1, H / 2, LOBBY / 2), C.white)
	wall("ParedeLobbyDir", V(2, H, LOBBY), V(HALF + 1, H / 2, LOBBY / 2), C.white)
	-- Frente com abertura de porta (10 x 12)
	wall("FrenteEsq", V(HALF - 5, H, 2), V(-(HALF + 5) / 2, H / 2, -1), C.white)
	wall("FrenteDir", V(HALF - 5, H, 2), V((HALF + 5) / 2, H / 2, -1), C.white)
	wall("FrenteTopo", V(10, H - 12, 2), V(0, 12 + (H - 12) / 2, -1), C.white)
	-- Divisória lobby/sala com portal (16 x 14)
	wall("DivisoriaEsq", V(HALF - 8, H, 2), V(-(HALF + 8) / 2, H / 2, LOBBY), C.white)
	wall("DivisoriaDir", V(HALF - 8, H, 2), V((HALF + 8) / 2, H / 2, LOBBY), C.white)
	wall("DivisoriaTopo", V(16, H - 14, 2), V(0, 14 + (H - 14) / 2, LOBBY), C.white)
	-- Sala (desce até BOTTOM)
	local hallDepth = L + 1 - LOBBY
	wall("ParedeSalaEsq", V(2, H - BOTTOM, hallDepth), V(-HALF - 1, (H + BOTTOM) / 2, LOBBY + hallDepth / 2), C.purpleDark)
	wall("ParedeSalaDir", V(2, H - BOTTOM, hallDepth), V(HALF + 1, (H + BOTTOM) / 2, LOBBY + hallDepth / 2), C.purpleDark)
	wall("ParedeTela", V(W + 4, H - BOTTOM, 2), V(0, (H + BOTTOM) / 2, L + 2), C.purpleDark)
	-- Tetos
	k:box(shell, "TetoLobby", V(W + 4, 1, LOBBY + 2), CF(0, H + 0.5, LOBBY / 2), C.cream)
	k:box(shell, "TetoSala", V(W + 4, 1, hallDepth + 2), CF(0, H + 0.5, LOBBY + hallDepth / 2), C.navy)

	-- Acabamento do lobby: listras vermelhas (como o balde do exterior), rodapé e frisos dourados
	local function stripes(along, fixed, from, to, normalSign, skip)
		for s = from + 2, to - 2, 8 do
			if not (skip and skip(s)) then
				local cf
				if along == "z" then
					cf = CF(fixed + normalSign * 0.1, H / 2, s)
					k:box(lobby, "Listra", V(0.2, H, 4), cf, C.red)
				else
					cf = CF(s, H / 2, fixed + normalSign * 0.1)
					k:box(lobby, "Listra", V(4, H, 0.2), cf, C.red)
				end
			end
		end
	end
	stripes("z", -HALF, 0, LOBBY, 1)
	stripes("z", HALF, 0, LOBBY, -1)
	stripes("x", 0, -HALF, HALF, 1, function(s) return math.abs(s) < 8 end)          -- frente (pula a porta)
	stripes("x", LOBBY - 1, -HALF, HALF, -1, function(s) return math.abs(s) < 11 end) -- divisória (pula o portal)

	for _, side in ipairs({ -1, 1 }) do
		k:box(lobby, "Rodape", V(0.4, 3, LOBBY), CF(side * (HALF - 0.2), 1.5, LOBBY / 2), C.redDark)
		k:box(lobby, "Friso", V(0.5, 0.6, LOBBY), CF(side * (HALF - 0.25), 3.3, LOBBY / 2), C.gold)
		k:box(lobby, "FrisoTopo", V(0.5, 0.8, LOBBY), CF(side * (HALF - 0.25), H - 1, LOBBY / 2), C.gold)
	end

	-- ═══════════════════════════════════════════
	-- Lobby: porta de saída, tapete, spawn
	-- ═══════════════════════════════════════════
	-- Porta dupla vermelha com janelinhas redondas
	for _, side in ipairs({ -1, 1 }) do
		k:box(gates, "PortaFolha", V(4.8, 11.6, 0.6), CF(side * 2.5, 5.8, -0.3), C.red)
		-- Janela redonda: cilindro deitado no eixo Z
		k:cyl(gates, "Janela", 0.7, 2, CF(side * 2.5, 8, 0.05) * CFrame.Angles(0, rad(90), 0), C.glass, { material = GLASS, transparency = 0.3 })
		k:box(gates, "Puxador", V(0.3, 2, 0.4), CF(side * 0.8, 5.5, 0.2), C.gold)
	end
	k:box(gates, "Batente", V(11, 0.8, 1), CF(0, 12.2, 0), C.gold)
	local exitSign = k:box(gates, "PlacaSaida", V(5, 1.6, 0.3), CF(0, 13.6, 0.2), C.green, { material = NEON })
	k:sign(exitSign, { face = Enum.NormalId.Back, bg = C.green, glow = true,
		lines = { { text = "SAÍDA", y = 0.1, h = 0.8, color = C.white } } })

	k:box(gates, "Saida", V(10, 10, 2), CF(0, 5, 1.2), C.green,
		{ transparency = 1, collide = false, touch = true })
	k:box(gates, "SpawnInterior", V(4, 1, 4), CFrame.lookAt(V(0, 0.5, 9), V(0, 0.5, 30)), C.green,
		{ transparency = 1, collide = false })

	-- Tapete vermelho da porta até a sala
	k:box(lobby, "Tapete", V(8, 0.1, LOBBY - 2), CF(0, 0.05, LOBBY / 2), C.carpet)
	for _, side in ipairs({ -1, 1 }) do
		k:box(lobby, "TapeteBorda", V(0.5, 0.12, LOBBY - 2), CF(side * 4, 0.06, LOBBY / 2), C.gold)
	end

	-- ═══════════════════════════════════════════
	-- Lanchonete (lado esquerdo)
	-- ═══════════════════════════════════════════
	local counterX = -HALF + 7
	k:box(snack, "Balcao", V(4, 4, 22), CF(counterX, 2, 18), C.white)
	for z = 8, 28, 4 do
		k:box(snack, "BalcaoListra", V(0.2, 4, 2), CF(counterX + 2.05, 2, z), C.red)
	end
	k:box(snack, "Tampo", V(5, 0.6, 23), CF(counterX - 0.2, 4.3, 18), C.wood)
	k:box(snack, "BalcaoFundo", V(3, 7, 26), CF(-HALF + 1.5, 3.5, 18), C.woodDark)
	k:box(snack, "TampoFundo", V(3.4, 0.5, 26), CF(-HALF + 1.7, 7.25, 18), C.wood)

	-- Pipoqueira: base vermelha, vitrine de vidro cheia de pipoca, teto com bolinha dourada
	local machine = k:model("Pipoqueira", snack)
	local mBase = V(counterX - 0.2, 4.6, 11)
	k:box(machine, "Base", V(3.6, 1.2, 3.6), CF(mBase + V(0, 0.6, 0)), C.red)
	k:box(machine, "Vitrine", V(3.4, 3.6, 3.4), CF(mBase + V(0, 3, 0)), C.glass, { material = GLASS, transparency = 0.55 })
	for _ = 1, 26 do
		k:ball(machine, "Pipoca", k:rand(0.55, 0.8),
			mBase + V(k:rand(-1.4, 1.4), 1.4 + k:rand(0, 1.3), k:rand(-1.4, 1.4)),
			k:pick({ C.popcorn, C.popcornButter, C.cream }))
	end
	k:box(machine, "Teto", V(3.8, 0.8, 3.8), CF(mBase + V(0, 5.2, 0)), C.red)
	k:ball(machine, "Topo", 0.9, mBase + V(0, 6, 0), C.gold)
	local mSign = k:box(machine, "Letreiro", V(3.2, 0.7, 0.2), CF(mBase + V(0, 5.2, 0) + V(1.95, 0, 0)) * CFrame.Angles(0, rad(-90), 0), C.red)
	k:sign(mSign, { face = Enum.NormalId.Front, bg = C.red, glow = true,
		lines = { { text = "PIPOCA", y = 0.1, h = 0.8, color = C.butter } } })

	-- Máquina de refri com três bicos
	local dispenser = k:model("MaquinaRefri", snack)
	local dBase = V(counterX - 0.4, 4.6, 19)
	k:box(dispenser, "Corpo", V(2.6, 3.4, 4), CF(dBase + V(0, 1.7, 0)), C.metal)
	for i, color in ipairs({ C.redDark, C.sky, C.mint }) do
		local z = dBase.Z - 1.3 + (i - 1) * 1.3
		k:box(dispenser, "Painel", V(0.15, 1.2, 1), CF(dBase.X + 1.35, dBase.Y + 2.4, z), color)
		k:vcyl(dispenser, "Bico", 0.5, 0.35, V(dBase.X + 1.1, dBase.Y + 1.2, z), C.black)
	end
	for i = 0, 2 do
		k:vcyl(dispenser, "CopoPilha", 0.6, 0.9, V(counterX + 0.6, 4.9 + i * 0.5, 22.5), C.white)
	end

	-- Vitrine de doces (bolinhas coloridas)
	local candy = k:model("VitrineDoces", snack)
	k:box(candy, "Vidro", V(3.2, 2.4, 4), CF(counterX - 0.2, 5.8, 26), C.glass, { material = GLASS, transparency = 0.6 })
	for _ = 1, 22 do
		k:ball(candy, "Bala", 0.55, V(counterX - 0.2 + k:rand(-1.3, 1.3), 4.9 + k:rand(0, 0.9), 26 + k:rand(-1.7, 1.7)),
			k:pick({ C.pink, C.mint, C.lavender, C.sky, C.butter, C.red }))
	end
	k:box(snack, "Caixa", V(1.6, 1.2, 1.8), CF(counterX - 0.2, 5.2, 15), C.black)

	-- Cardápio na parede
	local menu = k:box(snack, "Cardapio", V(0.4, 7, 18), CF(-HALF + 0.3, 13, 18), C.black)
	k:sign(menu, {
		face = Enum.NormalId.Right,
		bg = k:rgb(45, 28, 40),
		glow = true,
		frames = { { x = 0, y = 0, w = 1, h = 0.2, color = C.red } },
		lines = {
			{ text = "LANCHONETE", y = 0.02, h = 0.16, color = C.butter },
			{ text = "Pipoca Amanteigada", y = 0.27, h = 0.12, color = C.white, align = "left", w = 0.62 },
			{ text = "$5", y = 0.27, h = 0.12, color = C.butter, align = "right", x = 0.7, w = 0.25 },
			{ text = "Refri Gigante", y = 0.44, h = 0.12, color = C.white, align = "left", w = 0.62 },
			{ text = "$3", y = 0.44, h = 0.12, color = C.butter, align = "right", x = 0.7, w = 0.25 },
			{ text = "Cachorro-Quente", y = 0.61, h = 0.12, color = C.white, align = "left", w = 0.62 },
			{ text = "$6", y = 0.61, h = 0.12, color = C.butter, align = "right", x = 0.7, w = 0.25 },
			{ text = "Nachos com Cheddar", y = 0.78, h = 0.12, color = C.white, align = "left", w = 0.62 },
			{ text = "$7", y = 0.78, h = 0.12, color = C.butter, align = "right", x = 0.7, w = 0.25 },
		},
	})

	sodaCup(snack, V(-HALF + 3, 7.5, 31.5), 0.7, C.sky)
	sodaCup(snack, V(-HALF + 3, 7.5, 5), 0.6, C.red)

	-- ═══════════════════════════════════════════
	-- Bilheteria (lado direito) + fila com pedestais
	-- ═══════════════════════════════════════════
	local booth = k:model("Bilheteria", lobby)
	local bx = HALF - 4
	k:box(booth, "Corpo", V(7, 4, 10), CF(bx, 2, 15), C.red)
	k:box(booth, "Tampo", V(7.6, 0.5, 10.6), CF(bx, 4.25, 15), C.wood)
	k:box(booth, "Vidro", V(0.2, 4.6, 9.4), CF(bx - 3.3, 6.8, 15), C.glass, { material = GLASS, transparency = 0.55 })
	for _, z in ipairs({ 10.1, 19.9 }) do
		k:box(booth, "Coluna", V(7, 5, 0.6), CF(bx, 6.8, z), C.white)
	end
	k:box(booth, "Teto", V(7.6, 0.8, 10.6), CF(bx, 9.6, 15), C.white)
	-- Toldo listrado (como o toldo roxo do Coffee Shop, mas vermelho/branco)
	for i = 0, 9 do
		k:part(booth, {
			name = "Toldo",
			class = "WedgePart",
			size = V(1, 1.4, 2),
			cf = CF(bx - 4.4, 9.4, 10.5 + i) * CFrame.Angles(0, rad(-90), 0),
			color = (i % 2 == 0) and C.red or C.white,
		})
	end
	-- Dentro da bilheteria: máquina de ingressos e rolinhos de bilhete
	k:box(booth, "MaquinaIngresso", V(1.6, 1.4, 1.6), CF(bx - 1.5, 5.2, 13), C.black)
	k:box(booth, "IngressoSaindo", V(0.1, 0.6, 1), CF(bx - 2.35, 5.3, 13), C.pink)
	for i = 0, 2 do
		k:cyl(booth, "RoloIngressos", 0.8, 1.1, CF(bx - 1.6, 4.95, 16.5 + i * 1.2) * CFrame.Angles(0, rad(90), 0),
			k:pick({ C.pink, C.butter, C.mint }))
	end
	local priceTag = k:box(booth, "PlacaPreco", V(0.2, 1.2, 3), CF(bx - 3.45, 4.9, 18), C.white)
	k:sign(priceTag, { face = Enum.NormalId.Left, bg = C.white, glow = true,
		lines = { { text = "INGRESSO", y = 0.08, h = 0.4, color = C.redDark }, { text = "GRÁTIS!", y = 0.5, h = 0.42, color = C.green } } })
	local boothSign = k:box(booth, "Letreiro", V(0.3, 2, 9), CF(bx - 3.9, 11.2, 15), C.gold)
	k:sign(boothSign, { face = Enum.NormalId.Left, bg = C.gold, glow = true,
		lines = { { text = "BILHETERIA", y = 0.1, h = 0.8, color = C.redDark } } })

	-- Pedestais dourados com corda vermelha
	local posts = {}
	for i = 0, 3 do
		local p = V(bx - 8, 0, 8 + i * 4)
		table.insert(posts, p)
		k:vcyl(booth, "Pedestal", 3, 0.35, p + V(0, 1.5, 0), C.gold)
		k:vcyl(booth, "PedestalBase", 0.3, 1.4, p + V(0, 0.15, 0), C.gold)
		k:ball(booth, "PedestalTopo", 0.6, p + V(0, 3.1, 0), C.gold)
	end
	for i = 1, #posts - 1 do
		k:beam(booth, "Corda", posts[i] + V(0, 2.7, 0), posts[i + 1] + V(0, 2.7, 0), 0.25, C.redDark)
	end

	-- ═══════════════════════════════════════════
	-- Baldes de pipoca gigantes emoldurando o portal da sala (fora do caminho do tapete)
	-- ═══════════════════════════════════════════
	for _, side in ipairs({ -1, 1 }) do
		local base = V(side * 12.5, 0, 29)
		k:vcyl(lobby, "Pedestal", 1, 8.4, base + V(0, 0.5, 0), C.gold)
		k:vcyl(lobby, "PedestalTopo", 0.4, 7.6, base + V(0, 1.2, 0), C.white)
		popcornBucket(lobby, base + V(0, 1.4, 0), 2.6, 6, 14, 30)
	end

	-- Pufes de macaron (área de espera no meio do lobby)
	local poufColors = { C.pink, C.mint, C.lavender, C.butter, C.sky, C.pink }
	for i, p in ipairs({ V(-10, 0, 12), V(-13, 0, 16), V(-10, 0, 19.5), V(10, 0, 12), V(13, 0, 16), V(10, 0, 19.5) }) do
		macaron(lobby, p, poufColors[i])
	end

	-- Cartazes de filmes
	local posterCatalog = {
		{ "O DONUT PERDIDO", "EM CARTAZ", C.purple, C.pink },
		{ "VELOZES & CROCANTES", "EM BREVE", k:rgb(30, 90, 160), C.butter },
		{ "MISSÃO: IMPASTÁVEL", "EM BREVE", k:rgb(30, 30, 40), C.red },
		{ "SUSHI WARS", "EM CARTAZ", k:rgb(20, 110, 100), C.mint },
		{ "A BATATA CONTRA-ATACA", "EM BREVE", k:rgb(160, 70, 20), C.butter },
		{ "PROCURANDO NUGGET", "EM CARTAZ", k:rgb(40, 140, 200), C.gold },
	}
	-- Parede direita do lobby (de frente para o centro)
	poster(decor, CF(HALF - 0.4, 8.5, 26) * CFrame.Angles(0, rad(90), 0), table.unpack(posterCatalog[1]))
	poster(decor, CF(HALF - 0.4, 8.5, 32) * CFrame.Angles(0, rad(90), 0), table.unpack(posterCatalog[2]))
	-- Frente, dos dois lados da porta (de frente para dentro)
	poster(decor, CF(-12, 8.5, 0.4) * CFrame.Angles(0, rad(180), 0), table.unpack(posterCatalog[3]))
	poster(decor, CF(12, 8.5, 0.4) * CFrame.Angles(0, rad(180), 0), table.unpack(posterCatalog[4]))
	-- Divisória, dos dois lados do portal (de frente para a entrada)
	poster(decor, CF(-23, 8.5, LOBBY - 1.4), table.unpack(posterCatalog[5]))
	poster(decor, CF(23, 8.5, LOBBY - 1.4), table.unpack(posterCatalog[6]))

	-- Letreiro "SALA 1" com lâmpadas sobre o portal
	local marquee = k:box(decor, "LetreiroSala", V(18, 4, 0.6), CF(0, 17, LOBBY - 1.4), C.red)
	k:sign(marquee, { face = Enum.NormalId.Front, bg = C.red, glow = true,
		lines = {
			{ text = "SALA 1", y = 0.08, h = 0.55, color = C.butter, stroke = C.redDark },
			{ text = "SESSÃO DA PIPOCA", y = 0.66, h = 0.26, color = C.white },
		} })
	for i = 0, 17 do
		local x = -8.5 + i
		for _, y in ipairs({ 15.2, 18.8 }) do
			k:ball(decor, "Lampada", 0.5, V(x, y, LOBBY - 1.75), (i % 2 == 0) and C.butter or C.white, { material = NEON })
		end
	end

	-- Luzes do lobby (luminárias no teto)
	for _, x in ipairs({ -16, 0, 16 }) do
		for _, z in ipairs({ 9, 27 }) do
			local lamp = k:vcyl(lights, "Luminaria", 0.4, 3, V(x, H - 0.2, z), C.butter, { material = NEON })
			k:light(lamp, { range = 22, brightness = 1.2 })
		end
	end
	local spot = k:box(lights, "SpotBalcao", V(1, 0.5, 1), CF(counterX, H - 0.5, 18), C.metal)
	k:light(spot, { class = "SpotLight", face = Enum.NormalId.Bottom, range = 30, brightness = 2, angle = 70 })

	-- ═══════════════════════════════════════════
	-- Sala: patamar, arquibancada rebaixada, fosso e palco
	-- ═══════════════════════════════════════════
	local ROWS = 6
	local ROW_DEPTH = 7
	local ROW_DROP = 1.2
	local landingEnd = 54.5

	local function slab(name, zFrom, zTo, top, color)
		local depth = zTo - zFrom
		k:box(hall, name, V(W, top - BOTTOM, depth), CF(0, (top + BOTTOM) / 2, zFrom + depth / 2), color)
	end
	slab("Patamar", LOBBY + 1, landingEnd, 0, C.carpet)
	local rowZ, rowTop = {}, {}
	for i = 0, ROWS - 1 do
		local zFrom = landingEnd + i * ROW_DEPTH
		local top = -(i + 1) * ROW_DROP
		rowZ[i], rowTop[i] = zFrom + ROW_DEPTH / 2, top
		slab("Degrau", zFrom, zFrom + ROW_DEPTH, top, C.carpet)
		-- Luzes de corredor na quina de cada degrau
		for _, x in ipairs({ -3.8, 3.8, -HALF + 2, HALF - 2 }) do
			k:box(hall, "LuzCorredor", V(1.2, 0.2, 0.3), CF(x, top + 0.1, zFrom + 0.2), C.butter, { material = NEON })
		end
	end
	local pitStart = landingEnd + ROWS * ROW_DEPTH
	local pitTop = -(ROWS + 1) * ROW_DROP

	-- Rampas invisíveis nos corredores (central e laterais): passam pela quina de cada
	-- degrau, então personagens pequenos sobem de volta sem travar nos degraus
	for _, aisle in ipairs({ { -4.4, 4.4 }, { -HALF, -31.6 }, { 31.6, HALF } }) do
		k:ramp(hall, "RampaCorredor", aisle[1], aisle[2], pitStart + ROW_DEPTH, pitTop, landingEnd, 0)
	end
	slab("Fosso", pitStart, 110, pitTop, C.carpet)
	slab("Palco", 110, L + 1, pitTop + 2.4, C.wood)
	k:box(hall, "PalcoFriso", V(W, 0.4, 0.4), CF(0, pitTop + 2.4, 110), C.gold)

	-- Paredes da sala: pilastras douradas e arandelas de "grão de pipoca"
	for _, side in ipairs({ -1, 1 }) do
		for z = 42, 114, 12 do
			k:box(hall, "Pilastra", V(0.6, H - BOTTOM, 1.6), CF(side * (HALF - 0.3), (H + BOTTOM) / 2, z), C.gold)
		end
		for z = 48, 108, 12 do
			local cup = k:vcyl(hall, "Arandela", 1.4, 1.6, V(side * (HALF - 0.9), 9, z), C.red)
			local glow = k:ball(hall, "ArandelaPipoca", 1.5, V(side * (HALF - 0.9), 10.2, z), C.popcornButter, { material = NEON })
			k:light(glow, { range = 14, brightness = 1.1, color = k:rgb(255, 210, 140) })
			cup.Name = "Arandela"
		end
	end
	-- Lado da sala na divisória (roxo) e placa de saída
	k:box(hall, "DivisoriaSalaEsq", V(HALF - 8, H, 0.2), CF(-(HALF + 8) / 2, H / 2, LOBBY + 1.1), C.purple)
	k:box(hall, "DivisoriaSalaDir", V(HALF - 8, H, 0.2), CF((HALF + 8) / 2, H / 2, LOBBY + 1.1), C.purple)
	k:box(hall, "DivisoriaSalaTopo", V(16, H - 14, 0.2), CF(0, 14 + (H - 14) / 2, LOBBY + 1.1), C.purple)
	local hallExit = k:box(hall, "PlacaSaidaSala", V(5, 1.6, 0.3), CF(0, 15.2, LOBBY + 1.3), C.green, { material = NEON })
	k:sign(hallExit, { face = Enum.NormalId.Back, bg = C.green, glow = true,
		lines = { { text = "SAÍDA", y = 0.1, h = 0.8, color = C.white } } })

	-- Tela, moldura e cortinas
	local screenCenter = V(0, pitTop + 2.4 + 13, L - 0.5)
	k:box(hall, "MolduraTela", V(60, 25, 0.6), CF(screenCenter + V(0, 0, 0.4)), C.black)
	local screen = k:box(hall, "Tela", V(57, 22.5, 0.3), CF(screenCenter), C.white)
	k:sign(screen, {
		face = Enum.NormalId.Front,
		bg = k:rgb(255, 196, 120),
		glow = true,
		pixelsPerStud = 16,
		frames = {
			{ x = 0, y = 0.62, w = 1, h = 0.38, color = k:rgb(255, 150, 170) },
			{ x = 0.36, y = 0.08, w = 0.28, h = 0.42, color = C.butter, corner = 0.5 },
		},
		lines = {
			{ text = "CINECORN", y = 0.2, h = 0.2, color = C.redDark, stroke = C.white },
			{ text = "A Grande Aventura da Pipoca", y = 0.62, h = 0.14, color = C.white, stroke = C.redDark },
			{ text = "SESSÃO COMEÇANDO", y = 0.82, h = 0.09, color = C.white },
		},
	})
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 6 do
			local x = side * (HALF - 0.8 - i * 1.15)
			k:vcyl(hall, "Cortina", H - pitTop - 2.4, 1.5,
				V(x, (H + pitTop + 2.4) / 2, L - 1.6 + (i % 2) * 0.3),
				(i % 2 == 0) and C.red or C.redDark)
		end
	end
	k:box(hall, "Sanefa", V(W, 3, 1.6), CF(0, H - 1.5, L - 1.4), C.red)
	for x = -HALF + 1, HALF - 1, 2 do
		k:ball(hall, "Franja", 0.7, V(x, H - 3.2, L - 2.2), C.gold)
	end

	-- Projetor e facho de luz até a tela
	local projector = k:box(hall, "Projetor", V(3, 2, 1.5), CF(0, 25, LOBBY + 1.6), C.black)
	k:ball(hall, "Lente", 1, V(0, 25, LOBBY + 2.4), C.butter, { material = NEON })
	k:beam(hall, "Facho", V(0, 25, LOBBY + 2.6), screenCenter - V(0, 0, 0.4), 9, k:rgb(255, 245, 210),
		{ material = NEON, transparency = 0.93, collide = false, shadow = false })
	projector.Name = "Projetor"

	-- Estrelinhas no teto
	for _ = 1, 70 do
		k:ball(hall, "Estrela", k:rand(0.25, 0.5), V(k:rand(-HALF + 2, HALF - 2), H - 0.15, k:rand(LOBBY + 3, L - 4)),
			k:pick({ C.white, C.butter }), { material = NEON, collide = false })
	end

	-- ═══════════════════════════════════════════
	-- Poltronas (dois blocos de 7, corredor central e laterais)
	-- ═══════════════════════════════════════════
	local function seat(parent, x, z, top)
		local m = k:model("Poltrona", parent)
		k:box(m, "Pe", V(2.4, 1.2, 2.2), CF(x, top + 0.6, z), C.seatDark)
		k:box(m, "Assento", V(3.2, 0.8, 3), CF(x, top + 1.6, z + 0.2), C.seat)
		k:box(m, "Encosto", V(3.2, 3.6, 0.8), CF(x, top + 3.4, z - 1.4) * CFrame.Angles(rad(-10), 0, 0), C.seat)
		k:cyl(m, "EncostoTopo", 3.2, 0.9, CF(x, top + 5.2, z - 1.75), C.seat)
		return m
	end

	local cupColors = { C.red, C.sky, C.mint, C.pink }
	for i = 0, ROWS - 1 do
		local z, top = rowZ[i] + 0.6, rowTop[i]
		for _, blockStart in ipairs({ -30, 6 }) do
			for s = 0, 6 do
				local x = blockStart + s * 4
				seat(seats, x, z, top)
			end
			-- Braços entre as poltronas, com porta-copos em alguns
			for a = 0, 7 do
				local ax = blockStart - 2 + a * 4
				k:box(seats, "Braco", V(0.6, 0.4, 2.8), CF(ax, top + 2.6, z), C.seatDark)
				if (a + i) % 2 == 0 then
					k:vcyl(seats, "PortaCopo", 0.3, 1, V(ax, top + 2.95, z + 1.1), C.black)
					k:vcyl(seats, "CopinhoRefri", 1.3, 0.75, V(ax, top + 3.6, z + 1.1), k:pick(cupColors))
					k:vcyl(seats, "CopinhoTampa", 0.15, 0.8, V(ax, top + 4.3, z + 1.1), C.white)
				end
			end
		end
	end

	-- Baldinhos de pipoca esquecidos em algumas poltronas
	for _ = 1, 8 do
		local i = math.floor(k:rand(0, ROWS - 0.01))
		local blockStart = k:pick({ -30, 6 })
		local x = blockStart + math.floor(k:rand(0, 6.99)) * 4
		popcornBucket(seats, V(x, rowTop[i] + 2.0, rowZ[i] + 0.8), 0.7, 1.4, 8, 5)
	end

	-- Pipoca derramada no chão
	for _ = 1, 30 do
		local i = math.floor(k:rand(0, ROWS - 0.01))
		k:ball(decor, "PipocaChao", k:rand(0.4, 0.7),
			V(k:pick({ k:rand(-3.5, 3.5), k:rand(-HALF + 1, -HALF + 3.5), k:rand(HALF - 3.5, HALF - 1) }),
				rowTop[i] + 0.25, rowZ[i] + k:rand(-3, 3)),
			k:pick({ C.popcorn, C.popcornButter }), { collide = false })
	end

	-- ═══════════════════════════════════════════
	-- Comidas gigantes decorando o palco e o fosso
	-- ═══════════════════════════════════════════
	local stageTop = pitTop + 2.4
	popcornBucket(decor, V(-24, stageTop, 114), 2.6, 5.5, 14, 30)
	popcornBucket(decor, V(24, stageTop, 114), 2.6, 5.5, 14, 30)
	sodaCup(decor, V(-17, stageTop, 115), 0.9, C.sky)
	sodaCup(decor, V(17, stageTop, 115), 0.9, C.red)
	hotDog(decor, CF(-26, pitTop + 1.6, 104) * CFrame.Angles(0, rad(20), 0), 1.8)
	nachos(decor, CF(26, pitTop + 0.5, 104) * CFrame.Angles(0, rad(-15), 0), 2)

	-- Rolos de filme na parede do patamar (decoração)
	for _, side in ipairs({ -1, 1 }) do
		local center = V(side * (HALF - 0.6), 20, 46)
		k:cyl(decor, "RoloFilme", 0.6, 7, CF(center) * CFrame.Angles(0, 0, 0), C.metal)
		for h = 0, 5 do
			local a = h / 6 * 2 * math.pi
			k:cyl(decor, "RoloFuro", 0.7, 1.4, CF(center + V(0, math.cos(a) * 2.2, math.sin(a) * 2.2)), C.black)
		end
		k:cyl(decor, "RoloCentro", 0.8, 1.2, CF(center), C.gold)
	end

	-- Ponto de luz geral fraco na sala (para não ficar escura demais)
	local fill = k:box(lights, "LuzGeralSala", V(1, 1, 1), CF(0, 22, 80), C.navy, { transparency = 1, collide = false })
	k:light(fill, { range = 60, brightness = 0.6, color = k:rgb(200, 180, 255) })

	return root
end
