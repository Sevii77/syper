local Base = {SyperBase = true, SyperFocusable = true}

function Base:Init()
	
end

function Base:OnFocusChanged(gained)
	if gained then
		local panel = self.refocus_panel
		while panel do
			local npanel = panel.refocus_panel
			if not IsValid(npanel) then
				panel:RequestFocus()
			end
			
			panel = npanel
		end
	else
		self:GetParent().refocus_panel = self
	end
end

function Base:FocusPreviousChild(cur_focus)
	local allow = cur_focus == nil and true or false
	local children = self:GetChildren()
	for i = #children, 1, -1 do
		local panel = children[i]
		if panel == cur_focus then
			allow = true
		elseif allow and panel.SyperFocusable then
			panel.refocus_panel = nil
			panel:RequestFocus()
			
			return panel
		end
	end
end

function Base:FocusPrevious()
	local parent = self:GetParent()
	local new = parent:FocusPreviousChild(self)
	if not new then
		if parent.SyperFocusable then
			-- move up in parent hierarchy
			parent:FocusPrevious()
		else
			-- loop around
			new = parent:FocusPreviousChild()
		end
	end
	
	-- move as far down in parent hierarchy
	while IsValid(new) do
		if not new.SyperFocusable then break end
		
		new.refocus_panel = nil
		new:RequestFocus()
		new = new:FocusPreviousChild()
	end
end

function Base:FocusNextChild(cur_focus)
	local allow = cur_focus == nil and true or false
	local children = self:GetChildren()
	for i = 1, #children do
		local panel = children[i]
		if panel == cur_focus then
			allow = true
		elseif allow and panel.SyperFocusable then
			panel.refocus_panel = nil
			panel:RequestFocus()
			
			return panel
		end
	end
end

function Base:FocusNext()
	local parent = self:GetParent()
	local new = parent:FocusNextChild(self)
	if not new then
		if parent.SyperFocusable then
			-- move up in parent hierarchy
			parent:FocusNext()
		else
			-- loop around
			new = parent:FocusNextChild()
		end
	end
	
	-- move as far down in parent hierarchy
	while IsValid(new) do
		if not new.SyperFocusable then break end
		
		new.refocus_panel = nil
		new:RequestFocus()
		new = new:FocusNextChild()
	end
end

function Base:FindParent(name)
	local p = self:GetParent()
	while IsValid(p) do
		if p:GetName() == name then
			return p
		end
		
		p = p:GetParent()
	end
end

function Base:FindTabHandler()
	return self:FindParent("SyperTabHandler")
end

function Base:FindIDE()
	return self:FindParent("SyperIDE")
end

vgui.Register("SyperBase", Base, "Panel")