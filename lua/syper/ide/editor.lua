local Lexer = Syper.Lexer
local Mode = Syper.Mode
local Settings = Syper.Settings
local TOKEN = Syper.TOKEN

----------------------------------------

local editors = {}

local settings
local len, sub, ignore_chars, tab_str, tab_strsize
local function settingsUpdate(s)
	settings = s
	
	len = settings.utf8 and utf8.len or string.len
	sub = settings.utf8 and utf8.sub or string.sub
	
	ignore_chars = {}
	if settings.ignore_chars then
		for _, c in ipairs(settings.ignore_chars) do
			ignore_chars[c] = true
		end
	end
	
	if settings.tab_spaces then
		tab_str = string.rep(" ", settings.tab_size)
		tab_strsize = settings.tab_size
	else
		tab_str = "\t"
		tab_strsize = 1
	end
	
	for editor, _ in pairs(editors) do
		editor:Refresh()
	end
end

settingsUpdate(Settings.settings)
hook.Add("SyperSettings", "syper_editor", settingsUpdate)

----------------------------------------

local function getRenderString(str, offset)
	local tabsize = settings.tab_size
	local ctrl = settings.show_control_characters
	local s = ""
	offset = offset or 0
	
	for i = 1, len(str) do
		local c = sub(str, i, i)
		s = s .. (c == "\t" and string.rep(" ", tabsize - ((len(s) + offset) % tabsize)) or ((not ctrl or string.find(c, "%C")) and c or ("<0x" .. string.byte(c) .. ">")))
	end
	
	return s
end

local function renderToRealPos(str, pos)
	local tabsize = settings.tab_size
	local l = 0
	
	for i = 1, len(str) do
		local t = sub(str, i, i) == "\t"
		local c = tabsize - (l % tabsize)
		l = l + (t and c or 1)
		-- if l >= pos then return i end
		if (t and (l - math.floor(c / 2 - 0.5)) or l) >= pos then return i end
	end
	
	return len(str)
end

local function realToRenderPos(str, pos)
	local tabsize = settings.tab_size
	local l = 0
	
	for i = 1, pos - 1 do
		l = l + (sub(str, i, i) == "\t" and tabsize - (l % tabsize) or 1)
	end
	
	return l + 1
end

local function getTabStr(x, line)
	if settings.tab_spaces then
		return string.rep(" ", settings.tab_size - ((x - 1) % settings.tab_size))
	elseif settings.tab_inline_spaces then
		if string.match(line, "%s*()") == x then
			return "\t"
		else
			return string.rep(" ", settings.tab_size - ((x - 1) % settings.tab_size))
		end
	end
	
	return "\t"
end

local function matchWord(str, x)
	local s, e = string.match(sub(str, 1, x), "()[%w_]*$"), (string.match(sub(str, x), "^[%w_]*()") + x - 1)
	return s, e, sub(str, s, e)
end

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
	
	local lines = self.content_data.lines
	for caret_id = #self.carets, 1, -1 do
		local caret = self.carets[caret_id]
		if caret.select_x then
			local sx, sy = caret.x, caret.y
			local ex, ey = caret.select_x, caret.select_y
			
			if ey < sy or (ex < sx and sy == ey) then
				sx, sy, ex, ey = ex, ey, sx, sy
			end
			
			add(sub(lines[sy][1], sx, sy == ey and ex - 1 or -1))
			
			for y = sy + 1, ey - 1 do
				add(lines[y][1])
			end
			
			if sy ~= ey then
				add(sub(lines[ey][1], 1, ex - 1))
			end
			
			if caret_id > 1 then
				add("\n")
			end
		end
	end
	
	if empty then
		for caret_id = #self.carets, 1, -1 do
			add(lines[self.carets[caret_id].y][1])
			
			if caret_id > 1 then
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
	
	if self:HasSelection() then
		self:RemoveSelection()
	end
end

function Act.paste(self)
	-- This will never be used
	self.is_pasted = true
end

function Act.pasteindent(self)
	-- TODO
end

