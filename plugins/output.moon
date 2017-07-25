{:IRCClient} = require "lib.irc"

color = (text)-> ("\00300%s\015")\format text

patterns =
	JOIN: "\00308[\0030%s\00308]\015 \00309>\015 %s"
		-- channel, nick
	NICK: "%s \00309>>\015 %s"
		-- nick, nick
	MODE: "\00308[\0030%s\00308]\015 Mode %s by %s"
		-- channel/user, mode, nick
	MODE_2: "\00308[\0030%s\00308]\015 Mode %s"
		-- user, mode
	KICK: "\00308[\0030%s\00308]\015 %s kicked %s"
		-- nick, nick
	KICK_2: "\00308[\0030%s\00308]\015 %s kicked %s \00314(\015%s\00314)"
		-- nick, nick, reason
	PART: "\00308[\0030%s\00308]\015 \00304<\015 %s"
		-- nick
	PART_2: "\00308[\0030%s\00308]\015 \00304<\015 %s \00314(\015%s\00314)"
		-- nick, reason
	QUIT: "\00311<\015%s\00311>\015 \00304<\015 \00314(\015%s\00314)"
		-- nick, reason
	ACTION: "\00308[\0030%s\00308]\015 * %s %s"
		-- nick, message
	ACTION_2: "* %s %s"
		-- nick, message
	PRIVMSG: "\00311<\00308[\0030%s\00308]\015%s\00311>\015 %s"
		-- channel, nick, message
	PRIVMSG_2: "\00311<\015%s\00311>\015 %s"
		-- nick, message
	NOTICE: "\00311-\00308[\0030%s\00308]\015%s\00311-\015 %s"
		-- channel, nick, message
	NOTICE_2: "\00311-\015%s\00311-\015 %s"
		-- nick, message
	INVITE: "\00308[\0030%s\00308]\015 %s invited %s"
		-- nick, nick
	_CHANNEL: "^#"
	_ACTION: "^\001ACTION (.+)\001$"
	_CTCP: "^\001.+\001$"

IRCClient\add_handler '372', (line)=>
	@log "\00305%s", line[#line] -- MOTD

IRCClient\add_handler 'JOIN', (line)=>
	@log patterns.JOIN, line[1], color(line.nick)

IRCClient\add_handler 'NICK', (line)=>
	@log patterns.NICK, color(line.nick), color(line[1])

IRCClient\add_handler 'MODE', (line)=>
	{channel, :nick} = line
	if patterns._CHANNEL\match channel
		@log patterns.MODE, channel, table.concat(line, " "), color(nick)
	else
		@log patterns.MODE_2, channel, table.concat(line, " ")

IRCClient\add_handler 'KICK', (line)=>
	{channel, kicked, message, :nick} = line
	if message != kicked
		@log PATTERNS.KICK_2, channel, color(nick), color(kicked), message
	else
		@log PATTERNS.KICK, channel, color(nick), color(kicked)

IRCClient\add_handler 'PART', (line)=>
	{channel, message, :nick} = line
	if message != nick
		@log patterns.PART_2, channel, color(nick), message
	else
		@log patterns.PART, channel, nick

IRCClient\add_handler 'QUIT', (line)=>
	{message, :nick} = line
	@log patterns.QUIT, color(nick), (message or "Client quit")

IRCClient\add_handler 'PRIVMSG', (line)=>
	{:nick, channel, message} = line
	if channel\match patterns._CHANNEL
		prefix = @users[nick].channels[channel] and
			@users[nick].channels[channel].status or ""
		user = color(prefix .. nick)
		if message\match patterns._ACTION
			@log patterns.ACTION, channel, color(user),
				message\match patterns._ACTION
		elseif not message\match patterns._CTCP
			@log patterns.PRIVMSG, channel, user, message
	else
		if message\match patterns._ACTION
			@log patterns.ACTION_2, color(nick), message\match patterns._ACTION
		elseif not message\match patterns._CTCP
			@log patterns.PRIVMSG_2, color(nick), message

IRCClient\add_handler 'NOTICE', (line)=>
	{:nick, channel, message} = line
	if channel\match patterns._CHANNEL
		prefix = @users[nick].channels[channel] and
			@users[nick].channels[channel].status or ""
		user = color(prefix .. nick)
		if not message\match patterns._CTCP
			@log patterns.NOTICE, channel, user, message
	elseif not message\match patterns._CTCP
		@log patterns.NOTICE_2, color(nick), message
