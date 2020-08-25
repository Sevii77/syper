local Lexer = Syper.Lexer
local Mode = Syper.Mode
local Settings = Syper.Settings
local TOKEN = Syper.TOKEN

----------------------------------------

local len, sub, ignore_chars
local function settingsUpdate(settings)
	len = settings.utf8 and utf8.len or string.len
	sub = settings.utf8 and utf8.sub or string.sub
	
	ignore_chars = {}
	if settings.ignore_chars then
		for _, c in ipairs(settings.ignore_chars) do
			ignore_chars[c] = true
		end
	end
end

settingsUpdate(Settings.settings)
hook.Add("SyperSettings", "syper_editor", settingsUpdate)

----------------------------------------

local function getRenderString(str)
	local tabsize = Settings.lookupSetting("tab_size")
	local ctrl = Settings.lookupSetting("show_controll_characters")
	local s = ""
	
	for i = 1, len(str) do
		local c = sub(str, i, i)
		s = s .. (c == "\t" and string.rep(" ", tabsize - (len(s) % tabsize)) or ((not ctrl or string.find(c, "%C")) and c or ("<0x" .. string.byte(c) .. ">")))
	end
	
	return s
end

local function renderToRealPos(str, pos)
	local tabsize = Settings.lookupSetting("tab_size")
	local l = 0
	
	for i = 1, len(str) do
		l = l + (sub(str, i, i) == "\t" and tabsize - (l % tabsize) or 1)
		if l >= pos then return i end
	end
	
	return len(str)
end

local function realToRenderPos(str, pos)
	local tabsize = Settings.lookupSetting("tab_size")
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
		local text = getRenderString(token.str)
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
	self:Undo()
end

function Act.redo(self)
	self:Redo()
end

