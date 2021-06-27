do
	local add = Syper.include
	
	add("scrollbar_h.lua", true)
	
	add("base.lua", true)
	add("base_textentry.lua", true)
	add("divider_h.lua", true)
	add("divider_v.lua", true)
	add("textentry.lua", true)
	add("button.lua", true)
	add("tabhandler.lua", true)
	add("tree.lua", true)
	add("editor.lua", true)
	add("html.lua", true)
	add("browser.lua", true)
end

if SERVER then return end

local Settings = Syper.Settings
local settings = Settings.settings
local FT = Syper.FILETYPE

----------------------------------------

local Act = {}

function Act.save(self, force_browser)
	local panel = vgui.GetKeyboardFocus()
	if not panel or not IsValid(panel) or panel.ClassName ~= "SyperEditor" then return end
	
	self:Save(panel, force_browser)
end

function Act.command_overlay(self, str)
	if self.command_overlay then
		self.command_overlay:Remove()
		self.command_overlay = nil
		self.command_overlay_tab:RequestFocus()
		
		return
	end
	
	local tab = vgui.GetKeyboardFocus()
	self.command_overlay_tab = tab
	local cmd = self:Add("DTextEntry")
	cmd:SetHeight(30)
	cmd:Dock(BOTTOM)
	cmd:SetZPos(100)
	cmd:SetText(str)
	cmd:SetCaretPos(#str)
	cmd:RequestFocus()
	cmd.OnKeyCodeTyped = function(_, key)
		if key == KEY_ENTER then
			cmd:Remove()
			self.command_overlay = nil
			
			local str = cmd:GetText()
			local c = string.sub(str, 1, 1)
			str = string.sub(str, 2)
			if c == ":" then
				local num = tonumber(string.match(str, "(%-?%d+)"))
				if num then
					tab.Act.goto_line(tab, num)
				end
			end
			
			tab:RequestFocus()
		end
		
		return self:OnKeyCodeTyped(key)
	end
	self.command_overlay = cmd
end

function Act.focus(self, typ, index)
	local panel = vgui.GetKeyboardFocus()
	if not panel.SyperBase then return end
	
	if typ == "prev" then
		local panel = vgui.GetKeyboardFocus()
		if not panel.SyperBase then return end
		panel:FocusPrevious()
	elseif typ == "next" then
		local panel = vgui.GetKeyboardFocus()
		if not panel.SyperBase then return end
		panel:FocusNext()
	elseif typ == "tab" then
		local th = panel:FindTabHandler()
		if index < 1 or index > th:GetTabCount() then return end
		th:SetActive(index)
	end
end

----------------------------------------

local DFrame
local IDE = {Act = Act}

function IDE:Init()
	DFrame = DFrame or vgui.GetControlTable("DFrame")
	
	self.last_save = CurTime()
	
	self:SetSizable(true)
	self:SetTitle("Syper")
	self:SetMinWidth(640)
	self:SetMinWidth(480)
	
	do
		self.bar = self:Add("DMenuBar")
		self.bar:Dock(TOP)
		
		local file = self.bar:AddMenu("File")
		do
			file:AddOption("New File", function()
				local editor = self:Add("SyperEditor")
				editor:SetSyntax("text")
				editor:SetContent("")
				self:AddTab(nil, editor)
			end)
			file:AddOption("Open File", function()
				local browser = vgui.Create("SyperBrowser")
				local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
				browser:SetPos(x - 240, y - 180)
				browser:SetSize(480, 360)
				browser:MakePopup()
				browser.allow_folders = false
				browser:ModeOpen()
				browser:SetPath("/")
				browser.OnConfirm = function(_, path)
					local editor = self:Add("SyperEditor")
					editor:SetSyntax(Syper.SyntaxFromPath(path))
					editor:SetPath(path)
					editor:ReloadFile()
					self:AddTab(string.match(path, "([^/]*)$"), editor)
				end
			end)
			file:AddOption("Open Folder", function()
				local browser = vgui.Create("SyperBrowser")
				local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
				browser:SetPos(x - 240, y - 180)
				browser:SetSize(480, 360)
				browser:MakePopup()
				browser.allow_files = false
				browser:ModeOpen()
				browser:SetPath("/")
				browser.OnConfirm = function(_, path)
					self.filetree:AddDirectory(path)
					self.filetree:InvalidateLayout()
				end
			end)
			file:AddOption("Open GitHub", function()
				self:TextEntry("Enter GitHub Link", "", function(path)
					self.filetree:AddDirectory(path, "GITHUB")
					self.filetree:InvalidateLayout()
				end, function(path)
					return string.find(path, "github%.com/([^/]+)/([^/]+)")
				end)
			end)
		end
		
		local config = self.bar:AddMenu("Config")
		do
			config:AddOption("Keybinds", function()
				local def = self:Add("SyperEditor")
				def:SetSyntax("json")
				def:SetContent(include("syper/default_binds.lua"))
				def:SetEditable(false)
				
				local conf = self:Add("SyperEditor")
				conf:SetSyntax("json")
				conf:SetPath("syper/keybinds.json")
				conf:ReloadFile()
				
				local div = self:Add("SyperHDivider")
				div:SetLeft(def)
				div:SetRight(conf)
				self:AddTab("Keybinds", div)
				div:CenterDiv()
			end)
			config:AddOption("Settings", function()
				local def = self:Add("SyperEditor")
				def:SetSyntax("json")
				def:SetContent(include("syper/default_settings.lua"))
				def:SetEditable(false)
				
				local conf = self:Add("SyperEditor")
				conf:SetSyntax("json")
				conf:SetPath("syper/settings.json")
				conf:ReloadFile()
				
				local div = self:Add("SyperHDivider")
				div:SetLeft(def)
				div:SetRight(conf)
				self:AddTab("Settings", div)
				div:CenterDiv()
			end)
		end
	end
	
	do
		self.tabhandler = self:Add("SyperTabHandler")
	end
	
	do
		self.filetree = self:Add("SyperTree")
		self.filetree.OnNodePress = function(_, node)
			local tabhandler = self:GetActiveTabHandler()
			for i, tab in ipairs(tabhandler.tabs) do
				if tab.panel.path == node.path then
					tabhandler:SetActive(i)
					
					return
				end
			end
			
			local typ = Syper.FILEEXTTYPE[Syper.getExtension(node.path)]
			if not typ or typ == FT.Generic or typ == FT.Code then
				local editor = self:Add("SyperEditor")
				editor:SetSyntax(Syper.SyntaxFromPath(node.path))
				if node.root_path == "GITHUB" then
					editor.loading = true
					Syper.fetchGitHubFile(node.path, function(content)
						editor.loading = false
						editor:SetContent(content)
					end)
				else
					editor:SetPath(node.path, node.root_path)
					editor:ReloadFile()
				end
				self:AddTab(node.name, editor)
			elseif typ == FT.Image then
				local viewer = self:Add("SyperHTML")
				viewer:OpenImg(node.root_path == "GITHUB" and Syper.getGitHubRaw(node.path) or node.path)
				self:AddTab(node.name, viewer)
			elseif typ == FT.Video then
				local viewer = self:Add("SyperHTML")
				viewer:OpenVideo(node.root_path == "GITHUB" and Syper.getGitHubRaw(node.path) or node.path)
				self:AddTab(node.name, viewer)
			elseif typ == FT.Audio then
				local viewer = self:Add("SyperHTML")
				viewer:OpenAudio(node.root_path == "GITHUB" and Syper.getGitHubRaw(node.path) or node.path)
				self:AddTab(node.name, viewer)
			end
		end
	end
	
	self.filetree_div = self:Add("SyperHDivider")
	self.filetree_div:Dock(FILL)
	self.filetree_div:StickLeft()
	self.filetree_div:SetLeft(self.filetree)
	self.filetree_div:SetRight(self.tabhandler)
end

function IDE:Paint(w, h)
	local time = CurTime()
	if self.save_session_time and (self.save_session_time < time or self.last_save < time - 300) then
		Settings.saveSession(self)
		
		self.save_session_time = nil
		self.last_save = time
	end
	
	surface.SetDrawColor(settings.style_data.ide_ui)
	surface.DrawRect(0, 0, w, h)
	
	return true
end

function IDE:OnKeyCodeTyped(key)
	local bind = Settings.lookupBind(
		input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL),
		input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT),
		input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT),
		key
	)
	
	if bind then
		local act = self.Act[bind.act]
		if act then
			act(self, unpack(bind.args or {}))
			
			return true
		end
	end