function Act.newline(self)
	if self:HasSelection() then
		self:RemoveSelection()
	end
	
	-- TODO: fix bug with multiple caret smart auto indent
	
	for caret_id, caret in ipairs(self.carets) do
		if settings.indent_auto then
			local spacer, e = string.match(self.content_data:GetLineStr(caret.y), "^([^\n%S]*)()")
			local move = nil
			
			if settings.indent_smart then
				local tokens = self.content_data:GetLineTokens(caret.y)
				for i = #tokens, 1, -1 do
					local token = tokens[i]
					if caret.x > token.s then
						local indent = self.mode.indent[token.str]
						if indent and not indent[token.mode] then
							local token2 = tokens[i + 1]
							if token2 then
								local bracket = self.mode.bracket2[token2.str]
								if bracket and not bracket.ignore_mode[token2.mode] then
									self:InsertStrAt(caret.x, caret.y, "\n" .. spacer .. tab_str, true)
									move = -e
								else
									spacer = spacer .. tab_str
								end
							else
								spacer = spacer .. tab_str
							end
							
							break
						else
							local outdent = self.mode.outdent[token.str]
							if outdent and not outdent[token.mode] then break end
						end
					end
				end
			end
			
			self:InsertStrAt(caret.x, caret.y, "\n" .. spacer, true)
			
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
				self:InsertStrAt(1, y, tab_str, true)
			end
			
			caret.select_x = caret.select_x + tab_strsize
		else
			self:InsertStrAt(caret.x, caret.y, getTabStr(caret.x, self.content_data:GetLineStr(caret.y)), true)
		end
	end
	
	self:PushHistoryBlock()
	self:Rebuild()
end

function Act.outdent(self)
	local lines = self.content_data.lines
	for caret_id, caret in ipairs(self.carets) do
		if caret.select_y and caret.select_y ~= caret.y then
			for y = math.min(caret.y, caret.select_y), math.max(caret.y, caret.select_y) do
				if string.sub(lines[y][1], 1, tab_strsize) == tab_str then
					self:RemoveStrAt(1, y, tab_strsize, true)
				end
			end
			
			caret.select_x = caret.select_x - tab_strsize
		else
			self:InsertStrAt(caret.x, caret.y, getTabStr(caret.x, lines[caret.y][1]), true)
		end
	end
	
	self:PushHistoryBlock()
	self:Rebuild()
end

function Act.comment(self)
	local lines = self.content_data.lines
	for caret_id, caret in ipairs(self.carets) do
		local sy = caret.y
		local ey = caret.select_y or caret.y
		
		if ey < sy then
			ey, sy = sy, ey
		end
		
		local level = math.huge
		for y = sy, ey do
			level = math.min(level, string.match(lines[y][1], "%s*()"))
		end
		
		local remove = true
		local cs = #self.mode.comment
		for y = sy, ey do
			if string.sub(lines[y][1], level, level + cs - 1) ~= self.mode.comment then
				remove = false
				break
			end
		end
		
		if remove then
			for y = sy, ey do
				self:RemoveStrAt(level, y, cs, true)
			end
			
			if caret.select_x then
				caret.select_x = caret.select_x - cs
			end
		else
			for y = sy, ey do
				self:InsertStrAt(level, y, self.mode.comment, true)
			end
			
			if caret.select_x then
				caret.select_x = caret.select_x + cs
			end
		end
	end
	
	self:PushHistoryBlock()
	self:Rebuild()
end

