--[[
	Copia exteriores do ServerStorage para ReplicatedStorage.ShopModels.ModelosCasas
	(prévia 3D no Inventário/Shop), sem scripts e sem peças invisíveis/gatilhos.

	  lune run tools/houses/sync_previews.luau
]]

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

-- [nome do modelo de prévia] = arquivo de origem
local SOURCES = {
	CasaDeBiscoito = "src/ServerStorage/CasaExterior.rbxmx",
}

local TARGET = "src/ReplicatedStorage/ShopModels/ModelosCasas.rbxmx"

local folder = roblox.deserializeModel(fs.readFile(TARGET))[1]

for previewName, sourcePath in pairs(SOURCES) do
	local source = roblox.deserializeModel(fs.readFile(sourcePath))[1]
	local preview = source:Clone()
	preview.Name = previewName

	for _, d in ipairs(preview:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or (d:IsA("BasePart") and d.Transparency >= 1) then
			d:Destroy()
		end
	end

	local old = folder:FindFirstChild(previewName)
	if old then old:Destroy() end
	preview.Parent = folder
	print("prévia atualizada:", previewName)
end

fs.writeFile(TARGET, roblox.serializeModel({ folder }, true))
