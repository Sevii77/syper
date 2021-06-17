local settings = Syper.Settings.settings

----------------------------------------

local Tab = {}

function Tab:Init()
	self.handler = nil
	self.name = nil
	self.panel = nil
	self.active = false
end

function Tab:Setup(handler, name, panel)
	self.handler = handler
	self.name = name
	self.panel = panel
	self.width = handler.tab_size
end

function Tab:OnMousePressed(key)
	if key == MOUSE_LEFT then
		self.handler:SetActivePanel(self.panel)
		
		if self.handler.OnTabPress then
			self.handler:OnTabPress(self)
		end
		
		self.handler.holding = self
		self.handler.hold_offset = self:LocalCursorPos()
		self:MouseCapture(true)
		self:SetZPos(1001)
	elseif key == MOUSE_RIGHT then
		-- TODO: make close check if it should prompt save first
		-- TODO: make not look shit
		local menu = DermaMenu()
		menu:AddOption("Close", function()
			self.handler:RemoveTab(self.handler:GetIndex(self.panel))
		end)
		menu:AddOption("Close Others", function()
			local s = self.handler:GetIndex(self.panel) + 1
			for _ = s, #self.handler.tabs do
				self.handler:RemoveTab(s)
			end
			
			for _ = 1, #self.handler.tabs - 1 do
				self.handler:RemoveTab(1)
			end
		end)
		menu:AddOption("Close To Right", function()
			local s = self.handler:GetIndex(self.panel) + 1
			for _ = s, #self.handler.tabs do
				self.handler:RemoveTab(s)
			end
		end)
		menu:AddOption("Close To Left", function()
			for _ = 1, self.handler:GetIndex(self.panel) - 1 do
				self.handler:RemoveTab(1)
			end
		end)
		menu:Open()
	end
end

