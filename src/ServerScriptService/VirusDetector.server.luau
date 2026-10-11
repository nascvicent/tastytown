local InsertService = game:GetService("InsertService")

-- Função para dedurar quem criou o objeto
local function dedurar(child)
	print("🚨 ALERTA: Algo foi criado no InsertService!")
	print("Nome do Objeto: " .. child.Name)
	print("--- RASTREIO DA ORIGEM (TRACEBACK) ---")
	-- Isso imprime a árvore de execução, mostrando qual script chamou essa função
	print(debug.traceback()) 
	print("--------------------------------------")
end

-- Monitora o que for adicionado daqui pra frente
InsertService.ChildAdded:Connect(dedurar)

-- Checa se já tem algo lá quando o jogo começa
for _, child in pairs(InsertService:GetChildren()) do
	dedurar(child)
end