end

function IDE:OnMousePressed(key)
	local bind = Settings.lookupBind(
		input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL),
		input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT),
		input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT),
		key
	)
	
	if bind then
		local act = self.Act[bind.act]
		if act then
			act(self, unpack(bind.args or {}))
			
			return true
		end
	end
	
	DFrame.OnMousePressed(self, key)
end

function IDE:GetActiveTabHandler()
	return self.tabhandler
end

function IDE:AddTab(name, panel)
	local tabhandler = self:GetActiveTabHandler()
	tabhandler:AddTab(name or "untitled", panel, tabhandler:GetActive() + 1)
	
	if panel.SetName then
		panel:SetName(name)
		panel.OnNameChange = function(_, name)
			tabhandler:RenameTab(tabhandler:GetIndex(panel), name)
		end
	end
	
	self.filetree:Select((panel.root_path and panel.path) and self.filetree.nodes_lookup[panel.root_path] and self.filetree.nodes_lookup[panel.root_path][panel.path], true)
end

function IDE:Save(panel, force_browser)
	local function browser(relative_path)
		local save_panel = vgui.Create("SyperBrowser")
		local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
		save_panel:SetPos(x - 240, y - 180)
		save_panel:SetSize(480, 360)
		save_panel:MakePopup()
		
		if relative_path then
			save_panel:SetPath(panel.path)
		else
			save_panel:SetPath("/")
		end
		
		save_panel.OnConfirm = function(_, path)
			local selected = panel.root_path and panel.path and self.filetree.nodes_lookup[panel.root_path][panel.path]
			panel:SetPath(path)
			local th = self:GetActiveTabHandler()
			th:RenameTab(th:GetIndex(panel), string.match(path, "([^/]+)/?$"))
			print(panel:Save())
			
			self.filetree:Refresh(panel.path, panel.root_path)
			if selected and selected.selected then
				self.filetree:Select(self.filetree.nodes_lookup[panel.root_path][panel.path], true)
			end
		end
	end
	
	if force_browser then
		browser(panel.root_path == "DATA" and panel.path)
		
		return
	end
	
	local saved, err = panel:Save()
	if not saved then
		browser(err == 4)
	else
		self.filetree:Refresh(panel.path, panel.root_path)
		
		if panel.root_path == "DATA" then
			if panel.path == "syper/keybinds.json" then
				Settings.loadBinds()
			elseif panel.path == "syper/settings.json" then
				Settings.loadSettings()
			end
		end
	end
