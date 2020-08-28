return [=[{
	"ctrl+s": {"act": "save"},
	"ctrl+g": {"act": "command_overlay", "args": [":"]},
	
	"ctrl+z": {"act": "undo"},
	"ctrl+y": {"act": "redo"},
	"ctrl+shift+z": {"act": "redo"},
	
	"ctrl+c": {"act": "copy"},
	"ctrl+x": {"act": "cut"},
	"ctrl+v": {"act": "paste", "_COMMENT_": "this is just a dummy, cant be changed"},
	"ctrl+shift+v": {"act": "pasteindent", "_COMMENT_": "partly a dummy, only does the indenting"},
	
	"enter": {"act": "newline"},
	"tab": {"act": "indent"},
	"shift+tab": {"act": "outdent"},
	"ctrl+/": {"act": "comment"},
	"ctrl+a": {"act": "selectall"},
	
	"mouse_1": {"act": "setcaret"},
	"ctrl+mouse_1": {"act": "setcaret", "args": [true]},
	
	"backspace": {"act": "delete", "args": ["char", -1]},
	"delete": {"act": "delete", "args": ["char", 1]},
	"ctrl+backspace": {"act": "delete", "args": ["word", -1]},
	"ctrl+delete": {"act": "delete", "args": ["word", 1]},
	
	"left": {"act": "move", "args": ["char", -1]},
	"right": {"act": "move", "args": ["char", 1]},
	"shift+left": {"act": "move", "args": ["char", -1, true]},
	"shift+right": {"act": "move", "args": ["char", 1, true]},
	"ctrl+left": {"act": "move", "args": ["word", -1]},
	"ctrl+right": {"act": "move", "args": ["word", 1]},
	"ctrl+shift+left": {"act": "move", "args": ["word", -1, true]},
	"ctrl+shift+right": {"act": "move", "args": ["word", 1, true]},
	
	"up": {"act": "move", "args": ["line", -1]},
	"down": {"act": "move", "args": ["line", 1]},
	"shift+up": {"act": "move", "args": ["line", -1, true]},
	"shift+down": {"act": "move", "args": ["line", 1, true]},
	"ctrl+up": {"act": "move", "args": ["line", -1]},
	"ctrl+down": {"act": "move", "args": ["line", 1]},
	"ctrl+shift+up": {"act": "move", "args": ["line", -1, true]},
	"ctrl+shift+down": {"act": "move", "args": ["line", 1, true]},
	
	"pageup": {"act": "move", "args": ["page", -1]},
	"pagedown": {"act": "move", "args": ["page", 1]},
	"shift+pageup": {"act": "move", "args": ["page", -1, true]},
	"shift+pagedown": {"act": "move", "args": ["page", 1, true]},
	
	"home": {"act": "move", "args": ["bol"]},
	"end": {"act": "move", "args": ["eol"]},
	"shift+home": {"act": "move", "args": ["bol", false, true]},
	"shift+end": {"act": "move", "args": ["eol", false, true]},
	"ctrl+home": {"act": "move", "args": ["bof"]},
	"ctrl+end": {"act": "move", "args": ["eof"]},
	"ctrl+shift+home": {"act": "move", "args": ["bof", false, true]},
	"ctrl+shift+end": {"act": "move", "args": ["eof", false, true]}
}]=]