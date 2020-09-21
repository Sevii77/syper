local TOKEN = Syper.TOKEN
local ignore = {"mcomment", "mstring", "string"}

return {
	indent = {
		{"function", ignore},
		{"then", ignore},
		{"else", ignore},
		{"do", ignore},
		{"repeat", ignore},
		{"{", ignore},
		{"(", ignore},
	},
	
	outdent = {
		{"elseif", ignore},
		{"else", ignore},
		{"end", ignore},
		{"until", ignore},
		{"}", ignore},
		{")", ignore},
	},
	
	pair = {
		["function"] = {
			token = TOKEN.Keyword_Modifier,
			open = {"function", "then", "else", "do"}
		},
		
		["then"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		
		["else"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		
		["do"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		
		["repeat"] = {
			token = TOKEN.Keyword,
			open = {"repeat"}
		},
		
		["{"] = {
			token = TOKEN.Punctuation,
			open = {"{"}
		},
		
		["("] = {
			token = TOKEN.Punctuation,
			open = {"("}
		},
		
		["["] = {
			token = TOKEN.Punctuation,
			open = {"["}
		},
	},
	
	pair2 = {
		["elseif"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		
		["else"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		
		["end"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		
		["until"] = {
			token = TOKEN.Keyword,
			open = {"repeat"}
		},
		
		["}"] = {
			token = TOKEN.Punctuation,
			open = {"{"}
		},
		
		[")"] = {
			token = TOKEN.Punctuation,
			open = {"("}
		},
		
		["]"] = {
			token = TOKEN.Punctuation,
			open = {"["}
		},
	},
	
	bracket = {
		["{"] = {"}", ignore},
		["("] = {")", ignore},
		["["] = {"]", ignore},
		["'"] = {"'", ignore, {"\\"}},
		["\""] = {"\"", ignore, {"\\"}},
	},
	
	comment = "-- ",
}