function Act.copy(self)
	local str, empty = {}, true
	local function add(s)
		str[#str + 1] = s
		empty = false
	end
	
	for caret_id, caret in ipairs(self.carets) do
		if caret.select_x then
			local sx, sy = caret.x, caret.y
			local ex, ey = caret.select_x, caret.select_y
			
			if ey < sy or (ex < sx and sy == ey) then
				local ex_, ey_ = ex, ey
				ex, ey = sx, sy
				sx, sy = ex_, ey_
			end
			
			add(sub(self.content_lines[sy][1], sx, sy == ey and ex - 1 or -1))
			
			for y = sy + 1, ey - 1 do
				add(self.content_lines[y][1])
			end
			
			if sy ~= ey then
				add(sub(self.content_lines[ey][1], 1, ex - 1))
			end
			
			if caret_id ~= #self.carets then
				add("\n")
			end
		end
	end
	
	if empty then
		for caret_id, caret in ipairs(self.carets) do
			add(self.content_lines[caret.y][1])
			
			if caret_id ~= #self.carets then
				add("\n")
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
	
	self:RemoveSelection()
end

function Act.paste(self)
	-- This will never be used
	self.is_pasted = true
end

function Act.pasteindent(self)
	-- TODO
end

function Act.newline(self)
	for caret_id, caret in ipairs(self.carets) do
		if Settings.settings.indent_auto then
			local e = select(2, string.find(self.content_lines[caret.y][1], "^\t*"))
			local move = nil
			
			if Settings.settings.indent_smart then
				local tokens = self.data.lines[caret.y].tokens
				for i = #tokens, 1, -1 do
					local token = tokens[i]
					if caret.x > token.s then
						local indent = self.mode.indent[token.str]
						if indent and not indent[token.mode] then
							local token2 = tokens[i + 1]
							if token2 then
								local bracket = self.mode.bracket2[token2.str]
								if bracket and not bracket.ignore_mode[token2.mode] then
									self:InsertStrAt(caret.x, caret.y, "\n" .. string.rep("\t", e + 1), true)
									move = -e - 1
								else
									e = e + 1
								end
							else
								e = e + 1
							end
							
							break
						else
							local outdent = self.mode.outdent[token.str]
							if outdent and not outdent[token.mode] then break end
						end
					end
				end
			end
			
			self:InsertStrAt(caret.x, caret.y, "\n" .. string.rep("\t", e), true)
			
			if move then
				self:MoveCaret(caret_id, move, nil)
			end
		else
			self:InsertStrAt(caret.x, caret.y, "\n", true)
		end
	end
	
	self:PushHistoryBlock()
	self:Rebuild()
end

function Act.indent(self)
	for caret_id, caret in ipairs(self.carets) do
		if caret.select_y and caret.select_y ~= caret.y then
			for y = math.min(caret.y, caret.select_y), math.max(caret.y, caret.select_y) do
				self:InsertStrAt(1, y, "\t", true)
				if y == caret.select_y then
					caret.select_x = caret.select_x + 1
				end
			end
		else
			self:InsertStrAt(caret.x, caret.y, "\t", true)
		end
	end
	
	self:PushHistoryBlock()
	self:Rebuild()
end

function Act.outdent(self)
	for caret_id, caret in ipairs(self.carets) do
		if caret.select_y and caret.select_y ~= caret.y then
			for y = math.min(caret.y, caret.select_y), math.max(caret.y, caret.select_y) do
				if string.sub(self.content_lines[y][1], 1, 1) == "\t" then
					self:RemoveStrAt(1, y, 1, true)
					if y == caret.select_y then
						caret.select_x = caret.select_x - 1
					end
				end
			end
		else
			self:InsertStrAt(caret.x, caret.y, "\t", true)
		end
	end
	
	self:PushHistoryBlock()
	self:Rebuild()
end

function Act.selectall(self)
	local lines = self.content_lines
	
	self:ClearCarets()
	self:SetCaret(1, lines[#lines][2], #lines)
	
	self.carets[1].select_x = 1
	self.carets[1].select_y = 1
	
	for _, l in ipairs(lines) do
		print(l[2], l[1])
	end
end

function Act.writestr(self, str)
	self:InsertStr(str)
end

function Act.delete(self, typ, count_dir)
	local has_selection = false
	for _, caret in ipairs(self.carets) do
		if caret.select_x then
			has_selection = true
			break
		end
	end
	
	if has_selection then
		self:RemoveSelection()
	elseif typ == "char" then
		if count_dir == -1 and Settings.settings.auto_closing_bracket then
			local lines = self.content_lines
			for caret_id, caret in ipairs(self.carets) do
				if caret.x > 1 and caret.x <= lines[caret.y][2] then
					local bracket = self.mode.bracket[sub(lines[caret.y][1], caret.x - 1, caret.x - 1)]
					if bracket and sub(lines[caret.y][1], caret.x, caret.x) == bracket.close then
						self:RemoveStrAt(caret.x + 1, caret.y, -2, true)
					else
						self:RemoveStrAt(caret.x, caret.y, -1, true)
					end
				else
					self:RemoveStrAt(caret.x, caret.y, -1, true)
				end
			end
			
			self:PushHistoryBlock()
			self:Rebuild()
		else
			self:RemoveStr(count_dir)
		end
	elseif typ == "word" then
		local lines = self.content_lines
		for caret_id, caret in ipairs(self.carets) do
			if count_dir > 0 then
				local line = lines[caret.y][1]
				local ll = lines[caret.y][2]
				if caret.x >= ll then
					if caret.y == #lines then goto SKIP end
					
					self:RemoveStrAt(caret.x, caret.y, 1, true)
					
					goto SKIP
				end
				
				local e = select(2, string.find(sub(line, caret.x), "[^%w_]*[%w_]+"))
				self:RemoveStrAt(caret.x, caret.y, e or (ll + 1 - caret.x), true)
			else
				local line = lines[caret.y][1]
				if caret.x == 1 then
					if caret.y == 1 then goto SKIP end
					
					self:RemoveStrAt(caret.x, caret.y, -1, true)
					
					goto SKIP
				end
				
				local s = string.find(sub(line, 1, caret.x - 1), "[%w_]*[^%w_]*$")
				self:RemoveStrAt(caret.x, caret.y, s - caret.x, true)
			end
			
			::SKIP::
		end
		
		self:PushHistoryBlock()
		self:Rebuild()
	end
	
	self:ClearExcessCarets()
end

function Act.move(self, typ, count_dir, selc)
	local lines = self.content_lines
	
	local function handleSelect(caret)
		if selc then
			if not caret.select_x then
				caret.select_x = caret.x
				caret.select_y = caret.y
			end
		elseif caret.select_x then
			caret.select_x = nil
			caret.select_y = nil
		end
	end
	
	for caret_id, caret in ipairs(self.carets) do
		if typ == "char" then
			if selc and not caret.select_x then
				caret.select_x = caret.x
				caret.select_y = caret.y
				
				self:MoveCaret(caret_id, count_dir, nil)
			elseif not selc and caret.select_x then
				local sx, sy = caret.x, caret.y
				local ex, ey = caret.select_x, caret.select_y
				
				if ey < sy or (ex < sx and sy == ey) then
					local ex_, ey_ = ex, ey
					ex, ey = sx, sy
					sx, sy = ex_, ey_
				end
				
				if count_dir < 0 then
					self:SetCaret(caret_id, sx, sy)
				else
					self:SetCaret(caret_id, ex, ey)
				end
				
				caret.select_x = nil
				caret.select_y = nil
			else
				self:MoveCaret(caret_id, count_dir, nil)
			end
		elseif typ == "word" then
			handleSelect(caret)
			
			if count_dir > 0 then
				local line = lines[caret.y][1]
				local ll = lines[caret.y][2]
				if caret.x >= ll then
					if caret.y == #lines then goto SKIP end
					
					self:SetCaret(caret_id, 1, caret.y + 1)
					
					goto SKIP
				end
				
				local e = select(2, string.find(sub(line, caret.x), "[^%w_]*[%w_]+"))
				self:SetCaret(caret_id, e and (e + caret.x) or (ll + 1), nil)
			else
				local line = lines[caret.y][1]
				if caret.x == 1 then
					if caret.y == 1 then goto SKIP end
					
					self:SetCaret(caret_id, lines[caret.y - 1][2] + 1, caret.y - 1)
					
					goto SKIP
				end
				
				local s = string.find(sub(line, 1, caret.x - 1), "[%w_]*[^%w_]*$")
				self:SetCaret(caret_id, s, nil)
			end
			
			::SKIP::
		elseif typ == "line" then
			handleSelect(caret)
			
			self:MoveCaret(caret_id, nil, count_dir)
		elseif typ == "page" then
			handleSelect(caret)
			
			self:MoveCaret(caret_id, nil, count_dir * self:VisibleLineCount())
			self:DoScroll(count_dir * self:VisibleLineCount() * Settings.settings.font_size)
		elseif typ == "bol" then
			handleSelect(caret)
			
			local e = select(2, string.find(lines[caret.y][1], "^%s*")) + 1
			if caret.x ~= e or caret.x ~= 1 then
				self:SetCaret(caret_id, caret.x == e and 1 or e, nil)
			end
		elseif typ == "eol" then
			handleSelect(caret)
			
			self:SetCaret(caret_id, lines[caret.y][2])
		elseif typ == "bof" then
			handleSelect(caret)
			
			self:SetCaret(caret_id, 1, 1)
		elseif typ == "eof" then
			handleSelect(caret)
			
			self:SetCaret(caret_id, lines[#lines][2], #lines)
		end
	end
	
	self:ClearExcessCarets()
end

----------------------------------------

local Editor = {Act = Act}

function Editor:Init()
	self.content_lines = {{"\0", 0}}
	self.history = {}
	self.history_pointer = 0
	self.history_block = {}
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
	
	self.scrolltarget = 0
	self.scrollbar = self:Add("DVScrollBar")
	self.scrollbar:Dock(RIGHT)
	self.scrollbar:SetWidth(12)
	self.scrollbar:SetHideButtons(true)
	self.scrollbar.OnMouseWheeled = function(_, delta) self:OnMouseWheeled(delta) return true end
	self.scrollbar.OnMousePressed = function()
		local y = select(2, self.scrollbar:CursorPos())
		self:DoScroll((y > self.scrollbar.btnGrip.y and 1 or -1) * self:VisibleLineCount() * Settings.settings.font_size)
	end
	self.scrollbar.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, Settings.settings.style_data.highlight)
	end
	self.scrollbar.btnGrip.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, Settings.settings.style_data.linenumber)
	end
	
	self.lineholder_dock = self:Add("Panel")
	self.lineholder_dock:Dock(FILL)
	self.lineholder_dock:SetMouseInputEnabled(false)
	
	self.lineholder = self.lineholder_dock:Add("Panel")
	self.lineholder:SetMouseInputEnabled(false)
	self.lineholder.Paint = function(_, w, h)
		local th = Settings.lookupSetting("font_size")
		local lines = self.content_lines
		for _, caret in ipairs(self.carets) do
			if caret.select_x then
				surface.SetDrawColor(Settings.settings.style_data.highlight)
				
				local sx, sy = caret.x, caret.y
				local ex, ey = caret.select_x, caret.select_y
				
				if ey < sy or (ex < sx and sy == ey) then
					local ex_, ey_ = ex, ey
					ex, ey = sx, sy
					sx, sy = ex_, ey_
				end
				
				ex = ex - 1
				
				if sy == ey then
					local offset = surface.GetTextSize(getRenderString(sub(lines[sy][1], 1, sx - 1)))
					local tw = surface.GetTextSize(getRenderString(sub(lines[sy][1], sx, ex)))
					surface.DrawRect(self.gutter_size + offset, sy * th - th, tw, th)
				else
					local offset = surface.GetTextSize(getRenderString(sub(lines[sy][1], 1, sx - 1)))
					local tw = surface.GetTextSize(getRenderString(sub(lines[sy][1], sx)))
					surface.DrawRect(self.gutter_size + offset, sy * th - th, tw, th)
					
					for y = sy + 1, ey - 1 do
						local tw = surface.GetTextSize(getRenderString(lines[y][1]))
						surface.DrawRect(self.gutter_size, y * th - th, tw, th)
					end
					
					local tw = surface.GetTextSize(getRenderString(sub(lines[ey][1], 1, ex)))
					surface.DrawRect(self.gutter_size, ey * th - th, tw, th)
				end
			end
		end
		
		return true
	end
	self.lineholder.PaintOver = function(_, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		
		local th = Settings.lookupSetting("font_size")
		local lines = self.content_lines
		for caret_id, caret in ipairs(self.carets) do
			surface.DrawRect(self.gutter_size + caret.visual_x, caret.y * th - th, 2, th)
		end
	end
	
	self:SetCursor("beam")
	self:SetSyntax("lua")
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
	
	local th = Settings.lookupSetting("font_size")
	local lines = self.content_lines
	for caret_id, caret in ipairs(self.carets) do
		surface.SetTextPos(self.gutter_size, h - th * caret_id)
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
	
	if key == KEY_TAB then
		self.refocus = true
	end
	
	if bind then
		local act = self.Act[bind.act]
		
		-- Gotta check since there are binds that are handled by different things such as changing active tab
		if act then
			act(self, unpack(bind.args or {}))
			
			return true
		end
	end
	
	return false
end

function Editor:OnMousePressed(key)
	if key == MOUSE_LEFT then
		self:RequestFocus()
	end
	
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
	end
end

function Editor:OnMouseWheeled(delta)
	self:DoScroll(-delta * Settings.settings.font_size * Settings.settings.scroll_multiplier)
end

function Editor:OnTextChanged()
	-- print(#self.textentry:GetText(), select(2, string.gsub(self.textentry:GetText(), "\n", "")), self.textentry:GetText())
	local str = self.textentry:GetText()
	self.textentry:SetText("")
	
	local bracket, bracket2 = nil, nil
	if not self.is_pasted then
		if str == "\n" then return end
		if Settings.settings.auto_closing_bracket then
			bracket = self.mode.bracket[str]
			bracket2 = self.mode.bracket2[str]
		end
	elseif self.is_pasted then
		self.is_pasted = false
	end
	
	if ignore_chars[str] then return end
	if #str == 0 then return end
	
	local selection = false
	for _, caret in ipairs(self.carets) do
		if caret.select_x then
			selection = true
			break
		end
	end
	if selection then
		self:RemoveSelection()
	end
	
	-- self:InsertStr(str)
	for caret_id, caret in ipairs(self.carets) do
		if bracket2 and sub(self.content_lines[caret.y][1], caret.x, caret.x) == str then
			if not bracket2.ignore_char[sub(self.content_lines[caret.y][1], caret.x - 1, caret.x - 1)] then
				self:MoveCaret(caret_id, 1, nil)
			else
				self:InsertStrAt(caret.x, caret.y, str, true)
			end
		elseif bracket and not bracket.ignore_mode[self:GetToken(caret.x, caret.y).mode] then
			self:InsertStrAt(caret.x, caret.y, str .. bracket.close, true)
			self:MoveCaret(caret_id, -1, nil)
		else
			self:InsertStrAt(caret.x, caret.y, str, true)
		end
	end
	
	if Settings.settings.indent_smart then
		for caret_id, caret in ipairs(self.carets) do
			local str = string.match(self.content_lines[caret.y][1], "\t%s*(%a+)[\n%z]")
			local outdent = self.mode.outdent[str]
			if outdent then
				self:RemoveStrAt(1, caret.y, 1, true)
			end
		end
	end
	
	self:PushHistoryBlock()
	self:Rebuild()
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

function Editor:PerformLayout()
	self.lineholder:SetSize(select(2, self.lineholder_dock:GetSize()), 99999)
	self:UpdateScrollbar()
end

function Editor:UpdateScrollbar()
	local s = select(2, self.lineholder_dock:GetSize())
	self.scrollbar:SetUp(s, s + Settings.lookupSetting("font_size") * (#self.content_lines - 1) + 1)
end

function Editor:DoScroll(delta)
	local speed = Settings.settings.scroll_speed
	self.scrolltarget = math.Clamp(self.scrolltarget + delta, 0, self.scrollbar.CanvasSize)
	if speed == 0 then
		self.scrollbar:SetScroll(self.scrolltarget)
	else
		self.scrollbar:AnimateTo(self.scrolltarget, 0.1 / speed, 0, -1)
	end
end

function Editor:OnVScroll(scroll)
	if self.scrollbar.Dragging then
		self.scrolltarget = -scroll
	end
	
	self.lineholder:SetPos(0, scroll)
end

function Editor:VisibleLineCount()
	return math.ceil(select(2, self.lineholder_dock:GetSize()) / Settings.lookupSetting("font_size"))
end

function Editor:PushHistoryBlock()
	self.history_pointer = self.history_pointer + 1
	self.history[self.history_pointer] = {table.Copy(self.carets), self.history_block}
	for i = self.history_pointer + 1, #self.history do
		self.history[i] = nil
	end
	self.history_block = {}
end

function Editor:AddHistory(tbl)
	self.history_block[#self.history_block + 1] = tbl
end

function Editor:Undo()
	if self.history_pointer == 0 then return end
	
	local his = self.history[self.history_pointer]
	self.carets = his[1]
	for caret_id, caret in ipairs(self.carets) do
		self:SetCaret(caret_id, caret.x, caret.y)
	end
	for _, v in ipairs(his[2]) do
		v[1](self, v[3], v[4], v[5])
	end
	self.history_pointer = self.history_pointer - 1
	
	self:Rebuild()
end

function Editor:Redo()
	if self.history_pointer == #self.history then return end
	
	self.history_pointer = self.history_pointer + 1
	local his = self.history[self.history_pointer]
	self.carets = his[1]
	for caret_id, caret in ipairs(self.carets) do
		self:SetCaret(caret_id, caret.x, caret.y)
	end
	for _, v in ipairs(his[2]) do
		v[2](self, v[3], v[4], v[6])
	end
	
	self:Rebuild()
end

function Editor:Rebuild(line_count, start_line)
	local t = SysTime()
	
	if not line_count then
		self.lineholder:Clear()
		self.lines = {}
		self.data = Lexer.tokenize(self.lexer, self.content_lines)
		
		local h = Settings.lookupSetting("font_size")
		for i, line_data in ipairs(self.data.lines) do
			local line = self.lineholder:Add("SyperEditorLine")
			line:SetData(line_data)
			line:SetHeight(h)
			line:Dock(TOP)
			
			self.lines[i] = line
		end
	else
		self.data = Lexer.tokenize(self.lexer, self.content_lines, line_count, self.data, start_line)
		local lines = self.data.lines
		local h = Settings.lookupSetting("font_size")
		for i = start_line, math.min(#lines, start_line + line_count - 1) do
			local line = self.lines[i]
			if not line then
				line = self.lineholder:Add("SyperEditorLine")
				line:SetHeight(h)
				line:Dock(TOP)
				
				self.lines[i] = line
			end
			
			line:SetData(lines[i])
		end
	end
	
	self:UpdateScrollbar()
	
	print("rebuild", SysTime() - t)
end

function Editor:GetToken(x, y)
	local tokens = self.data.lines[y].tokens
	for i = #tokens, 1, -1 do
		local token = tokens[i]
		if x >= token.s then
			return token
		end
	end
end

function Editor:SetSyntax(syntax)
	self.lexer = Lexer.lexers[syntax]
	self.mode = Mode.modes[syntax]
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
	caret.visual_x = surface.GetTextSize(getRenderString(sub(self.content_lines[caret.y][1], 1, caret.x - 1)))
end

function Editor:MoveCaret(i, x, y)
	local lines = self.content_lines
	local caret = self.carets[i]
	
	if x and x ~= 0 then
		local xn = x / math.abs(x)
		for _ = xn, x, xn do
			if x > 0 then
				local ll = lines[caret.y][2]
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
						caret.x = lines[caret.y][2]
					end
					caret.max_x = caret.x
				end
			end
		end
	end
	
	if y and y ~= 0 then
		local yn = y / math.abs(y)
		for _ = yn, y, yn do
			if y > 0 then
				if caret.y < #lines then
					caret.x = renderToRealPos(lines[caret.y + 1][1], realToRenderPos(lines[caret.y][1], caret.x))
					caret.y = caret.y + 1
					
					if caret.y == #lines then break end
				end
			elseif caret.y > 1 then
				caret.x = renderToRealPos(lines[caret.y - 1][1], realToRenderPos(lines[caret.y][1], caret.x))
				caret.y = caret.y - 1
				
				if caret.y == 1 then break end
			end
		end
	end
	
	caret.visual_x = surface.GetTextSize(getRenderString(sub(self.content_lines[caret.y][1], 1, caret.x - 1)))
end

function Editor:InsertStr(str)
	local y = math.huge
	for _, caret in ipairs(self.carets) do
		y = math.min(y, caret.y)
		self:InsertStrAt(caret.x, caret.y, str, true)
	end
	
	self:PushHistoryBlock()
	
	self:Rebuild(self:VisibleLineCount(), y)
end

function Editor:InsertStrAt(x, y, str, do_history)
	if do_history then
		self:AddHistory({Editor.RemoveStrAt, Editor.InsertStrAt, x, y, len(str), str})
	end
	
	local lines, line_count, p = {}, 0, 1
	while true do
		local s = string.find(str, "\n", p)
		lines[#lines + 1] = string.sub(str, p, s)
		if not s then break end
		p = s + 1
		line_count = line_count + 1
	end
	local cs = self.content_lines
	local e = y + line_count
	local eo = cs[y][1]
	cs[y][1] = sub(cs[y][1], 1, x - 1) .. lines[1]
	cs[y][2] = len(cs[y][1])
	for i = y + 1, e do
		local line = lines[i - y + 1]
		table.insert(cs, i, {line, len(line)})
	end
	cs[e][1] = cs[e][1] .. sub(eo, x)
	cs[e][2] = len(cs[e][1])
	
	local length = len(str)
	for caret_id, caret in ipairs(self.carets) do
		if caret.y > y or (caret.y == y and caret.x >= x) then
			self:MoveCaret(caret_id, length, nil)
		end
	end
end

function Editor:RemoveStr(length)
	local history = {}
	for caret_id, caret in ipairs(self.carets) do
		self:RemoveStrAt(caret.x, caret.y, length, true)
	end
	
	self:PushHistoryBlock()
	self:Rebuild()
end

function Editor:RemoveSelection()
	local history = {}
	local cs = self.content_lines
	for caret_id, caret in ipairs(self.carets) do
		if caret.select_x then
			local sx, sy = caret.x, caret.y
			local ex, ey = caret.select_x, caret.select_y
			
			if ey < sy or (ex < sx and sy == ey) then
				local ex_, ey_ = ex, ey
				ex, ey = sx, sy
				sx, sy = ex_, ey_
			end
			
			local length = sy == ey and ex - sx or cs[sy][2] - sx + 1
			for y = sy + 1, ey - 1 do
				length = length + cs[y][2]
			end
			if sy ~= ey then
				length = length + ex - 1
			end
			
			local rem, x, y, rem_str = self:RemoveStrAt(sx, sy, length, true)
			history[#history + 1] = {Editor.InsertStrAt, Editor.RemoveStrAt, x, y, rem_str, rem}
			-- self:SetCaret(caret_id, sx, sy)
			
			caret.select_x = nil
			caret.select_y = nil
		end
	end
	
	self:PushHistoryBlock()
	self:Rebuild()
end

function Editor:RemoveStrAt(x, y, length, do_history)
	local cs = self.content_lines
	local rem = {}
	local length_org = length
	length = math.abs(length)
	
	if length_org < 0 then
		for _ = 1, length do
			x = x - 1
			if x < 1 then
				if y == 1 then
					length = length - 1
				else
					y = y - 1
					x = cs[y][2]
				end
			end
		end
	end
	
	for caret_id, caret in ipairs(self.carets) do
		local b = (caret.y == y and caret.x > x)
		if caret.y > y or b then
			self:MoveCaret(caret_id, b and -math.min(caret.x - x, length) or -length, nil)
		end
	end
	
	local i = 0
	while length > 0 do
		if not cs[y] then break end
		
		local org = cs[y][2]
		rem[#rem + 1] = sub(cs[y][1], x, x + length - 1)
		local str = sub(cs[y][1], 1, x - 1) .. sub(cs[y][1], x + length)
		cs[y][1] = str
		cs[y][2] = len(str)
		length = length - (org - cs[y][2])
		if cs[y][2] == x - 1 then
			if #cs == 1 then
				if cs[1][2] == 0 then
					cs[1] = {"\0", 1}
				end
				
				break
			end
			
			cs[y][1] = cs[y][1] .. (cs[y + 1] and cs[y + 1][1] or "")
			cs[y][2] = len(cs[y][1])
			table.remove(cs, y + 1)
		end
		
		i = i + 1
		if i == 4096 then print("!!! Syper: Editor:RemoveStrAt") break end
	end
	
	rem = table.concat(rem, "")
	length = math.abs(length_org) - length
	
	if do_history then
		self:AddHistory({Editor.InsertStrAt, Editor.RemoveStrAt, x, y, rem, length})
	end
	
	-- Update visual caret pos
	for caret_id, caret in ipairs(self.carets) do
		self:MoveCaret(caret_id, nil, nil)
	end
	
	return length, x, y, rem
end

vgui.Register("SyperEditor", Editor, "Panel")