function Act.selectall(self)
	local lines = self.content_data.lines
	
	self:ClearCarets()
	self:SetCaret(1, lines[#lines][2], #lines)
	
	self.carets[1].select_x = 1
	self.carets[1].select_y = 1
	
	for _, l in ipairs(lines) do
		print(l[2], l[1])
	end
end

local lx, ly, stage, last_id
function Act.setcaret(self, new)
	local sx, sy = self:GetCursorAsCaret()
	local caret_id
	if lx == sx and ly == sy then
		caret_id = last_id
	else
		if new then
			caret_id = self:AddCaret(sx, sy)
			for k, v in pairs(self:ClearExcessCarets()) do
				if k == caret_id then
					caret_id = v
				end
			end
		else
			self:ClearCarets()
			caret_id = 1
		end
		stage = 0
	end
	local caret = self.carets[caret_id]
	
	if RealTime() - self.last_click < 1 and stage ~= 0 and lx == sx and ly == sy then
		if stage == 2 then
			caret.select_x = 1
			caret.select_y = sy
			if sy < self.content_data:GetLineCount() then
				self:SetCaret(caret_id, 1, sy + 1)
			else
				self:SetCaret(caret_id, self.content_data:GetLineLength(sy), sy)
			end
			stage = 0
		else
			local s, e = matchWord(self.content_data:GetLineStr(sy), sx)
			caret.select_x = s
			caret.select_y = sy
			self:SetCaret(caret_id, e, sy)
			stage = 2
		end
	else
		caret.select_x = nil
		caret.select_y = nil
		self:SetCaret(caret_id, sx, sy)
		stage = 1
	end
	
	for k, v in pairs(self:ClearExcessCarets()) do
		if k == caret_id then
			caret_id = v
		end
	end
	
	last_id = caret_id
	lx, ly = sx, sy
	
	self:RequestCapture(true)
	local key = Settings.lookupAct("setcaret")
	self.on_mouse_hold[#self.on_mouse_hold + 1] = {key, function()
		local caret = self.carets[caret_id]
		if not caret then return end
		local x, y = self:GetCursorAsCaret()
		self:SetCaret(caret_id, x, y)
		if sx ~= x or sy ~= y then
			caret.select_x = sx
			caret.select_y = sy
		else
			caret.select_x = nil
			caret.select_y = nil
		end
		
		for k, v in pairs(self:ClearExcessCarets()) do
			if k == caret_id then
				caret_id = v
			end
		end
	end}
	
	self.on_mouse_release[#self.on_mouse_release + 1] = {key, function()
		self:RequestCapture(false)
	end}
	
	self.caretblink = RealTime()
end

function Act.writestr(self, str)
	self:InsertStr(str)
end

function Act.delete(self, typ, count_dir)
	if self:HasSelection() then
		self:RemoveSelection()
	elseif typ == "char" then
		if count_dir == -1 and settings.auto_closing_bracket then
			local lines = self.content_data.lines
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
		local lines = self.content_data.lines
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
end

function Act.move(self, typ, count_dir, selc)
	local lines = self.content_data.lines
	
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
					sx, sy, ex, ey = ex, ey, sx, sy
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
			self:DoScroll(count_dir * self:VisibleLineCount() * settings.font_size)
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
end

function Act.goto_line(self, line)
	self:ClearCarets()
	self:SetCaret(1, 1, math.Clamp(settings.gutter_relative and (self.carets[1].y + line) or line, 1, self.content_data:GetLineCount()))
end

----------------------------------------

local Editor = {Act = Act}

function Editor:Init()
	self.content_data = nil
	self.history = {}
	self.history_pointer = 0
	self.history_block = {}
	self.carets = {}
	self.caretmode = RealTime()
	self.caretblink = 0
	self.gutter_size = 50
	self.editable = true
	self.path = nil
	self.on_mouse_hold = {}
	self.on_mouse_release = {}
	self.last_click = 0
	self.mouse_captures = 0
	
	self:SetAllowNonAsciiCharacters(true)
	self:SetMultiline(true)
	
	self.scrolltarget = 0
	self.scrollbar = self:Add("DVScrollBar")
	self.scrollbar:Dock(RIGHT)
	self.scrollbar:SetWidth(12)
	self.scrollbar:SetHideButtons(true)
	self.scrollbar.OnMouseWheeled = function(_, delta) self:OnMouseWheeled(delta) return true end
	self.scrollbar.OnMousePressed = function()
		local y = select(2, self.scrollbar:CursorPos())
		self:DoScroll((y > self.scrollbar.btnGrip.y and 1 or -1) * self:VisibleLineCount() * settings.font_size)
	end
	self.scrollbar.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, settings.style_data.highlight)
	end
	self.scrollbar.btnGrip.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, settings.style_data.gutter_foreground)
	end
	
	self.lineholder_dock = self:Add("Panel")
	self.lineholder_dock:Dock(FILL)
	self.lineholder_dock:SetMouseInputEnabled(false)
	
	self.lineholder = self.lineholder_dock:Add("Panel")
	self.lineholder:SetMouseInputEnabled(false)
	self.lineholder.Paint = function(_, w, h)
		local th = settings.font_size
		local gw = self.gutter_size
		
		-- caret select
		surface.SetFont("syper_syntax_1")
		surface.SetDrawColor(settings.style_data.highlight)
		
		local lines = self.content_data.lines
		for _, caret in ipairs(self.carets) do
			if caret.select_x then
				local sx, sy = caret.x, caret.y
				local ex, ey = caret.select_x, caret.select_y
				
				if ey < sy or (ex < sx and sy == ey) then
					sx, sy, ex, ey = ex, ey, sx, sy
				end
				
				ex = ex - 1
				
				if sy == ey then
					local offset = surface.GetTextSize(getRenderString(sub(lines[sy][1], 1, sx - 1)))
					local tw = surface.GetTextSize(getRenderString(sub(lines[sy][1], sx, ex)))
					surface.DrawRect(gw + offset + 1, sy * th - th + 1, tw - 2, th - 2)
				else
					local offset = surface.GetTextSize(getRenderString(sub(lines[sy][1], 1, sx - 1)))
					local tw = surface.GetTextSize(getRenderString(sub(lines[sy][1], sx))) + th / 3
					surface.DrawRect(gw + offset + 1, sy * th - th + 1, tw - 1, th - 1)
					
					for y = sy + 1, ey - 1 do
						local tw = surface.GetTextSize(getRenderString(lines[y][1])) + th / 3
						surface.DrawRect(gw, y * th - th, tw, th)
					end
					
					local tw = surface.GetTextSize(getRenderString(sub(lines[ey][1], 1, ex)))
					surface.DrawRect(gw, ey * th - th, tw - 1, th - 1)
				end
			end
		end
		
		-- content
		surface.SetDrawColor(settings.style_data.gutter_background)
		surface.DrawRect(0, 0, gw, h)
		
		local y = self:FirstVisibleLine()
		for y = y, math.min(self.content_data:GetLineCount(), y + self:VisibleLineCount()) do
			local offset_y = y * th - th
			
			local linenum = tostring(settings.gutter_relative and y - self.carets[1].y or y)
			surface.SetTextColor(settings.style_data.gutter_foreground)
			surface.SetFont("syper_syntax_1")
			local tw = surface.GetTextSize(linenum)
			surface.SetTextPos(gw - tw - settings.gutter_margin, offset_y)
			surface.DrawText(linenum)
			
			local offset_x = gw
			local line = self.content_data.lines[y][6]
			for i, token in ipairs(line) do
				if token[5] then
					surface.SetDrawColor(token[5])
					surface.DrawRect(offset_x, offset_y, i == #line and 9999 or token[1], th)
				end
				
				surface.SetTextColor(token[4])
				surface.SetFont(token[3])
				surface.SetTextPos(offset_x, offset_y)
				surface.DrawText(token[2])
				
				offset_x = offset_x + token[1]
			end
		end
		
		return true
	end
	self.lineholder.PaintOver = function(_, w, h)
		if not self:HasFocus() then return end
		
		surface.SetDrawColor(255, 255, 255, math.Clamp(math.cos((RealTime() - self.caretblink) * math.pi * 1.6) * 255 + 128, 0, 255))
		
		local th = settings.font_size
		for caret_id, caret in ipairs(self.carets) do
			local offset = surface.GetTextSize(getRenderString(sub(self.content_data:GetLineStr(caret.y), 1, caret.x - 1)))
			surface.DrawRect(self.gutter_size + offset, caret.y * th - th, 2, th)
		end
	end
	
	self:SetCursor("beam")
	self:SetSyntax("text")
	self:Rebuild()
	self:AddCaret(1, 1)
	
	editors[self] = true
end

function Editor:OnRemove()
	editors[self] = nil
end

function Editor:Think()
	if self.clear_excess_carets then
		self:ClearExcessCarets()
	end
	
	self.key_handled = nil
end

function Editor:Paint(w, h)
	surface.SetDrawColor(settings.style_data.background)
	surface.DrawRect(0, 0, w, h)
	
	return true
end

function Editor:PaintOver(w, h)
	surface.SetTextColor(255, 255, 255, 255)
	surface.SetFont("syper_syntax_1")
	
	local th = settings.font_size
	for caret_id, caret in ipairs(self.carets) do
		surface.SetTextPos(self.gutter_size, h - th * caret_id)
		surface.DrawText(string.format("%s,%s | %s,%s", caret.x, caret.y, caret.select_x, caret.select_y))
	end
end

function Editor:OnKeyCodeTyped(key)
	if key == 0 then return end
	
	local ctrl = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)
	local bind = Settings.lookupBind(
		ctrl,
		input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT),
		input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT),
		key
	)
	
	if key == KEY_TAB then
		self.refocus = true
	end
	
	if bind then
		local act = self.Act[bind.act]
		if act then
			act(self, unpack(bind.args or {}))
			
			self.key_handled = not ctrl
			return
		end
	end
	
	if self.ide:OnKeyCodeTyped(key) then
		self.key_handled = not ctrl
	end