function Tab:OnMouseReleased(key)
	if key == MOUSE_LEFT then
		self.handler.holding = nil
		self:MouseCapture(false)
		
		local cur = self.handler:GetIndex(self.panel)
		for i, tab in ipairs(self.handler.tabs) do
			if tab.tab:GetX() > self:GetX() then
				if cur == i then
					self.handler:InvalidateLayout()
					
					return
				end
				
				self.handler:MoveTab(cur, i)
				
				return
			end
		end
		
		self.handler:MoveTab(cur, #self.handler.tabs + 1)
	end
end

function Tab:OnMouseWheeled(delta)
	self.handler.scroll = self.handler.scroll - delta * self.handler.scroll_mul
	self.handler:InvalidateLayout()
end

function Tab:Paint(w, h)
	if self.active then
		draw.NoTexture()
		surface.SetDrawColor(settings.style_data.gutter_background)
		surface.DrawPoly({
			{x = 0, y = h},
			{x = 5, y = 0},
			{x = w - 5, y = 0},
			{x = w, y = h},
		})
		
		surface.SetTextColor(settings.style_data.ide_foreground)
	else
		surface.SetDrawColor(settings.style_data.ide_background)
		surface.DrawRect(0, 0, w, h)
		
		local prev = self.handler.tabs[self.handler.active_tab - 1]
		if prev and prev.tab ~= self then
			surface.SetDrawColor(settings.style_data.gutter_background)
			surface.DrawRect(w - 1, 3, 1, h - 6)
		end
		
		surface.SetTextColor(settings.style_data.ide_disabled)
	end
	
	surface.SetFont(self.handler.tab_font)
	local tw, th = surface.GetTextSize(self.name)
	local o = (h - th) / 2
	surface.SetTextPos(5 + o, o)
	surface.DrawText(self.name)
	
	local dw = math.max(self.handler.tab_size, tw + 10 + o * 2)
	if self.width ~= dw then
		self.width = dw
		self:InvalidateParent()
	end
end

function Tab:SetActive(state)
	self.active = state
end

vgui.Register("SyperTab", Tab, "Panel")

----------------------------------------

local TabHandler = {}

function TabHandler:Init()
	self.bar_size = 25
	
	self.tab_size = 100
	self.tab_font = "syper_ide"
	
	self.scroll_mul = 20
	self.scroll = 0
	
	self.active_tab = 0
	self.tabs = {}
end

function TabHandler:Paint(w, h)
	surface.SetDrawColor(settings.style_data.ide_background)
	surface.DrawRect(0, 0, w, self.bar_size - 4)
	
	surface.SetDrawColor(settings.style_data.gutter_background)
	surface.DrawRect(0, self.bar_size - 4, w, 4)
	
	surface.SetDrawColor(settings.style_data.background)
	surface.DrawRect(0, self.bar_size, w, h - self.bar_size)
end

function TabHandler:Think()
	if not self.holding then return end
	
	local x = self:LocalCursorPos()
	self.holding:SetPos(x - self.hold_offset, 0)
end

function TabHandler:ScrollBounds(w)
	-- local max = #self.tabs * self.tab_size - w
	local max = -w
	for i, tab in ipairs(self.tabs) do
		max = max + tab.tab.width
	end
	
	self.scroll = math.Clamp(self.scroll, 0, math.max(0, max))
end

function TabHandler:PerformLayout(w, h)
	if self.holding then return end
	
	self:ScrollBounds(w)
	
	local offset = 0
	for i, tab in ipairs(self.tabs) do
		local x = math.Clamp(offset - self.scroll, 0, w - tab.tab.width)
		tab.tab:SetPos(x, 0)
		tab.tab:SetSize(tab.tab.width, self.bar_size - 4)
		tab.tab:SetZPos(tab.tab.active and 1000 or -math.abs(w / 2 - (offset - self.scroll) + tab.tab.width / 2))
		
		offset = offset + tab.tab.width
	end
	
	self:PerformLayoutTab(self:GetActivePanel(), w, h)
end

function TabHandler:PerformLayoutTab(tab, w, h)
	if not tab then return end
	
	tab.panel:SetPos(0, self.bar_size)
	tab.panel:SetSize(w, h - self.bar_size)
	tab.panel:InvalidateLayout()
end

function TabHandler:FocusPreviousChild(cur_focus)
	local allow = cur_focus == nil and true or false
	for i = #self.tabs, 1, -1 do
		local tab = self.tabs[i]
		if tab.panel == cur_focus then
			allow = true
		elseif allow then
			self:SetActivePanel(tab.panel)
			return tab.panel
		end
	end
end

function TabHandler:FocusNextChild(cur_focus)
	local allow = cur_focus == nil and true or false
	for i = 1, #self.tabs do
		local tab = self.tabs[i]
		if tab.panel == cur_focus then
			allow = true
		elseif allow then
			self:SetActivePanel(tab.panel)
			return tab.panel
		end
	end
end

function TabHandler:AddTab(name, panel, index, dont_active)
	local tab = self:Add("SyperTab")
	tab:Setup(self, name, panel)
	if index then
		index = math.Clamp(index, 1, #self.tabs + 1)
	else
		index = #self.tabs + 1
	end
	
	panel:SetParent(self)
	
	table.insert(self.tabs, index, {
		name = name,
		tab = tab,
		panel = panel
	})
	
	if not dont_active then
		self:SetActive(index)
	end
	
	Syper.IDE:SaveSession()
	
	return self.tabs[index]
end

function TabHandler:RemoveTab(index, keep_panel)
	local tab = self.tabs[index]
	tab.tab:Remove()
	
	if not keep_panel then
		tab.panel:Remove()
	end
	
	table.remove(self.tabs, index)
	
	if tab.tab.active then
		self:SetActive(math.max(1, index - 1))
		
		if self.OnTabPress then
			self:OnTabPress(self.tabs[self.active_tab])
		end
	end
	
	Syper.IDE:SaveSession()
end

function TabHandler:RenameTab(index, name)
	self.tabs[index].name = name
	self.tabs[index].tab.name = name
	Syper.IDE:SaveSession()
end

function TabHandler:MoveTab(old, new)
	local t = self.tabs[old]
	table.insert(self.tabs, new, t)
	table.remove(self.tabs, old + (old > new and 1 or 0))
	
	self:InvalidateLayout()
	Syper.IDE:SaveSession()
end

function TabHandler:GetIndex(panel)
	for i, tab in ipairs(self.tabs) do
		if tab.panel == panel then
			return i
		end
	end
end

function TabHandler:SetActive(index)
	self.active_tab = index
	for i, tab in ipairs(self.tabs) do
		if i == index then
			tab.panel:SetVisible(true)
			tab.panel:RequestFocus()
			tab.tab:SetActive(true)
		else
			tab.panel:SetVisible(false)
			tab.tab:SetActive(false)
		end
	end
	
	self:InvalidateLayout()
	Syper.IDE:SaveSession()
end

function TabHandler:GetActive()
	return self.active_tab
end

function TabHandler:SetActivePanel(panel)
	for i, tab in ipairs(self.tabs) do
		if tab.panel == panel then
			tab.panel:SetVisible(true)
			tab.panel:RequestFocus()
			tab.tab:SetActive(true)
			self.active_tab = i
		else
			tab.panel:SetVisible(false)
			tab.tab:SetActive(false)
		end
	end
	
	self:InvalidateLayout()
	Syper.IDE:SaveSession()
end

function TabHandler:GetActivePanel()
	return self.tabs[self.active_tab]
end

function TabHandler:GetTabCount()
	return #self.tabs
end

function TabHandler:SetBarSize(size)
	self.bar_size = size
	self:InvalidateLayout()
end

function TabHandler:SetTabSize(size)
	self.tab_size = size
	self:InvalidateLayout()
end

vgui.Register("SyperTabHandler", TabHandler, "Panel")