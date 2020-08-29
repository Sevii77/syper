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
	
	-- pair
	local pair, pair2 = {}, {}
	for _, v in ipairs(mode.pair) do
		local c = {}
		pair[v[1][1]] = {token = v[1][2], close = c, open = {[v[1][1]] = v[1][2]}, pattern = v.pattern}
		
		for i = 2, #v do
			c[v[i][1]] = v[i][2]
			
			if not pair2[v[i][1]] then
				pair2[v[i][1]] = {token = v[i][2], open = {}, close = {[v[i][1]] = v[i][2]}, pattern = v.pattern}
			end
			
			pair2[v[i][1]].open[v[1][1]] = v[1][2]
		end
	end
	
	for k, v in pairs(pair) do
		for k2, v2 in pairs(pair) do
			if k ~= k2 then
				for k3, v3 in pairs(v.close) do
					if v2.close[k3] then
						v.open[k2] = v2.token
					end
				end
			end
		end
	end
	
	for k, v in pairs(pair2) do
		for k2, v2 in pairs(pair2) do
			if k ~= k2 then
				for k3, v3 in pairs(v.open) do
					if v2.open[k3] then
						v.close[k2] = v2.token
					end
				end
			end
		end
	end
	
	mode.pair = pair
	mode.pair2 = pair2
	
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