end

function Editor:OnMousePressed(key)
	local bind = Settings.lookupBind(
		input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL),
		input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT),
		input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT),
		key
	)
	
	if key == MOUSE_LEFT then
		self:RequestFocus()
	end
	self.last_click = RealTime()
	
	if bind then
		local act = self.Act[bind.act]
		if act then
			act(self, unpack(bind.args or {}))
			
			return true
		end
	end
	
	return self.ide:OnMousePressed(key)
end

function Editor:OnMouseReleased(key)
	local n = {}
	for _, v in ipairs(self.on_mouse_hold) do
		if not v[1] == key then
			n[#n + 1] = v
		end
	end
	self.on_mouse_hold = n
	
	local n = {}
	for _, v in ipairs(self.on_mouse_release) do
		if not v[1] == key then
			n[#n + 1] = v
		else
			v[2]()
		end
	end
	self.on_mouse_release = n
end

function Editor:OnCursorMoved(x, y)
	for _, v in ipairs(self.on_mouse_hold) do
		v[2](x, y)
	end
end

function Editor:OnMouseWheeled(delta)
	self:DoScroll(-delta * settings.font_size * settings.scroll_multiplier)
end

function Editor:OnTextChanged()
	local str = self:GetText()
	self:SetText("")
	
	local bracket, bracket2 = nil, nil
	if not self.is_pasted then
		if self.key_handled then return end
		if settings.auto_closing_bracket then
			bracket = self.mode.bracket[str]
			bracket2 = self.mode.bracket2[str]
		end
	elseif self.is_pasted then
		self.is_pasted = false
	end
	
	if ignore_chars[str] then return end
	if #str == 0 then return end
	
	if self:HasSelection() then
		self:RemoveSelection()
	end
	
	for caret_id, caret in ipairs(self.carets) do
		local line_str = self.content_data:GetLineStr(caret.y)
		if bracket2 and sub(line_str, caret.x, caret.x) == str then
			if not bracket2.ignore_char[sub(line_str, caret.x - 1, caret.x - 1)] then
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
	
	if settings.indent_smart then
		for caret_id, caret in ipairs(self.carets) do
			local str = string.match(self.content_data:GetLineStr(caret.y), tab_str .. "%s*(%a+)[\n%z]")
			local outdent = self.mode.outdent[str]
			if outdent then
				self:RemoveStrAt(1, caret.y, tab_strsize, true)
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

function Editor:PerformLayout()
	self.lineholder:SetSize(self.lineholder_dock:GetWide(), 99999)
	self:UpdateScrollbar()
end

function Editor:RequestCapture(yes)
	self.mouse_captures = self.mouse_captures + (yes and 1 or -1)
	self:MouseCapture(self.mouse_captures > 0)
end

function Editor:UpdateScrollbar()
	local s = self.lineholder_dock:GetTall()
	self.scrollbar:SetUp(s, s + settings.font_size * (#self.content_data.lines - 1) + 1)
end

function Editor:UpdateGutter()
	surface.SetFont("syper_syntax_1")
	local w = settings.gutter_margin * 2 + surface.GetTextSize(tostring(-self.content_data:GetLineCount()))
	self.gutter_size = w
end

function Editor:DoScroll(delta)
	local speed = settings.scroll_speed
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
	return math.ceil(self.lineholder_dock:GetTall() / settings.font_size)
end

function Editor:FirstVisibleLine()
	return math.floor(-select(2, self.lineholder:GetPos()) / settings.font_size) + 1
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
	for i = #his[2], 1, -1 do
		local v = his[2][i]
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

function Editor:GetContentStr()
	local str = {}
	for i = 1, self.content_data:GetLineCount() do
		str[i] = self.content_data:GetLineStr(i)
	end
	
	str[#str] = string.sub(str[#str], 1, -2)
	
	return table.concat(str, "")
end

function Editor:Save()
	if not self.path then return false end
	
	local dirs, p = {}, 1
	while true do
		local s = string.find(self.path, "/", p)
		dirs[#dirs + 1] = string.sub(self.path, p, s)
		if not s then break end
		p = s + 1
	end
	
	for i = 1, #dirs - 1 do
		local dir = dirs[i]
		if not file.Exists(dir, "DATA") then
			file.CreateDir(dir)
		end
	end
	
	file.Write(self.path, self:GetContentStr())
	
	if self.OnSave then
		self:OnSave()
	end
	
	return true
end

function Editor:ReloadFile()
	self:SetContent(file.Read(self.path, "DATA"))
end

function Editor:SetPath(path)
	if string.find(path, "[\":]") then return false end
	
	self.path = path
	
	return true
end

function Editor:Refresh()
	self:SetContent(self:GetContentStr())
end

function Editor:Rebuild(line_count, start_line)
	local t = SysTime()
	
	local h = settings.font_size
	for _, y in ipairs(self.content_data:RebuildDirty(256)) do
		local line = {}
		local offset = 0
		for i, token in ipairs(self.content_data:GetLineTokens(y)) do
			local text = getRenderString(token.str, offset)
			offset = offset + len(text)
			local clr = settings.style_data[token.token]
			local font = "syper_syntax_" .. token.token
			surface.SetFont(font)
			local w = surface.GetTextSize(text)
			line[i] = {w, text, font, clr.f, clr.b}
		end
		
		self.content_data.lines[y][6] = line
	end
	
	self:UpdateScrollbar()
	self:UpdateGutter()
	
	print("rebuild", SysTime() - t)
end

function Editor:GetToken(x, y)
	local tokens = self.content_data:GetLineTokens(y)
	for i = #tokens, 1, -1 do
		local token = tokens[i]
		if x >= token.s then
			return token
		end
	end
end

function Editor:HasSelection()
	for _, caret in ipairs(self.carets) do
		if caret.select_x then
			return true
		end
	end
	
	return false
end

function Editor:SetSyntax(syntax)
	self.lexer = Lexer.lexers[syntax]
	self.mode = Mode.modes[syntax]
	self.content_data = Lexer.createContentTable(self.lexer, self.mode)
	self.content_data:ModifyLine(1, "\n")
end

function Editor:SetEditable(state)
	self.editable = state
end

function Editor:SetIDE(ide)
	self.ide = ide
end

function Editor:ClearCarets()
	self.carets = {self.carets[#self.carets]}
end

function Editor:MarkClearExcessCarets()
	self.clear_excess_carets = true
end

function Editor:ClearExcessCarets()
	local rem = {}
	for i, c in ipairs(self.carets) do
		if not rem[i] then
			for j, c2 in ipairs(self.carets) do
				if i ~= j and not rem[j] then
					if c.x == c2.x and c.y == c2.y then
						rem[j] = i
					elseif c.select_x then
						-- c
						local sx, sy = c.x, c.y
						local ex, ey = c.select_x, c.select_y
						
						local s = false
						if ey < sy or (ex < sx and sy == ey) then
							sx, sy, ex, ey = ex, ey, sx, sy
							s = true
						end
						
						-- c2
						local sx2, sy2 = c2.x, c2.y
						local ex2, ey2 = c2.select_x, c2.select_y
						
						if ex2 and (ey2 < sy2 or (ex2 < sx2 and sy2 == ey2)) then
							sx2, sy2, ex2, ey2 = ex2, ey2, sx2, sy2
						end
						
						if (sx2 > sx and sy2 == sy and (sy ~= ey or sx2 < ex)) or (sx2 < ex and sy2 == ey and sy ~= ey) or (sy2 > sy and sy2 < ey) or
						   (ex2 and ((ex2 > sx and ey2 == sy and (sy ~= ey or ex2 < ex)) or (ex2 < ey and ey2 == ey and sy ~= ey) or (ey2 > sy and ey2 < ey)))then
							rem[j] = i
							
							if ex2 then
								if sy2 < sy or (sx2 < sx and sy2 == sy) then
									if s then
										c.select_x = sx2
										c.select_y = sy2
									else
										c.x = sx2
										c.y = sy2
									end
								end
								
								if ey2 > sy or (ex2 > ex and sy2 == sy) then
									if s then
										c.x = ex2
										c.y = ey2
									else
										c.select_x = ex2
										c.select_y = ey2
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	local link = {}
	local new = {}
	for i, c in ipairs(self.carets) do
		if not rem[i] then
			new[#new + 1] = c
			link[i] = #new
		end
	end
	self.carets = new
	self.clear_excess_carets = false
	
	local link2 = {}
	for k, v in pairs(rem) do
		link2[k] = link[v]
	end
	
	return link2
end

function Editor:GetCursorAsCaret()
	local x, y = self:LocalCursorPos()
	y = math.Clamp(math.floor((y + self.scrollbar.Scroll) / settings.font_size) + 1, 1, self.content_data:GetLineCount())
	surface.SetFont("syper_syntax_1")
	local w = surface.GetTextSize(" ")
	x = renderToRealPos(self.content_data:GetLineStr(y), math.floor((x - self.gutter_size + w / 2) / w) + 1)
	
	return x, y
end

function Editor:AddCaret(x, y)
	self.carets[#self.carets + 1] = {
		x = x,
		y = y,
		max_x = x,
		select_x = nil,
		select_y = nil,
		new = true
	}
	
	self:MarkClearExcessCarets()
	
	table.sort(self.carets, function(a, b)
		return a.y > b.y or (a.y == b.y and a.x > b.x)
	end)
	
	for caret_id, caret in ipairs(self.carets) do
		if caret.new then
			caret.new = nil
			return caret_id
		end
	end
end

function Editor:SetCaret(i, x, y)
	local caret = self.carets[i]
	
	x = x or caret.x
	y = y or caret.y
	
	caret.x = x
	caret.y = y
	caret.max_x = x
	
	self.caretblink = RealTime()
	self:MarkClearExcessCarets()
end

function Editor:MoveCaret(i, x, y)
	local lines = self.content_data.lines
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
	
	self.caretblink = RealTime()
	self:MarkClearExcessCarets()
end

function Editor:InsertStr(str)
	for _, caret in ipairs(self.carets) do
		self:InsertStrAt(caret.x, caret.y, str, true)
	end
	
	self:PushHistoryBlock()
	self:Rebuild()
end

function Editor:InsertStrAt(x, y, str, do_history)
	if not self.editable then return end
	
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
	
	local cd = self.content_data
	if line_count == 0 then
		cd:InsertIntoLine(y, lines[1], x)
	else
		local o = cd:GetLineStr(y)
		cd:ModifyLine(y, sub(o, 1, x - 1) .. lines[1])
		for y2 = y + 1, y + line_count - 1 do
			cd:InsertLine(y2, lines[y2 - y + 1])
		end
		cd:InsertLine(y + line_count, lines[line_count + 1] .. sub(o, x))
	end
	
	local length = len(str)
	for caret_id, caret in ipairs(self.carets) do
		if caret.y == y and caret.x >= x then
			self:MoveCaret(caret_id, length, nil)
		elseif caret.y > y and line_count > 0 then
			self:MoveCaret(caret_id, nil, line_count)
		end
	end
	
	self:MarkClearExcessCarets()
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
	local cs = self.content_data.lines
	for caret_id, caret in ipairs(self.carets) do
		if caret.select_x then
			local sx, sy = caret.x, caret.y
			local ex, ey = caret.select_x, caret.select_y
			
			if ey < sy or (ex < sx and sy == ey) then
				sx, sy, ex, ey = ex, ey, sx, sy
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
	if not self.editable then return end
	
	local cd = self.content_data
	local rem = {}
	local length_org = length
	local line_count = 0
	local ex, ey = x, y
	length = math.abs(length)
	
	if length_org < 0 then
		for _ = 1, length do
			x = x - 1
			if x < 1 then
				if y == 1 then
					length = length - 1
				else
					y = y - 1
					x = cd:GetLineLength(y)
					line_count = line_count + 1
				end
			end
		end
	else
		local c = cd:GetLineCount()
		for _ = 1, length do
			ex = ex + 1
			if ex > cd:GetLineLength(ey) then
				if ey ~= c then
					ey = ey + 1
					ex = 1
					line_count = line_count + 1
				end
			end
		end
	end
	
	for caret_id, caret in ipairs(self.carets) do
		if (caret.x > x and caret.y == y) or caret.y > y then
			if caret.y == y then
				self:MoveCaret(caret_id, -math.min(caret.x - x, length), nil)
			elseif caret.y <= ey then
				self:MoveCaret(caret_id, -length, nil)
			elseif caret.y > ey and line_count > 0 then
				self:MoveCaret(caret_id, nil, -line_count)
			end
		end
	end
	
	self:MarkClearExcessCarets()
	
	local i = 0
	while length > 0 do
		if not cd:LineExists(y) then break end
		
		local org = cd:GetLineLength(y)
		rem[#rem + 1] = sub(cd:GetLineStr(y), x, x + length - 1)
		cd:RemoveFromLine(y, length, x)
		local len = cd:GetLineLength(y)
		length = length - (org - len)
		if len == x - 1 then
			if cd:GetLineCount() == 1 then
				if cd:GetLineLength(1) == 0 then
					cd:ModifyLine(1, "\n")
				end
				
				break
			end
			
			if cd:LineExists(y + 1) then
				cd:AppendToLine(y, cd:GetLineStr(y + 1))
				cd:RemoveLine(y + 1)
			end
		end
		
		i = i + 1
		if i == 4096 then print("!!! Syper: Editor:RemoveStrAt") break end
	end
	
	rem = table.concat(rem, "")
	length = math.abs(length_org) - length
	
	if do_history then
		self:AddHistory({Editor.InsertStrAt, Editor.RemoveStrAt, x, y, rem, length})
	end
	
	return length, x, y, rem
end

function Editor:SetContent(str)
	local lines, p = {}, 1
	while true do
		local s = string.find(str, "\n", p)
		lines[#lines + 1] = string.sub(str, p, s)
		if not s then break end
		p = s + 1
	end
	
	self.content_data = Lexer.createContentTable(self.lexer, self.mode)
	for y, str in ipairs(lines) do
		self.content_data:ModifyLine(y, str)
	end
	self.content_data:AppendToLine(#lines, "\n")
	
	self:Rebuild()
	self:MarkClearExcessCarets()
end

vgui.Register("SyperEditor", Editor, "SyperBaseTextEntry")
