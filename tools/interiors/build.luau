--[[
	Gera os interiores com o Lune.

	  lune run tools/interiors/build.luau            -> gera todos
	  lune run tools/interiors/build.luau CineCorn   -> gera só um

	Saídas:
	  src/ServerStorage/Interiors/<Nome>Interior.rbxmx  (o Rojo leva para o Studio)
	  tools/interiors/preview/scene.js                  (preview 3D no navegador)
]]

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local INTERIORS = {
	CineCorn = require("./CineCorn"),
}

local OUT_DIR = "src/ServerStorage/Interiors"
local PREVIEW = "tools/interiors/preview/scene.js"

local function round(n)
	return math.floor(n * 1000 + 0.5) / 1000
end

local function color(c)
	return { round(c.R), round(c.G), round(c.B) }
end

-- Converte o modelo para dados simples que o preview three.js entende
local function dump(model)
	local parts, guis, lights = {}, {}, {}
	local index = {}

	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			local cf = { inst.CFrame:GetComponents() }
			for i, v in ipairs(cf) do cf[i] = round(v) end
			local shape = "Block"
			if inst:IsA("Part") then shape = inst.Shape.Name end
			table.insert(parts, {
				n = inst.Name,
				c = inst.ClassName,
				sh = shape,
				s = { round(inst.Size.X), round(inst.Size.Y), round(inst.Size.Z) },
				cf = cf,
				col = color(inst.Color),
				m = inst.Material.Name,
				t = round(inst.Transparency),
			})
			index[inst] = #parts - 1
		end
	end

	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("SurfaceGui") and index[inst.Parent] then
			local bg = inst:FindFirstChild("Background")
			local entry = {
				p = index[inst.Parent],
				f = inst.Face.Name,
				bg = bg and color(bg.BackgroundColor3) or { 1, 1, 1 },
				frames = {},
				lines = {},
			}
			if bg then
				for _, child in ipairs(bg:GetChildren()) do
					if child:IsA("TextLabel") then
						table.insert(entry.lines, {
							text = child.Text,
							x = child.Position.X.Scale, y = child.Position.Y.Scale,
							w = child.Size.X.Scale, h = child.Size.Y.Scale,
							col = color(child.TextColor3),
							stroke = child.TextStrokeTransparency < 1 and color(child.TextStrokeColor3) or nil,
							align = child.TextXAlignment.Name,
						})
					elseif child:IsA("Frame") then
						table.insert(entry.frames, {
							x = child.Position.X.Scale, y = child.Position.Y.Scale,
							w = child.Size.X.Scale, h = child.Size.Y.Scale,
							col = color(child.BackgroundColor3),
							round = child:FindFirstChildOfClass("UICorner") ~= nil,
						})
					end
				end
			end
			table.insert(guis, entry)
		elseif inst:IsA("Light") and inst.Parent:IsA("BasePart") then
			local p = inst.Parent.CFrame.Position
			table.insert(lights, {
				pos = { round(p.X), round(p.Y), round(p.Z) },
				col = color(inst.Color),
				b = inst.Brightness,
				r = inst.Range,
				spot = inst:IsA("SpotLight"),
			})
		end
	end

	return { name = model.Name, scale = model:GetAttribute("BuildScale") or 1, parts = parts, guis = guis, lights = lights }
end

local wanted = process.args[1]
local scenes = {}

fs.writeDir(OUT_DIR)
for name, build in pairs(INTERIORS) do
	if not wanted or wanted == name then
		local model = build(roblox)
		local count = 0
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then count += 1 end
		end
		fs.writeFile(OUT_DIR .. "/" .. model.Name .. ".rbxmx", roblox.serializeModel({ model }, true))
		table.insert(scenes, dump(model))
		print(("%s: %d peças -> %s/%s.rbxmx"):format(name, count, OUT_DIR, model.Name))
	end
end

fs.writeFile(PREVIEW, "window.SCENES = " .. serde.encode("json", scenes) .. ";\n")
print("preview -> " .. PREVIEW)
