Syper.Lexer = {
	lexers = {}
}

local Lexer = Syper.Lexer
local TOKEN = Syper.TOKEN
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
		if s and (not pattern.shebang or start == 1) then
			local token = (not pattern.list or pattern.list[str]) and pattern[2] or pattern.list_nomatch
			
			if token then
				finds[#finds + 1] = {
					s = s,
					e = s + #str - 1,
					str = str,
					cap = cap,
					token = token,
					mode = pattern[3]
				}
			end
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

local ContentTable = {}
ContentTable.__index = ContentTable

function ContentTable:InsertLine(y, str)
	table.insert(self.lines, y, {
		str = str,
		len = self.len(str),
		tokens = {},
		mode = nil,
		mode_repl = nil,
		render = nil,
		pair = {}
	})
	
	local dirty = {}
	for i, _ in pairs(self.dirty) do
		dirty[i >= y and i + 1 or i] = true
	end
	dirty[y] = true
	self.dirty = dirty
end

function ContentTable:RemoveLine(y)
	table.remove(self.lines, y)
	
	local dirty = {}
	for i, _ in pairs(self.dirty) do
		dirty[i >= y and i - 1 or i] = true
	end
	if y <= #self.lines then
		dirty[y] = true
	end
	self.dirty = dirty
end

function ContentTable:ModifyLine(y, str)
	if not self.lines[y] then
		self.lines[y] = {
			str = str,
			len = self.len(str),
			tokens = {},
			mode = nil,
			mode_repl = nil,
			render = nil,
			-- pair = {}
		}
	else
		self.lines[y].str = str
		self.lines[y].len = self.len(str)
	end
	
	self.dirty[y] = true
end

function ContentTable:InsertIntoLine(y, str, x)
	local str = self.sub(self.lines[y].str, 1, x - 1) .. str .. self.sub(self.lines[y].str, x)
	self.lines[y].str = str
	self.lines[y].len = self.len(str)
	self.dirty[y] = true
end

function ContentTable:AppendToLine(y, str)
	local str = self.lines[y].str .. str
	self.lines[y].str = str
	self.lines[y].len = self.len(str)
	self.dirty[y] = true
end

function ContentTable:PrependToLine(y, str)
	local str = str .. self.lines[y].str
	self.lines[y].str = str
	self.lines[y].len = self.len(str)
	self.dirty[y] = true
end

function ContentTable:RemoveFromLine(y, len, x)
	local str = self.sub(self.lines[y].str, 1, x - 1) .. self.sub(self.lines[y].str, x + len)
	self.lines[y].str = str
	self.lines[y].len = self.len(str)
	self.dirty[y] = true
end

function ContentTable:GetLineStr(y)
	return self.lines[y].str
end

function ContentTable:GetLineLength(y)
	return self.lines[y].len
end

function ContentTable:GetLineTokens(y)
	return self.lines[y].tokens
end

function ContentTable:GetLineCount()
	return #self.lines
end

function ContentTable:LineExists(y)
	return self.lines[y] ~= nil
end

function ContentTable:RebuildLine(y)
	local lexer = self.lexer
	local line = self.lines[y]
	-- print("rebuild line " .. y)
	
	local curbyte = 1
	local mode, mode_repl
	
	if y > 1 then
		local prev = self.lines[y - 1]
		local tok = prev.tokens[#prev.tokens]
		mode = tok.mode
		mode_repl = tok.mode_repl
	else
		mode = "main"
	end
	
	line.tokens = {}
	line.mode = mode
	line.mode_repl = mode_repl
	
	while true do
		local fdata = find(line.str, curbyte, lexer[mode], mode_repl)
		if not fdata then break end
		
		if fdata.mode then
			mode = fdata.mode
			mode_repl = fdata.cap
		end
		
		line.tokens[#line.tokens + 1] = {token = fdata.token, str = fdata.str, mode = mode, mode_repl = mode_repl, s = fdata.s, e = fdata.e}
		curbyte = fdata.e + 1
		
		if fdata.str[#fdata.str] == "\n" then break end
	end
	
	return mode, mode_repl
end

function ContentTable:RebuildLines(y, c)
	for y = y, y + c do
		local mode = self:RebuildLine(y)
		local next_line = self.lines[y + 1]
		if not next_line or next_line.mode == mode then return y end
	end
	
	return y + c
end

function ContentTable:RebuildDirty(max_lines)
	local t = SysTime()
	
	local dirty = {}
	for y, _ in pairs(self.dirty) do
		dirty[#dirty + 1] = y
	end
	table.sort(dirty, function(a, b) return a < b end)
	
	local changed = {}
	for i = 1, #dirty do
		local y = dirty[i]
		
		if self.dirty[y] then
			for y = y, self:RebuildLines(y, max_lines) do
				self.dirty[y] = nil
				-- changed[#changed + 1] = y
				changed[y] = true
			end
		end
	end
	
	print("rebuild dirty", SysTime() - t)
	
	return changed
end

-- TODO: dont rebuild everything every time
-- after checking performance, its fine for now
function ContentTable:RebuildTokenPairs()
	local t = SysTime()
	
	local changed = {}
	local scopes = {}
	for k, _ in pairs(self.mode.pair) do
		scopes[k] = {}
	end
	
	for y, line in ipairs(self.lines) do
		for x, token in ipairs(line.tokens) do
			token.pair = nil
			local token_override = nil
			
			local pair = self.mode.pair2[token.str]
			if pair and pair.token == token.token then
				local pos
				for _, k in ipairs(pair.open) do
					pos = scopes[k][#scopes[k]]
					scopes[k][#scopes[k]] = nil
				end
				
				if pos then
					self.lines[pos.y].tokens[pos.x].pair = {x = x, y = y}
					token.pair = pos
				else
					-- mark token error
					token_override = TOKEN.Error
				end
			end
			
			local pair = self.mode.pair[token.str]
			if pair and pair.token == token.token then
				for _, k in ipairs(pair.open) do
					scopes[k][#scopes[k] + 1] = {x = x, y = y}
				end
			end
			
			if token.token_override ~= token_override then
				changed[y] = true
			end
			
			token.token_override = token_override
		end
	end
	
	-- mark all unfinished error
	for _, v in pairs(scopes) do
		for _, pos in ipairs(v) do
			self.lines[pos.y].tokens[pos.x].token_override = TOKEN.Error
			changed[pos.y] = true
		end
	end
	
	print("rebuild token pairs", SysTime() - t)
	
	return changed
end

function Lexer.createContentTable(lexer, mode)
	return setmetatable({
		lexer = lexer,
		mode = mode,
		lines = {},
		dirty = {},
		len = Syper.Settings.settings.utf8 and utf8.len or string.len,
		sub = Syper.Settings.settings.utf8 and utf8.sub or string.sub,
	}, ContentTable)
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
