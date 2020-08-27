local Divider = {}

function Divider:Init()
	self.div_size = 10
	self.div_pos = 0
	self.left = nil
	self.right = nil
	
	self.holding = false
	self.hold_offset = 0
	
	self.stick = 1
	
	self.clr = {r = 0, g = 0, b = 0, a = 255}
	
	self:SetCursor("sizewe")
end

function Divider:Paint(w, h)
	surface.SetDrawColor(self.clr)
	surface.DrawRect(self.div_pos, 0, self.div_size, h)
end

function Divider:PerformLayout(w, h)
	if not self.left then return end
	if not self.right then return end
	
	if self.last_w then
		local div = self.last_w - w
		
		if self.stick == 0 then
			-- nothing, dont move
		elseif self.stick == 1 then
			self.div_pos = self.div_pos - div * (self.left:GetWide() / self.last_w)
		elseif self.stick == 2 then
			self.div_pos = self.div_pos - div
		end
	end
	self.last_w = w
	
	self.left:SetPos(0, 0)
	self.left:SetSize(self.div_pos, h)
	self.left:InvalidateLayout()
	
	self.right:SetPos(self.div_pos + self.div_size, 0)
	self.right:SetSize(w - self.div_pos - self.div_size, h)
	self.right:InvalidateLayout()
end

function Divider:OnCursorMoved(x, y)
	if not self.holding then return end
	
	self.div_pos = x - self.hold_offset
	self:InvalidateLayout()
end

function Divider:OnMousePressed(key)
	if key ~= MOUSE_LEFT then return end
	
	local x = self:LocalCursorPos()
	if x >= self.div_pos and x <= self.div_pos + self.div_size then
		self.holding = true
		self.hold_offset = x - self.div_pos
		self:MouseCapture(true)
	end
end

function Divider:OnMouseReleased(key)
	if key ~= MOUSE_LEFT then return end
	
	self.holding = false
	self:MouseCapture(false)
end

function Divider:SetColor(clr)
	self.clr = clr
end

function Divider:SetLeft(panel)
	self.left = panel
	panel:SetParent(self)
end

function Divider:SetRight(panel)
	self.right = panel
	panel:SetParent(self)
end

function Divider:CenterDiv()
	self:GetParent():InvalidateLayout(true)
	self.div_pos = self:GetWide() / 2 - self.div_size / 2
end

function Divider:SetDivSize(size)
	local dif = size - self.div_size
	self.div_size = size
	self.div_pos = self.div_pos - dif / 2
end

function Divider:StickLeft()
	self.stick = 0
end

function Divider:StickCenter()
	self.stick = 1
end

function Divider:StickRight()
	self.stick = 2
end

vgui.Register("SyperHDivider", Divider, "Panel")