end

function IDE:Delete(path)
	local single = type(path) == "string"
	local paths = single and {path} or path
	
	self:ConfirmPanel("Are you sure you want to delete\n" .. table.concat(paths, "\n"), function() end, function()
		local function deldir(path)
			path = string.sub(path, -1, -1) == "/" and path or path .. "/"
			path = string.sub(path, 1, 1) == "/" and string.sub(path, 2) or path
			
			local files, dirs = file.Find(path .. "*", "DATA")
			for _, name in ipairs(files) do
				-- print("del file " .. path .. name)
				file.Delete(path .. name)
			end
			
			for _, name in ipairs(dirs) do
				-- print("del dir " .. path .. name)
				deldir(path .. name)
			end
			
			file.Delete(path)
		end
		
		for _, path in ipairs(paths) do
			if file.IsDir(path, "DATA") then
				deldir(path)
			else
				file.Delete(path)
			end
			
			self.filetree:Refresh(path, "DATA")
		end
	end)
end

function IDE:TextEntry(title, text, on_confirm, allow)
	local frame = vgui.Create("DFrame")
	local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
	frame:SetPos(x - 180, y - 27)
	frame:SetSize(360, 54)
	frame:SetTitle(title)
	frame.Paint = function(_, w, h)
		surface.SetDrawColor(settings.style_data.ide_ui)
		surface.DrawRect(0, 0, w, h)
		
		return true
	end
	
	frame.confirm = frame:Add("SyperButton")
	frame.confirm:SetWide(80)
	frame.confirm:Dock(RIGHT)
	frame.confirm:SetText("Confirm")
	frame.confirm:SetFont("syper_ide")
	frame.confirm:SetDoubleClickingEnabled(false)
	frame.confirm:SetEnabled(allow(text))
	frame.confirm.DoClick = function(self)
		frame:Remove()
		
		on_confirm(frame.entry:GetText())
	end
	
	frame.entry = frame:Add("SyperTextEntry")
	frame.entry:Dock(FILL)
	frame.entry:SetFont("syper_ide")
	frame.entry:SetText(text)
	frame.entry:SelectAllOnFocus()
	frame.entry.OnChange = function(self)
		frame.confirm:SetEnabled(allow(self:GetText()))
	end
	
	frame:MakePopup()
	frame.entry:RequestFocus()
