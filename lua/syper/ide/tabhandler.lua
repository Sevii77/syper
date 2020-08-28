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
end

function Tab:OnMousePressed(key)
	if key ~= MOUSE_LEFT then return end
	
	self.handler:SetActivePanel(self.panel)
end

function Tab:OnMouseWheeled(delta)
	self.handler.scroll = self.handler.scroll - delta * self.handler.scroll_mul
	self.handler:InvalidateLayout()
end

function Tab:Paint(w, h)
	if self.active then
		surface.SetDrawColor(self.handler.tab_clr_active)
		surface.DrawRect(0, 0, w, h)
	else
		surface.SetDrawColor(self.handler.tab_clr)
		surface.DrawRect(0, 0, w, h)
		
		surface.SetDrawColor(self.handler.tab_clr_active)
		surface.DrawRect(0, 5, 1, h - 10)
		surface.DrawRect(w - 1, 5, 1, h - 10)
	end
	
	surface.SetTextColor(self.handler.tab_clr_text)
	surface.SetFont(self.handler.tab_font)
	local tw, th = surface.GetTextSize(self.name)
	local o = (h - th) / 2
	surface.SetTextPos(o, o)
	surface.DrawText(self.name)
end

function Tab:SetActive(state)
	self.active = state
end

vgui.Register("SyperTab", Tab, "Panel")

----------------------------------------

local TabHandler = {}

function TabHandler:Init()
	self.bar_size = 25
	self.bar_clr = {r = 0, g = 0, b = 0, a = 255}
	
	self.tab_size = 100
	self.tab_clr = {r = 32, g = 32, b = 32, a = 255}
	self.tab_clr_active = {r = 64, g = 64, b = 64, a = 255}
	self.tab_clr_text = {r = 255, g = 255, b = 255, a = 255}
	self.tab_font = "DermaDefault"
	
	self.scroll_mul = 20
	self.scroll = 0
	
	self.active_tab = 0
	self.tabs = {}
end

function TabHandler:Paint(w, h)
	surface.SetDrawColor(self.bar_clr)
	surface.DrawRect(0, 0, w, self.bar_size - 2)
	
	surface.SetDrawColor(self.tab_clr_active)
	surface.DrawRect(0, self.bar_size - 2, w, 2)
end

function TabHandler:ScrollBounds(w)
	self.scroll = math.Clamp(self.scroll, 0, math.max(0, #self.tabs * self.tab_size - w))
end

function TabHandler:PerformLayout(w, h)
	self:ScrollBounds(w)
	
	for i, tab in ipairs(self.tabs) do
		local x = math.Clamp((i - 1) * self.tab_size - self.scroll, (i - 1) * 3, w - self.tab_size - (#self.tabs - i) * 3)
		tab.tab:SetPos(x, 0)
		tab.tab:SetSize(self.tab_size, self.bar_size - 2)
		tab.tab:SetZPos(-math.abs(w / 2 - (((i - 1) * self.tab_size - self.scroll) + self.tab_size / 2)))
	end
	
	self:PerformLayoutTab(self:GetActivePanel(), w, h)
end

function TabHandler:PerformLayoutTab(tab, w, h)
	if not tab then return end
	
	tab.panel:SetPos(0, self.bar_size)
	tab.panel:SetSize(w, h - self.bar_size)
	tab.panel:InvalidateLayout()
end

function TabHandler:AddTab(name, panel, index)
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
	
	self:SetActive(index)
end

function TabHandler:RemoveTab(index)
	local tab = self.tabs[index]
	tab.tab:Remove()
	tab.panel:Remove()
	
	table.remove(self.tabs, index)
	
	if tab.tab.active then
		self:SetActive(math.max(1, index - 1))
	end
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
			tab.tab:SetActive(true)
		else
			tab.panel:SetVisible(false)
			tab.tab:SetActive(false)
		end
	end
	
	self:InvalidateLayout()
end

function TabHandler:GetActive()
	return self.active_tab
end

function TabHandler:SetActivePanel(panel)
	for i, tab in ipairs(self.tabs) do
		if tab.panel == panel then
			tab.panel:SetVisible(true)
			tab.tab:SetActive(true)
			self.active_tab = i
		else
			tab.panel:SetVisible(false)
			tab.tab:SetActive(false)
		end
	end
	
	self:InvalidateLayout()
end

function TabHandler:GetActivePanel()
	return self.tabs[self.active_tab]
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