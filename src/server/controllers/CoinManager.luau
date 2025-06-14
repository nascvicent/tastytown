--[[
    ModuleScript: CoinManager
    Responsável por gerenciar os dados das moedas dos jogadores,
    incluindo carregamento, salvamento e modificação.
--]]

-- Serviços
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- Cria a tabela do módulo que será retornada
local CoinManager = {}

-- Configurações do DataStore
local coinDataStore = DataStoreService:GetDataStore("PlayerCoinsV2") -- V2 para não conflitar com dados antigos

--============================================================================--
--                          FUNÇÕES INTERNAS (PRIVADAS)                       --
--============================================================================--

-- Função executada quando um jogador entra no jogo
local function onPlayerAdded(player)
    -- Cria a pasta 'leaderstats'
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    -- Cria o valor 'Coins'
    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Parent = leaderstats

    -- Tenta carregar os dados salvos do jogador
    local userId = player.UserId
    local data
    
    local success, err = pcall(function()
        data = coinDataStore:GetAsync(userId)
    end)

    if success then
        if data then
            coins.Value = data
            print(`Moedas de {player.Name} carregadas: {data}`)
        else
            coins.Value = 0 -- Valor inicial para novos jogadores
            print(`Novo jogador {player.Name}, iniciando com 0 moedas.`)
        end
    else
        coins.Value = 0 -- Segurança em caso de erro na API
        warn(`Erro ao carregar dados para {player.Name}: {err}`)
    end
end

-- Função para salvar os dados quando um jogador sai
local function onPlayerRemoving(player)
    -- Verifica se leaderstats e Coins existem para evitar erros
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats or not leaderstats:FindFirstChild("Coins") then
        return
    end

    local userId = player.UserId
    local coinsValue = leaderstats.Coins.Value

    local success, err = pcall(function()
        coinDataStore:SetAsync(userId, coinsValue)
    end)

    if success then
        print(`Dados de {player.Name} ({coinsValue} moedas) salvos com sucesso!`)
    else
        warn(`Falha ao salvar dados para {player.Name}: {err}`)
    end
end


--============================================================================--
--                          FUNÇÕES PÚBLICAS                                  --
--============================================================================--

-- Função para dar ou remover moedas de um jogador
function CoinManager.addCoins(player, amount)
    if not player then return end

    local leaderstats = player:FindFirstChild("leaderstats")
    local coins = leaderstats and leaderstats:FindFirstChild("Coins")

    if coins then
        coins.Value = coins.Value + amount
        return true -- Sucesso
    end

    return false -- Falha (jogador sem leaderstats de moedas)
end

-- Função para iniciar o sistema
function CoinManager.start()
    
    -- Conecta as funções aos eventos dos jogadores
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    

    -- Para jogadores que já podem estar no servidor quando o script rodar
    for _, player in ipairs(Players:GetPlayers()) do
        coroutine.wrap(onPlayerAdded)(player)
    end
    
    print("Módulo CoinManager iniciado e eventos conectados.")
end

-- para recompensar player que ganhar algo : local CoinManager = require(game.ServerScriptService.CoinManager)
--CoinManager.addCoins(player, 100) -- Dá 100 moedas ao jogador


-- Retorna a tabela do módulo para que outros scripts possam usá-la
return CoinManager