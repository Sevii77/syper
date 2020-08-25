local TOKEN = Syper.TOKEN
local ignore = {"mcomment", "mstring", "string"}

return {
	indent = {
		{"function", ignore},
		{"then", ignore},
		{"elseif", ignore},
		{"else", ignore},
		{"do", ignore},
		{"repeat", ignore},
		{"{", ignore},
		{"%(", ignore},
	},
	
	outdent = {
		{"elseif", ignore},
		{"else", ignore},
		{"end", ignore},
		{"}", ignore},
		{"%)", ignore},
	},
	
	open = {
		["function"] = {"end"},
		["then"] = {"elseif", "else", "end"},
		["elseif"] = {"elseif", "else", "end"},
		["else"] = {"end"},
		["do"] = {"end"},
		["repeat"] = {"until"},
		["{"] = {"}"},
		["%("] = {"%)"},
		["%["] = {"%]"},
		["%[(=*)%["] = {"%]<CAP>%]"},
	},
	
	bracket = {
		["{"] = {"}", ignore},
		["("] = {")", ignore},
		["["] = {"]", ignore},
		["'"] = {"'", ignore, {"\\"}},
		["\""] = {"\"", ignore, {"\\"}},
	}
}
