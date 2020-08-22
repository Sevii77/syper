local Lexer = Syper.Lexer
local Settings = Syper.Settings
local TOKEN = Syper.TOKEN

----------------------------------------

local len, sub
local function setStringFuncs(settings)
	len = settings.utf8 and utf8.len or string.len
	sub = settings.utf8 and utf8.sub or string.sub
end

setStringFuncs(Settings.settings)
hook.Add("SyperSettings", "syper_editor", setStringFuncs)

----------------------------------------

local function getRenderString(str)
	local tabsize = Settings.lookupSetting("tabsize")
	local s = ""
	
	for i = 1, len(str) do
		local c = sub(str, i, i)
		s = s .. (c == "\t" and string.rep(" ", tabsize - (len(s) % tabsize)) or c)
	end
	
	return s
end

local function renderToRealPos(str, pos)
	local tabsize = Settings.lookupSetting("tabsize")
	local l = 0
	
	for i = 1, len(str) do
		l = l + (sub(str, i, i) == "\t" and tabsize - (l % tabsize) or 1)
		if l >= pos then return i end
	end
	
	return len(str)
end

local function realToRenderPos(str, pos)
	local tabsize = Settings.lookupSetting("tabsize")
	local l = 0
	
	for i = 1, pos - 1 do
		l = l + (sub(str, i, i) == "\t" and tabsize - (l % tabsize) or 1)
	end
	
	return l + 1
end

----------------------------------------

local Line = {}

function Line:Init()
	self.data = {}
	self.wrap = false
	self.linenum = "1"
	self.linenumwidth = 50
	
	self:SetMouseInputEnabled(false)
	
	self.linenumbar = self:Add("Panel")
	self.linenumbar:SetWidth(self.linenumwidth)
	self.linenumbar:Dock(LEFT)
	self.linenumbar:SetMouseInputEnabled(false)
	self.linenumbar.Paint = function(_, w, h)
		surface.SetDrawColor(Settings.settings.style_data.linenumber_background)
		surface.DrawRect(0, 0, w, h)
		surface.SetTextColor(Settings.settings.style_data.linenumber)
		surface.SetFont("syper_syntax_1")
		local tw, th = surface.GetTextSize(self.linenum)
		surface.SetTextPos(w - tw - 20, 0)
		surface.DrawText(self.linenum)
	end
	
	self.tokenholder = self:Add("Panel")
	self.tokenholder:Dock(FILL)
	self.tokenholder:SetMouseInputEnabled(false)
end

