Syper.Mode = {
	modes = {}
}

local Mode = Syper.Mode
if CLIENT then

----------------------------------------

function Mode.prepareMode(mode)
	local new = {}
	for _, k in ipairs(mode.indent) do
		new[k] = true
	end
	mode.indent = new
	
	local new = {}
	for _, k in ipairs(mode.outdent) do
		new[k] = true
	end
	mode.outdent = new
	
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
