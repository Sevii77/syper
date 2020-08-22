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

function Lexer.tokenize(lexer, code, max_lines, data_override, start_line, start_char)
	code = code .. "\n"
	local data, mode, mode_repl, curbyte, curchar, line
	
	if data_override then
		data = data_override
		
		if not start_line then
			for i, line in ipairs(data.lines) do
				if line.start <= start_char then
					start_line = i
				else
					break
				end
			end
		end
		local sline = data.lines[start_line]
		
		mode = sline.mode
		mode_repl = sline.mode_repl
		curbyte = sline.start - 1
		-- curchar = sline.start_char - 1
		data.lines[start_line] = nil
		line = sline
		line.tokens = {}
	else
		data = {lines = {}}
		mode = "main"
		mode_repl = nil
		curbyte = 1
		-- curchar = 1
		line = {tokens = {}, str = "", mode = mode, mode_repl = mode_repl, start = curbyte, --[[start_char = curchar,]] stop = -1}
	end
	
	local linestart = start_line or 1
	local linecount = linestart
	
	while true do
		local fdata = find(code, curbyte, lexer[mode], mode_repl)
		if not fdata then break end
		line.tokens[#line.tokens + 1] = {token = fdata.pattern[2], text = fdata.str, mode = mode}
		line.str = line.str .. fdata.str
		curbyte = fdata.e + 1
		-- curchar = curchar + utf8.len(fdata.str)
		
		if fdata.pattern[3] then
			mode = fdata.pattern[3]
			line.mode = mode
			mode_repl = fdata.cap
		end
		
		if fdata.str[#fdata.str] == "\n" then
			line.stop = curbyte - 1
			line.len = #line.str
			line.len_char = utf8.len(line.str)
			data.lines[linecount] = line
			line = {tokens = {}, str = "", mode = mode, mode_repl = mode_repl, start = curbyte, --[[start_char = curchar]]}
			
			linecount = linecount + 1
			if linecount - linestart == max_lines then
				break
			end
		end
	end
	
	local last = data.lines[#data.lines]
	if last.stop == #code then
		local tok = last.tokens[#last.tokens]
		if string.sub(tok.text, -1, -1) == "\n" then
			if #tok.text == 1 then
				last.tokens[#last.tokens] = nil
			else
				tok.text = string.sub(tok.text, 1, -2)
			end
			last.stop = last.stop - 1
		end
	end
	
	-- line.stop = curbyte
	-- data.lines[linecount] = line
	
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
