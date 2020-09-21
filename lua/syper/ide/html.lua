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

function HTML:OpenImg(path)
	self.path = path
	self:SetHTML([[<img src="asset://garrysmod/]] .. path .. [[" style="position:fixed;top:50%;left:50%;transform:translate(-50%,-50%)">]])
end

-- wav seems to be unsupported
function HTML:OpenAudio(path)
	self.path = path
	self:SetHTML([[<audio controls autoplay style="position:fixed;top:50%;left:50%;transform:translate(-50%,-50%)"><source src="asset://garrysmod/]] .. path .. [["></audio>]])
end

-- doesnt seem to work, guess gmod chromium doesnt support the video codecs
function HTML:OpenVideo(path)
	self.path = path
	self:SetHTML([[<video controls autoplay style="position:fixed;top:50%;left:50%;transform:translate(-50%,-50%)"><source src="asset://garrysmod/]] .. path .. [["></video>]])
end

vgui.Register("SyperHTML", HTML, "DHTML")
