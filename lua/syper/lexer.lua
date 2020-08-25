Syper.Lexer = {
	lexers = {}
}

local Lexer = Syper.Lexer
if CLIENT then

----------------------------------------

function Lexer.prepareLexer(lexer)
	for mode, data in pairs(lexer) do
		if mode ~= "name" then
			for _, v in ipairs(data) do
				if v.list then
					local new = {}
					for _, n in ipairs(v.list) do
						new[n] = true
					end
					v.list = new
				end
			end
		end
	end
	
	return lexer
end

local function find(str, start, patterns, repl)
	local finds = {}
	for i, pattern in ipairs(patterns) do
		local s, _, str, cap = string.find(str, repl and string.gsub(pattern[1], "<CAP>", repl) or pattern[1], start)
		if s and (not pattern.list or pattern.list[str]) and (not pattern.shebang or start == 1) then
			finds[#finds + 1] = {
				s = s,
				e = s + #str - 1,
				str = str,
				cap = cap,
				pattern = pattern
			}
		end
	end
	
	if #finds == 0 then return end
	
	local s, cur = math.huge
	for _, v in ipairs(finds) do
		if v.s < s then
			s = v.s
			cur = v
		end
	end
	
	return cur
end

function Lexer.tokenize(lexer, content_lines, max_lines, data_override, start_line, start_char)
	local data, mode, mode_repl, curbyte, curchar, line
	
	if data_override then
		data = data_override
		
		-- if not start_line then
		-- 	for i, line in ipairs(data.lines) do
		-- 		if line.start <= start_char then
		-- 			start_line = i
		-- 		else
		-- 			break
		-- 		end
		-- 	end
		-- end
		local sline = data.lines[start_line]
		
		mode = sline.mode
		mode_repl = sline.mode_repl
		curbyte = sline.start - 1
		data.lines[start_line] = nil
		line = sline
		line.tokens = {}
	else
		data = {lines = {}}
		mode = "main"
		mode_repl = nil
		curbyte = 1
		line = {tokens = {}, str = "", mode = mode, mode_repl = mode_repl, start = curbyte, stop = -1}
	end
	
	local linestart = start_line or 1
	max_lines = math.min(max_lines or math.huge, (#content_lines - linestart + 1))
	
	for k = linestart, linestart + max_lines - 1 do
		local curbyte_line = 1
		local code = content_lines[k][1]
		local last = k == #content_lines
		
		if last then
			code = code .. "\n"
		end
		
		while true do
			local fdata = find(code, curbyte_line, lexer[mode], mode_repl)
			if not fdata then break end
			line.tokens[#line.tokens + 1] = {token = fdata.pattern[2], str = fdata.str, mode = mode, s = fdata.s, e = fdata.e}
			line.str = line.str .. fdata.str
			curbyte = fdata.e + 1
			curbyte_line = fdata.e + 1
			
			if fdata.pattern[3] then
				mode = fdata.pattern[3]
				mode_repl = fdata.cap
			end
			
			if fdata.str[#fdata.str] == "\n" then
				line.stop = curbyte - 1
				line.len = #line.str
				data.lines[k] = line
				line = {tokens = {}, str = "", mode = mode, mode_repl = mode_repl, start = curbyte}
				
				if k == linestart + max_lines - 1 and not last then
					return data
				end
			end
		end
	end
	
	return data
end

----------------------------------------

end
for _, name in pairs(file.Find("syper/lexer/*.lua", "LUA")) do
	local path = "syper/lexer/" .. name
	
	if SERVER then
		AddCSLuaFile(path)
	else
		Syper.Lexer.lexers[string.sub(name, 1, -5)] = Lexer.prepareLexer(include(path))
	end
end
