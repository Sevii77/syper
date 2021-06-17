local settings = Syper.Settings.settings

----------------------------------------

local HTML = {}

for k, v in pairs(vgui.GetControlTable("SyperBase")) do
	HTML[k] = HTML[k] or v
end

function HTML:Init()
	
end

function HTML:Paint(w, h)
	surface.SetDrawColor(settings.style_data.background)
	surface.DrawRect(0, 0, w, h)
end

function HTML:ModPath(path)
	if string.sub(path, 1, 4) == "http" or string.sub(path, 1, 5) == "asset" then
		return path
	end
	
	return "asset://garrysmod/" .. path
end

function HTML:OpenImg(path)
	self.mode = 1
	self.path = self:ModPath(path)
	self:SetHTML([[<img src="]] .. self.path .. [[" style="position:fixed;top:50%;left:50%;transform:translate(-50%,-50%)">]])
end

-- wav seems to be unsupported
function HTML:OpenAudio(path)
	self.mode = 2
	self.path = self:ModPath(path)
	self:SetHTML([[<audio controls autoplay style="position:fixed;top:50%;left:50%;transform:translate(-50%,-50%)"><source src="]] .. path .. [["></audio>]])
end

-- doesnt seem to work, guess gmod chromium doesnt support the video codecs
function HTML:OpenVideo(path)
	self.mode = 3
	self.path = self:ModPath(path)
	self:SetHTML([[<video controls autoplay style="position:fixed;top:50%;left:50%;transform:translate(-50%,-50%)"><source src="]] .. path .. [["></video>]])
end

function HTML:GetSessionState()
	return {
		mode = self.mode,
		path = self.path
	}
end

function HTML:SetSessionState(state)
	if state.mode == 1 then
		self:OpenImg(state.path)
	elseif state.mode == 2 then
		self:OpenAudio(state.path)
	elseif state.mode == 3 then
		self:OpenVideo(state.path)
	end
end

vgui.Register("SyperHTML", HTML, "DHTML")
