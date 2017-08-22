socket = require "cqueues.socket"
re = require "re"
moonscript = require "moonscript"

gen_index = (x)-> setmetatable {}, __index: x
clean_table = (tbl)-> tbl[k] = nil for k in pairs tbl

class IRCClient
	handlers: {}
	senders: {}
	hooks: {}
	commands: {}

	default_config = {
		prefix: "!"
	}
	possible_caps = {}

	new: (server, port = 6697, config = default_config)=>
		assert server, "No server given"
		@config =
			host: server
			port: port
			ssl: port == 6697
		for k, v in pairs config
			@config[k] = v
		@data = {}
	
	add_cap: (name)=>
		for cap in possible_caps
			if cap == name
				return
		table.insert possible_caps name
	
	add_command: (name, command)=>
		@commands[name] = command
	
	add_hook: (id, hook)=>
		if not @hooks[id]
			@hooks[id] = {hook}
		else
			table.insert @hooks[id], hook

	add_handler: (id, handler)=>
		if not @handlers[id]
			@handlers[id] = {handler}
		else
			table.insert @handlers[id], handler
	
	add_sender: (id, sender)=>
		assert not @senders[id], "Sender already exists: #{id}"
		@senders[id] = sender
	
	load_modules: (modules)=>
		if modules.commands
			for id, command in pairs modules.commands
				@add_command id, command
		if modules.hooks
			for id, hook in pairs modules.hooks
				@add_hook id, hook
		if modules.handlers
			for id, handler in pairs modules.handlers
				@add_handler id, handler
		if modules.senders
			for id, sender in pairs modules.senders
				@add_sender id, sender
	
	clear_modules: =>
		for t in *{@commands, @handlers, @hooks, @senders, @possible_caps}
			clean_table t
	
	connect: =>
		@socket\shutdown! if @socket
		
		{:host, :port, :ssl} = @config
		@config.nick = "Turbotato" if not @config.nick
		@config.username = "bot" if not @config.username
		@config.realname = "MoonScript IRC Bot" if not @config.realname

		@socket = assert socket.connect(host, port)
		@data.last_connect = os.time!
		if ssl
			@socket\starttls!
			@socket\flush!
		@fire_hook "CONNECT"
		{:nick, :username, :realname, :password} = @config
		@send_raw "NICK %s", nick
		@nick = nick
		@send_raw "PASS :%s", password if password and ssl
		error "Must use TLS with passwords" if password and not ssl
		@send_raw "USER %s * * :%s", username, realname
	
	disconnect: =>
		@send_raw "QUIT"
		@socket\shutdown! if @socket
		@fire_hook "DISCONNECT"
	
	send_raw: (pattern, ...)=>
		input = pattern\format ...
		@debug "=> %s", input
		@socket\write input .. "\n"
	
	date_pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+).(%d+)Z"
	parse_time: (date)=>
		year, month, day, hour, min, sec = date\match @date_pattern
		return :year, :month, :day, :hour, :min, :sec

	line_parser = re.compile [[ -- LPEG-RE
		line <- {| (tags sp)? (prefix sp)? {command / numeric} (sp arg)* |}

		tags <- {:tags: '@' tag (';' tag)* :}
		tag <- {| {:vendor: {[^/]+} '/' :}? {:key: ('=' [^; ]+)? ->
			esc_tag :} |}

		prefix <- ':' (
			{:nick: {[^ !]+} :} '!'
			{:user: {[^ @]+} :} '@'
			{:host: {[^ ]+} :} /
			{:nick: {[^ ]+} :})

		command <- [A-Za-z]+
		numeric <- %d^+3^-4 -- at most four digits, at least three

		arg <- ':' {.+} / {%S+}

		sp <- %s
	]], esc_tag: (tag)-> tag\gsub "\\(.)", setmetatable({
		[":"]: ":"
		s: " "
		r: "\r"
		n: "\n"
	}, __index: (t, k) -> k)

	fire_hook: (name)=>
		return if not @hooks[name]
		errors = {}
		for hook in *@hooks[name]
			ok, err = moonscript.errors.trace_pcall hook, self
			if not ok
				table.insert errors, err
		for err in *errors
			print err
	
	process: (line)=>
		data = line_parser\match line
		errors = {}
		command = table.remove data, 1
		if @handlers[command]
			for handler in *@handlers[command]
				ok, err = moonscript.errors.trace_pcall handler, self, data
				if not ok
					table.insert errors, err
		if next errors
			@log ("\00304errors in process(%q):")\format line
		for err in *errors
			for line in err\gmatch "[^\r\n]+"
				@log "\00304%s", line
	
	loop: =>
		for line in @socket\lines!
			@debug "<= %s", line
			@process line
	
	colors = {
		[0]: 15 -- white
		0  -- black
		4  -- blue
		2  -- green
		1  -- red
		3  -- brown
		5  -- purple
		3  -- orange
		11 -- yellow
		10 -- light green
		6  -- teal
		14 -- cyan
		12 -- light blue
		13 -- pink
		8  -- gray
		7  -- light gray
	}

	color_to_xterm = (line)->
		(line\gsub("\003(%d%d?),(%d%d?)", (fg, bg)->
			"\027[38;5;#{colors[tonumber(fg)]};48;5;#{colors[tonumber(bg)]}m"
		)\gsub("\003(%d%d?)", (fg)->
			"\027[38;5;#{colors[tonumber(fg)]}m"
		)\gsub("[\003\015]", "\027[0m"))
	
	time_format = "\00311[\015%X\00311]\015"

	log: (fmt, ...)=>
		time = os.date(time_format)\gsub ":", "\00308:\015"
		print color_to_xterm "#{time} #{string.format fmt, ...}\015"
	
	debug: (fmt, ...)=>
		@log fmt, ...  if @config.debug

return :IRCClient
