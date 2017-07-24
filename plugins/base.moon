cqueues = require "cqueues"
{:IRCClient} = require "lib.irc"
re = require "re"

-- [==] Keeping Alive [==]

IRCClient\add_hook 'CONNECT', =>
	@channels = {}
	@users = {}
	@server =
		isupport_caps: {}
		ircv3_caps: {}
		batches: {}

--- If you want to automatically join multiple channels, you can, in the
-- configuration, put "#channel_1,#channel_2" instead of listing them one each
IRCClient\add_handler '001', =>
	if @config.autojoin
		for channel in *@config.autojoin
			@send_raw "JOIN %s", channel
			cqueues.sleep 0.5

IRCClient\add_handler 'PING', (line)=>
	@send_raw "PONG : %s", line[#line]

IRCClient\add_handler 'ERROR', =>
	cqueues.sleep math.max(0, os.time! - (@data.last_connect + 30))
	@connect!

IRCClient\add_handler '443', (line)=>
	if not @data.nick_test
		@data.nick_test = 0
	@data.nick_test += 1
	if @data.nick_test > 30
		@disconnect!
	else
		@send_raw "NICK %s[%s]", @config.nick, @data.nick_test

-- [==] Capability Negotiation ::TODO:: [==]

-- [==] Data Collection [==]

isupport_cap_parser = re.compile [[{|
	{:is_deleting: {'-'} :}?
	{:key: {[^ =]+} :} {:value: '=' {.+} :}?
|}]]

IRCClient\add_handler '005', (line)=>
	for i=2, #line - 1
		cap = isupport_cap_parser\match line[i]
		if cap.is_deleting
			@server.isupport_caps[cap.key] = nil
		else
			@server.isupport_caps[cap.key] = cap.value or true

IRCClient\add_handler 'AWAY', (line)=>
	@users[line.nick].away = line[#line]

IRCClient\add_handler 'ACCOUNT', (line)=>
	@users[line.nick].account = line[1] != '*' and line[1] or nil

IRCClient\add_handler 'JOIN', (line)=>
	local channel, account, realname
	channel = line[#line]

	-- Add user to users

	if @server.ircv3_caps['extended_join']
		if line[2] != '*'
			channel, account, realname = table.unpack line
	elseif @server.ircv3_caps['account-tag'] and line.tags.account
		account = line.tags.account
	{:nick, :user, :host} = line
	if not @users[nick]
		@users[nick] =
			account: account
			channels:
				[channel]:
					status: ""
			username: user
			host: host
	else
		@users[nick].channels[channel] = status: ""
	@users[nick].realname = realname if realname

	-- Add channel to channels
	if not @channels[channel]
		if @server.ircv3_caps['userhost-in-names']
			@send_raw "NAMES %s", channel
		else
			@send_raw "WHO %s", channel
		@channels[channel] =
			users:
				[nick]: @users[nick]
	else
		@channels[channel].users[nick] = @users[nick]

IRCClient\add_handler 'NICK', (line)=>
	{:nick, :server} = line
	old = nick or server
	new = line[#line]
	for channel_name in pairs @users[old].channels
		@channels[channel_name].users[new] = @users[old]
		@channels[channel_name].users[old] = nil
	@users[new] = @users[old]
	@users[old] = nil

IRCClient\add_handler 'MODE', (line)=>
	local modes
	if @server.isupport_caps.PREFIX then
		symbols = @server.isupport_caps.PREFIX\match "(%(.-%))"
		modes = "[#{symbols}]"
	else
		modes = "ov"
	@send_raw "NAMES %s", line[1] if line[2]\match modes

IRCClient\add_handler '332', (line)=>
	@channels[line[2]].topic = line[3]

IRCClient\add_handler 'TOPIC', (line)=>
	@channels[line[1]].topic = line[2]

IRCClient\add_handler '353', (line)=>
	local statuses
	channel = line[3]
	prefix_cap = @server.isupport_caps.PREFIX
	if prefix_cap then
		statuses = "[#{prefix_cap\match("%(.-%)(.+)")\gsub "%p", "%%%1"}]"
	else
		statuses = "+@"
	
	for text in line[#line]\gmatch "%S+"
		local status, pre, nick, user, host
		if text\match statuses
			status, pre = text\match ("^(%s+)(.+)")\format statuses
		else
			status, pre = '', text

		if @server.ircv3_caps['userhost-in-names']
			-- TODO: prefix_pattern in IRCClient
			{:nick, :user,
				:host} = IRCClient.prefix_pattern\match pre
		else
			nick = pre

		@users[nick] = channels: {} if not @users[nick]
		@users[nick].user = user if user
		@users[nick].host = host if host

		if @channels[channel].users[nick]
			if @users[nick].channels[channel]
				@users[nick].channels[channel].status = status
			else
				@users[nick].channels[channel] = :status
		else
			@channels[channel].users[nick] = @users[nick]
			@users[nick].channels[channel] = :status

IRCClient\add_handler '352', (line)=>
	{_, user, host, _, nick, away} = line
	_user = @users[nick]
	if not _user
		@users[nick] = channels: {}
		_user = @users[nick]
	
	_user.user = user
	_user.host = host
	_user.away = away\sub(1, 1) == "G"

IRCClient\add_handler 'CHGHOST', (line)=>
	@users[line.nick].user, @users[line.nick].host = table.unpack line

IRCClient\add_handler 'KICK', (line)=>
	channel, nick = table.unpack line
	@users[nick].channels[channel] = nil
	if @users[nick].channels == 0 -- ::TODO:: re-fix at MONITOR impl.
		@users[nick] = nil

IRCClient\add_handler 'PART', (line)=>
	@users[line.nick].channels[line[1]] = nil
	if @users[line.nick].channels == 0
		@users[line.nick] = nil -- ::TODO:: re-fix at MONTIOR impl.

IRCClient\add_handler 'QUIT', (line)=>
	{:nick} = line
	for channel in pairs(@users[nick].channels)
		@channels[channel].users[nick] = nil
	@users[nick] = nil