function Line:SetData(line)
	self.data = line
	self.tokenholder:Clear()
	
	for i, token in ipairs(line.tokens) do
		local text = getRenderString(token.text)
		local label = self.tokenholder:Add("Panel")
		label:SetWidth(i == #line.tokens and 9999 or surface.GetTextSize(text))
		label:Dock(LEFT)
		label:SetMouseInputEnabled(false)
		label.Paint = function(self, w, h)
			local clr = Settings.settings.style_data[token.token]
			if clr.b then
				surface.SetDrawColor(clr.b)
				surface.DrawRect(0, 0, w, h)
			end
			
			surface.SetTextColor(clr.f)
			surface.SetFont("syper_syntax_" .. token.token)
			surface.SetTextPos(0, 0)
			surface.DrawText(text)
		end
	end
end

function Line:SetWrap(state)
	self.wrap = state
	
	-- stuff here
end

function Line:SetLineNumber(num)
	self.linenum = tostring(num)
end

function Line:SetLineNumberSize(width)
	self.linenumwidth = width
	self.linenumbar:SetWidth(self.linenumwidth)
end

vgui.Register("SyperEditorLine", Line, "Panel")

----------------------------------------

local Act = {}

function Act.undo(self)
	
end

function Act.redo(self)
	
end

function Act.copy(self)
	local str = {}
	local function add(s)
		str[#str + 1] = s
	end
	
	for _, caret in ipairs(self.carets) do
		if caret.select_x then
			local sx, sy = caret.x, caret.y
			local ex, ey = caret.select_x, caret.select_y
			
			if ey < sy or (ex < sx and sy == ey) then
				local ex_, ey_ = ex, ey
				ex, ey = sx, sy
				sx, sy = ex_, ey_
			end
			
			add(sub(self.content_lines[sy], sx, sy == ey and ex - 1 or -1))
			
			for y = sy + 1, ey - 1 do
				add("\n")
				add(self.content_lines[y])
			end
			
			if sy ~= ey then
				add("\n")
				add(sub(self.content_lines[ey], 1, ex - 1))
			end
		end
	end
	
	timer.Simple(0.1, function()
		print(table.concat(str, ""))
		SetClipboardText(table.concat(str, ""))
	end)
end

function Act.cut(self)
	Act.copy(self)
	
	-- TODO: the deleting part
end

function Act.paste(self)
	-- This will never be used
end

function Act.pasteindent(self)
	-- TODO
end

function Act.selectall(self)
	local lines = self.data.lines
	
	self:ClearCarets()
	self:SetCaret(1, lines[#lines].len_char, #lines)
	
	self.carets[1].select_x = 1
	self.carets[1].select_y = 1
end

function Act.writestr(self, str)
	self:InsertStr(str)
end

function Act.delete(self, typ, count_dir)
	self:ClearExcessCarets()
end

function Act.move(self, typ, count_dir, selc)
	local lines = self.data.lines
	
	for caret_id, caret in ipairs(self.carets) do
		if selc then
			if not caret.select_x then
				caret.select_x = caret.x
				caret.select_y = caret.y
			end
		elseif caret.select_x then
			caret.select_x = nil
			caret.select_y = nil
		end
		
		if typ == "char" then
			self:MoveCaret(caret_id, count_dir, nil)
		elseif typ == "word" then
			if count_dir > 0 then
				local line = lines[caret.y].str
				local ll = lines[caret.y].len_char
				if caret.x >= ll then
					if caret.y == #lines then goto SKIP end
					
					self:SetCaret(caret_id, 1, caret.y + 1)
					
					goto SKIP
				end
				
				local e = select(2, string.find(sub(line, caret.x), "[^%w_]*[%w_]+"))
				self:SetCaret(caret_id, e and (e + caret.x) or (ll + 1), nil)
			else
				local line = lines[caret.y].str
				if caret.x == 1 then
					if caret.y == 1 then goto SKIP end
					
					self:SetCaret(caret_id, lines[caret.y - 1].len_char + 1, caret.y - 1)
					
					goto SKIP
				end
				
				local s = string.find(sub(line, 1, caret.x - 1), "[%w_]*[^%w_]*$")
				self:SetCaret(caret_id, s, nil)
			end
			
			::SKIP::
		elseif typ == "line" then
			self:MoveCaret(caret_id, nil, count_dir)
		elseif typ == "bol" then
			local e = select(2, string.find(lines[caret.y].str, "^%s*")) + 1
			if caret.x ~= e or caret.x ~= 1 then
				self:SetCaret(caret_id, caret.x == e and 1 or e, nil)
			end
		elseif typ == "eol" then
			self:SetCaret(caret_id, lines[caret.y].len_char)
		elseif typ == "bof" then
			self:SetCaret(caret_id, 1, 1)
		elseif typ == "eof" then
			self:SetCaret(caret_id, lines[#lines].len_char, #lines)
		end
	end
	
	self:ClearExcessCarets()
end

----------------------------------------

local Editor = {Act = Act}

function Editor:Init()
	-- self.content = "" --"blahмblah"
	self.content_lines = {""}
	self.data = {}
	self.lines = {}
	self.carets = {}
	self.caretmode = 0
	self.gutter_size = 50
	
	self.textentry = self:Add("TextEntry")
	self.textentry:SetSize(0, 0)
	self.textentry:SetAllowNonAsciiCharacters(true)
	self.textentry:SetMultiline(true)
	self.textentry.OnKeyCodeTyped = function(_, key) self:OnKeyCodeTyped(key) end
	self.textentry.OnTextChanged = function() self:OnTextChanged() end
	self.textentry.OnLoseFocus = function() self:OnLoseFocus() end
	
	self.lineholder = self:Add("Panel")
	self.lineholder:Dock(FILL)
	self.lineholder:SetMouseInputEnabled(false)
	
	self:SetSyntax("text")
	self:Rebuild()
	self:AddCaret(1, 1)
end

function Editor:Paint(w, h)
	surface.SetDrawColor(Settings.settings.style_data.background)
	surface.DrawRect(0, 0, w, h)
	
	return true
end

function Editor:PaintOver(w, h)
	surface.SetTextColor(255, 255, 255, 255)
	surface.SetFont("syper_syntax_1")
	-- local cw, ch = surface.GetTextSize(" ")
	local _, th = surface.GetTextSize(" ")
	
	local lines = self.data.lines
	for _, caret in ipairs(self.carets) do
		if caret.select_x then
			surface.SetDrawColor(255, 255, 255, 100)
			
			local sx, sy = caret.x, caret.y
			local ex, ey = caret.select_x, caret.select_y
			
			if ey < sy or (ex < sx and sy == ey) then
				local ex_, ey_ = ex, ey
				ex, ey = sx, sy
				sx, sy = ex_, ey_
			end
			
			ex = ex - 1
			
			if sy == ey then
				local offset = surface.GetTextSize(getRenderString(sub(lines[sy].str, 1, sx - 1)))
				local tw = surface.GetTextSize(getRenderString(sub(lines[sy].str, sx, ex)))
				surface.DrawRect(self.gutter_size + offset, sy * th - th, tw, th)
				-- surface.DrawRect(self.gutter_size + cx * cw, cy * ch, (sx - cx) * cw, ch)
			else
				local offset = surface.GetTextSize(getRenderString(sub(lines[sy].str, 1, sx - 1)))
				local tw = surface.GetTextSize(getRenderString(sub(lines[sy].str, sx)))
				surface.DrawRect(self.gutter_size + offset, sy * th - th, tw, th)
				
				for y = sy + 1, ey - 1 do
					local tw = surface.GetTextSize(getRenderString(lines[y].str))
					surface.DrawRect(self.gutter_size, y * th - th, tw, th)
				end
				
				local tw = surface.GetTextSize(getRenderString(sub(lines[ey].str, 1, ex)))
				surface.DrawRect(self.gutter_size, ey * th - th, tw, th)
			end
		end
		
		-- local tw = surface.GetTextSize(getRenderString(sub(lines[caret.y].str, 1, caret.x - 1)))
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawRect(self.gutter_size + caret.visual_x, caret.y * th - th, 2, th)
		
		surface.SetTextPos(0, h - th)
		surface.DrawText(string.format("%s,%s | %s,%s", caret.x, caret.y, caret.select_x, caret.select_y))
	end
end

function Editor:OnKeyCodeTyped(key)
	local bind = Settings.lookupBind(
		input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL),
		input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT),
		input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT),
		key
	)
	
	if bind then
		local act = self.Act[bind.act]
		
		-- Gotta check since there are binds that are handled by different things such as changing active tab
		if act then
			act(self, unpack(bind.args or {}))
		end
		
		return true
	elseif key == KEY_TAB then
		self:InsertStr("\t")
		self.refocus = true
		
		return true
	end
	
	return false
end

function Editor:OnMousePressed(key)
	if key == MOUSE_LEFT then
		self:RequestFocus()
	end
end

function Editor:OnTextChanged()
	-- print(#self.textentry:GetText(), select(2, string.gsub(self.textentry:GetText(), "\n", "")), self.textentry:GetText())
	self:InsertStr(utf8.force(self.textentry:GetText()))
	self.textentry:SetText("")
end

function Editor:OnLoseFocus()
	if self.refocus then
		self:RequestFocus()
		self.refocus = false
	end
end

function Editor:RequestFocus()
	self.textentry:RequestFocus()
end

function Editor:OnGetFocus()
	self:RequestFocus()
end

function Editor:Rebuild()
	self.lineholder:Clear()
	self.lines = {}
	
	self.data = Lexer.tokenize(self.lexer, table.concat(self.content_lines, "\n"))
	
	local h = Settings.lookupSetting("font_size")
	for i, line_data in ipairs(self.data.lines) do
		local line = self.lineholder:Add("SyperEditorLine")
		line:SetData(line_data)
		line:SetHeight(h)
		line:Dock(TOP)
		
		self.lines[i] = line
	end
end

function Editor:SetSyntax(syntax)
	self.lexer = Lexer.lexers[syntax]
end

function Editor:ClearCarets()
	self.carets = {self.carets[#self.carets]}
end

function Editor:ClearExcessCarets()
	-- todo
end

function Editor:AddCaret(x, y)
	self.carets[#self.carets + 1] = {
		x = x,
		y = y,
		max_x = x,
		select_x = nil,
		select_y = nil,
		visual_x = 0
	}
	
	table.sort(self.carets, function(a, b)
		return a.y > b.y or (a.y == b.y and a.x > b.x)
	end)
	
	PrintTable(self.carets)
end

function Editor:SetCaret(i, x, y)
	local caret = self.carets[i]
	
	x = x or caret.x
	y = y or caret.y
	
	caret.x = x
	caret.y = y
	caret.max_x = x
	caret.visual_x = surface.GetTextSize(getRenderString(sub(self.content_lines[caret.y], 1, caret.x - 1)))
end

function Editor:MoveCaret(i, x, y)
	local lines = self.data.lines
	local caret = self.carets[i]
	
	if x then
		local xn = x / math.abs(x)
		for _ = xn, x, xn do
			if x > 0 then
				local ll = len(lines[caret.y].str)
				if caret.x < ll or caret.y < #lines then
					caret.x = caret.x + 1
					if caret.x > ll then
						caret.x = 1
						caret.y = caret.y + 1
					end
					caret.max_x = caret.x
				end
			else
				if caret.x > 1 or caret.y > 1 then
					caret.x = caret.x - 1
					if caret.x < 1 then
						caret.y = caret.y - 1
						caret.x = lines[caret.y].len_char
					end
					caret.max_x = caret.x
				end
			end
		end
	end
	
	if y then
		local yn = y / math.abs(y)
		for _ = yn, y, yn do
			if y > 0 then
				if caret.y < #lines then
					caret.x = renderToRealPos(lines[caret.y + 1].str, realToRenderPos(lines[caret.y].str, caret.x))
					caret.y = caret.y + 1
				end
			elseif caret.y > 1 then
				caret.x = renderToRealPos(lines[caret.y - 1].str, realToRenderPos(lines[caret.y].str, caret.x))
				caret.y = caret.y - 1
			end
		end
	end
	
	caret.visual_x = surface.GetTextSize(getRenderString(sub(self.content_lines[caret.y], 1, caret.x - 1)))
end

function Editor:Get1DFrom2DPos(x, y)
	return self.data.lines[y].start_char + x - 1
end

function Editor:InsertStr(str)
	local t = SysTime()
	for _, caret in ipairs(self.carets) do
		self:InsertStrAt(caret.x, caret.y, str)
	end
	print(SysTime() - t)
	
	-- currently just rebuild everything to test
	local t = SysTime()
	self:Rebuild()
	print(SysTime() - t)
end

function Editor:InsertStrAt(x, y, str)
	local pos = self:Get1DFrom2DPos(x, y)
	-- self.content = sub(self.content, 1, pos - 1) .. str .. sub(self.content, pos)
	
	local lines = string.Split(str, "\n")
	local line_count = #lines - 1
	local cs = self.content_lines
	local e = y + line_count
	local eo = cs[e] or ""
	cs[y] = sub(cs[y], 1, x - 1) .. lines[1]
	for i = y + 1, e do
		table.insert(cs, i, lines[i - y + 1])
	end
	cs[e] = cs[e] .. (e == y and sub(eo, x) or eo)
	
	for caret_id, caret in ipairs(self.carets) do
		if caret.y > y then
			self:MoveCaret(caret_id, nil, line_count)
		elseif caret.y == y then
			self:SetCaret(caret_id, (line_count == 0 and caret.x or 1) + len(string.match(str, "[^\n]*$")), y + line_count)
		end
	end
end

function Editor:RemoveStrAt(x, y, length)
	local pos = self:Get1DFrom2DPos(x, y) + math.min(length, 0)
	length = math.abs(length)
	
	self.content = sub(self.content, 1, pos - 1) .. sub(self.content, pos + length)
end

vgui.Register("SyperEditor", Editor, "Panel")
