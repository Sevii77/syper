local TOKEN = Syper.TOKEN

return {
	indent = {
		{"function", TOKEN.Keyword_Modifier},
		{"then", TOKEN.Keyword},
		{"elseif", TOKEN.Keyword},
		{"else", TOKEN.Keyword},
		{"do", TOKEN.Keyword},
		{"repeat", TOKEN.Keyword},
		{"{", TOKEN.Punctuation},
		{"%(", TOKEN.Punctuation},
	},
	
	outdent = {
		{"elseif", TOKEN.Keyword},
		{"else", TOKEN.Keyword},
		{"end", TOKEN.Keyword},
		{"}", TOKEN.Punctuation},
		{"%)", TOKEN.Punctuation},
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
		["{"] = {"}", {"mcomment", "mstring", "string"}},
		["("] = {")", {"mcomment", "mstring", "string"}},
		["["] = {"]", {"mcomment", "mstring", "string"}},
	}
}
