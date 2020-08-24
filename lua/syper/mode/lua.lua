return {
	indent = {"function", "then", "elseif", "else", "do", "repeat", "{", "%("},
	outdent = {"elseif", "else", "end", "}", "%)"},
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
		["%[(=*)%["] = {"%]<CAP>%]"}
	},
}
