-- TODO: make look nice
-- TODO: refresh filetree on save
-- TODO: make tab closing use this

local settings = Syper.Settings.settings

----------------------------------------

local Browser = {}

function Browser:Init()
	self.path = "/"
	self.mode_save = true
	self.allow_folders = true
	self.allow_files = true
	
	self.top = self:Add("Panel")
	self.top:SetHeight(20)
	self.top:Dock(TOP)
	
	self.moveup = self.top:Add("DButton")
	self.moveup:SetWide(20)
	self.moveup:Dock(RIGHT)
	self.moveup:SetText("^")
	self.moveup.DoClick = function()
		if self.path == "/" then return end
		
		self:SetPath(string.sub(self.path_entry:GetText(), 1, string.match(self.path_entry:GetText(), "()[^/]+/$") - 1))
	end
	
	self.path_entry = self.top:Add("DTextEntry")
	self.path_entry:Dock(FILL)
	self.path_entry.OnEnter = function(_, path)
		if not file.Exists(path, "DATA") then
			_:SetText(self.path)
		elseif file.IsDir(path, "DATA") then
			self:SetPath(path)
		else
			self:SetPath(string.sub(path, 1, string.match(path, "()[^/]+/$") - 1))
		end
	end
	
	
	self.bottom = self:Add("Panel")
	self.bottom:SetHeight(20)
	self.bottom:Dock(BOTTOM)
	
	self.confirm = self.bottom:Add("DButton")
	self.confirm:SetWide(80)
	self.confirm:Dock(RIGHT)
	
	self.cancel = self.bottom:Add("DButton")
	self.cancel:SetWide(80)
	self.cancel:Dock(RIGHT)
	self.cancel:SetText("Cancel")
	self.cancel.DoClick = function()
		self:Remove()
		
		if self.OnCancel then
			self:OnCancel()
		end
	end
	
	self.name_entry = self.bottom:Add("DTextEntry")
	self.name_entry:Dock(FILL)
	self.name_entry.OnTextChanged = function(_)
		self.confirm:SetEnabled(Syper.validFileName(_:GetText()))
	end
	
	self.holder = self:Add("DScrollPanel")
	self.holder:Dock(FILL)
	
	
	self:ModeSave()
end

function Browser:ModeSave()
	self.mode_save = true
	self.name_entry:SetVisible(true)
	self.confirm:SetText("Save")
	self.confirm:SetEnabled(Syper.validFileName(self.name_entry:GetText()))
	self.confirm.DoClick = function()
		self:Remove()
		
		if self.OnConfirm then
			self:OnConfirm(self.path_entry:GetText() .. self.name_entry:GetText())
		end
	end
end

function Browser:ModeOpen()
	self.mode_save = false
	self.name_entry:SetVisible(false)
	self.confirm:SetText("Open")
	self.confirm.DoClick = function()
		self:Remove()
		
		if self.OnConfirm then
			self:OnConfirm(self.path)
		end
	end
end

function Browser:SetPath(path)
	path = string.sub(path, -1, -1) == "/" and path or path .. "/"
	path = string.sub(path, 1, 1) == "/" and string.sub(path, 2) or path
	
	local name
	if not file.IsDir(path, "DATA") then
		local s, n = string.match(path, "/?()([^/]+)/?$")
		path = string.sub(path, 1, s - 1)
		name = n
	end
	
	self.path = path
	self.path_entry:SetText(path)
	
	for _, node in ipairs(self.holder.pnlCanvas:GetChildren()) do
		node:Remove()
	end
	
	local selected = nil
	local files, dirs = file.Find(self.path .. "*", "DATA")
	for _, dir in ipairs(dirs) do
		local node = self.holder.pnlCanvas:Add("DButton")
		node:SetHeight(20)
		node:Dock(TOP)
		node:SetText("[DIR] " .. dir)
		node.DoClick = function(_)
			selected = _
			self.path = path .. dir .. "/"
			if not self.mode_save then
				self.confirm:SetEnabled(self.allow_folders)
			end
		end
		node.DoDoubleClick = function()
			self:SetPath(path .. dir .. "/")
		end
		node.Paint = function(_, w, h)
			if selected == _ then
				surface.SetDrawColor(settings.style_data.gutter_foreground)
				surface.DrawRect(0, 0, w, h)
			end
			
			surface.SetTextColor(selected == _ and settings.style_data.ide_foreground or settings.style_data.ide_disabled)
			surface.SetFont("syper_ide")
			local str = _:GetText()
			local tw, th = surface.GetTextSize(str)
			surface.SetTextPos((h - th) / 2, (h - th) / 2)
			surface.DrawText(str)
			
			return true
		end
	end
	
	for _, file in ipairs(files) do
		local node = self.holder.pnlCanvas:Add("DButton")
		node:SetHeight(20)
		node:Dock(TOP)
		node:SetText("[FILE] " .. file)
		node.DoClick = function(_)
			selected = _
			self.path = path .. file
			self.name_entry:SetText(file)
			self.name_entry:OnTextChanged()
			if not self.mode_save then
				self.confirm:SetEnabled(self.allow_files)
			end
		end
		node.Paint = function(_, w, h)
			if selected == _ then
				surface.SetDrawColor(settings.style_data.gutter_foreground)
				surface.DrawRect(0, 0, w, h)
			end
			
			surface.SetTextColor(selected == _ and settings.style_data.ide_foreground or settings.style_data.ide_disabled)
			surface.SetFont("syper_ide")
			local str = _:GetText()
			local tw, th = surface.GetTextSize(str)
			surface.SetTextPos((h - th) / 2, (h - th) / 2)
			surface.DrawText(str)
			
			return true
		end
		
		if name == file then
			node:DoClick()
		end
	end
end

vgui.Register("SyperBrowser", Browser, "DFrame")
