Syper.Mode = {
	modes = {}
}

local Mode = Syper.Mode
if CLIENT then

----------------------------------------

function Mode.prepareMode(mode)
	-- indent
	local indent = {}
	for _, v in ipairs(mode.indent) do
		local t = {}
		indent[v[1]] = t
		
		for _, m in ipairs(v[2]) do
			t[m] = true
		end
	end
	mode.indent = indent
	
	-- outdent
	local outdent = {}
	for _, v in ipairs(mode.outdent) do
		local t = {}
		outdent[v[1]] = t
		
		for _, m in ipairs(v[2]) do
			t[m] = true
		end
	end
	mode.outdent = outdent
	
	-- bracket
	local bracket, bracket2 = {}, {}
	for k, v in pairs(mode.bracket) do
		local t, t2 = {}, {}
		bracket[k] = {close = v[1], ignore_mode = t, ignore_char = t2}
		bracket2[v[1]] = {open = k, ignore_mode = t, ignore_char = t2}
		
		for _, m in ipairs(v[2]) do
			t[m] = true
		end
		
		if v[3] then
			for _, m in ipairs(v[3]) do
				t2[m] = true
			end
		end
	end
	mode.bracket = bracket
	mode.bracket2 = bracket2
	
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
