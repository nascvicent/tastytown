local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Configurações de música
local MUSIC_CONFIG = {
	Normal = {
		Main = "rbxassetid://9047876673",
		Others = {
			"rbxassetid://9047920425",
			"rbxassetid://1839058272",
			"rbxassetid://9047989196"
		},
		MainChance = 0.3
	},
	Zones = {
		CoffeeShop = "rbxassetid://9044701683",
		FruitGym = "rbxassetid://1837482553"
	},
	Settings = {
		Volume = 0.63,
		FadeTime = 1.5 -- Tempo da transição em segundos
	}
}

local currentMusic = nil
local currentZone = nil
local musicConnection = nil -- Para guardar a conexão do .Ended

-- Função auxiliar para escolher música aleatória
local function getRandomNormalMusic()
	if math.random() <= MUSIC_CONFIG.Normal.MainChance then
		return MUSIC_CONFIG.Normal.Main
	else
		local randomIndex = math.random(1, #MUSIC_CONFIG.Normal.Others)
		return MUSIC_CONFIG.Normal.Others[randomIndex]
	end
end

-- Função principal para tocar música com transição (Crossfade)
local function playMusic(soundId, isLooped)
	-- Se já está tocando a mesma música e ela está ativa, não faz nada
	if currentMusic and currentMusic.SoundId == soundId and currentMusic.IsPlaying then
		return
	end

	-- 1. Lidar com a música antiga (Fade Out)
	if currentMusic then
		local oldMusic = currentMusic
		-- Desconecta evento de término para não disparar logicamente duplicada
		if musicConnection then
			musicConnection:Disconnect()
			musicConnection = nil
		end

		-- Cria tween para zerar o volume
		local fadeOutTween = TweenService:Create(oldMusic, TweenInfo.new(MUSIC_CONFIG.Settings.FadeTime), {Volume = 0})
		fadeOutTween:Play()

		-- Destroi o som antigo após o fade terminar
		fadeOutTween.Completed:Connect(function()
			oldMusic:Destroy()
		end)
	end

	-- 2. Configurar a nova música
	local music = Instance.new("Sound")
	music.Name = "BackgroundMusic"
	music.SoundId = soundId
	music.Volume = 0 -- Começa mudo para fazer o Fade In
	music.Looped = isLooped
	music.Parent = SoundService

	local musicGroup = SoundService:FindFirstChild("MusicGroup")
	if musicGroup then
		music.SoundGroup = musicGroup
	end

	music:Play()
	currentMusic = music

	-- 3. Fazer o Fade In (Aumentar volume)
	local fadeInTween = TweenService:Create(music, TweenInfo.new(MUSIC_CONFIG.Settings.FadeTime), {Volume = MUSIC_CONFIG.Settings.Volume})
	fadeInTween:Play()

	-- 4. Lógica para quando a música acabar (Apenas se não for Loop/Zona)
	if not isLooped then
		musicConnection = music.Ended:Connect(function()
			-- Só toca a próxima se ainda não estivermos numa zona
			if not currentZone then
				local nextId = getRandomNormalMusic()
				playMusic(nextId, false)
			end
		end)
	end
end

-- Escuta mudanças de zona
local remoteEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild('MusicZoneEvent')

remoteEvent.OnClientEvent:Connect(function(zoneName)
	-- Evita trocar se a zona for a mesma que já está
	if currentZone == zoneName then return end

	currentZone = zoneName

	if zoneName and MUSIC_CONFIG.Zones[zoneName] then
		-- Entrou na zona: Toca música da zona em Loop
		local zoneMusicId = MUSIC_CONFIG.Zones[zoneName]
		playMusic(zoneMusicId, true) -- true para Looped
	else
		-- Saiu da zona: Volta para playlist normal (sem loop, aleatória)
		local normalId = getRandomNormalMusic()
		playMusic(normalId, false) -- false para Looped
	end
end)

-- Inicia a música normal ao carregar o jogo
task.spawn(function()
	if not currentZone then
		local startId = getRandomNormalMusic()
		playMusic(startId, false)
	end
end)