end

function IDE:Rename(path)
	local name = string.match(path, "([^/]+)/?$")
	path = string.sub(path, 1, string.match(path, "()[^/]*/?$") - 1)
	
	local isdir = file.IsDir(path, "DATA")
	local allow = isdir and (function(text)
		return #text > 0 and not file.Exists(path .. text, "DATA")
	end) or (function(text)
		return Syper.validFileName(text)
	end)
	
	self:TextEntry("Rename", name, function(nname)
		local tab
		local tabhandler = self:GetActiveTabHandler()
		for i, t in ipairs(tabhandler.tabs) do
			if t.panel.path == path .. name then
				tab = t
				
				break
			end
		end
		
		file.Rename(path .. name, path .. nname)
		local node = self.filetree.nodes_lookup.DATA[path .. name] or self.filetree.nodes_lookup.DATA[path .. name .. "/"]
		if node.main_directory then
			self.filetree.nodes_lookup.DATA[path .. name .. "/"] = nil
			self.filetree.nodes_lookup.DATA[path .. nname .. "/"] = node
			node.name = nname
			node.path = path .. nname .. "/"
			
			self.filetree:Refresh()
		else
			self.filetree:Refresh(path, "DATA")
			if not isdir then
				if node.selected then
					self.filetree:Select(node, true)
				end
			end
		end
		
		if tab then
			tab.name = nname
			tab.tab.name = nname
			tab.panel:SetPath(path .. nname)
		end
	end, allow)
end

function IDE:ConfirmPanel(text, cancel_func, confirm_func)
	surface.SetFont("syper_ide")
	local tw, th = surface.GetTextSize(text)
	
	local frame = vgui.Create("DFrame")
	local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
	frame:SetPos(x - 180, y - 27)
	frame:SetSize(360, 74 + th)
	frame:SetTitle("Are you sure?")
	frame.Paint = function(_, w, h)
		surface.SetDrawColor(settings.style_data.ide_ui)
		surface.DrawRect(0, 0, w, h)
		
		draw.DrawText(text, "syper_ide", w / 2, 29, settings.style_data.ide_foreground, 1)
		
		return true
	end
	
	frame.cancel = frame:Add("SyperButton")
	frame.cancel:SetPos(5, 39 + th)
	frame.cancel:SetSize(175, 30)
	frame.cancel:SetText("Cancel")
	frame.cancel:SetFont("syper_ide")
	frame.cancel.DoClick = function()
		frame:Remove()
		
		cancel_func()
	end
	
	frame.confirm = frame:Add("SyperButton")
	frame.confirm:SetPos(180, 39 + th)
	frame.confirm:SetSize(175, 30)
	frame.confirm:SetText("Confirm")
	frame.confirm:SetFont("syper_ide")
	frame.confirm.DoClick = function()
		frame:Remove()
		
		confirm_func()
	end
	
	frame:MakePopup()
end

function IDE:SaveSession()
	self.save_session_time = CurTime() + 1
end

vgui.Register("SyperIDE", IDE, "DFrame")

----------------------------------------

function Syper.OpenIDE()
	if IsValid(Syper.IDE) then
		Syper.IDE:Show()
		
		return
	end
	
	local ide = vgui.Create("SyperIDE")
	ide:SetDeleteOnClose(false)
	ide:MakePopup()
	
	Syper.IDE = ide
	
	Settings.loadSession(ide)
end
