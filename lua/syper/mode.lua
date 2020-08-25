Syper.Mode = {
	modes = {}
}

local Mode = Syper.Mode
if CLIENT then

----------------------------------------

function Mode.prepareMode(mode)
	local new = {}
	for _, k in ipairs(mode.indent) do
		new[k[1]] = k[2]
	end
	mode.indent = new
	
	local new = {}
	for _, k in ipairs(mode.outdent) do
		new[k[1]] = k[2]
	end
	mode.outdent = new
	
	local new = {}
	for k, v in pairs(mode.bracket) do
		local t = {}
		new[k] = {close = v[1], ignore_mode = t}
		
		for _, m in ipairs(v[2]) do
			t[m] = true
		end
	end
	mode.bracket = new
	
	return mode
end

----------------------------------------

end
for _, name in pairs(file.Find("syper/mode/*.lua", "LUA")) do
	local path = "syper/mode/" .. name
	
	if SERVER then
		AddCSLuaFile(path)
	else
		Syper.Mode.modes[string.sub(name, 1, -5)] = Mode.prepareMode(include(path))
	end
end
