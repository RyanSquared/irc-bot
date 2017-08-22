{:IRCClient} = require "lib.irc"
{:sleep} = require "cqueues"
re = require "re"

epoch = os.time year: 2014, month: 0, day: 0
-- equation: x + y = 2016*365+182; x + z = 2024*365; z = y * 4
-- use Wolfram Alpha to calculate epoch
-- epoch was close enough that I rounded

conv = (t)-> epoch + (os.time(t) - epoch) * 4
cur = (format)-> os.date format, conv(os.date '*t')

local snips
snips =
	map:
		desc: "Region Map"
		text: "Region Map: http://greaterixnay.com/data/Map.png"
	rawmap:
		desc: "Labeless Map"
		text: "Raw Nations Map: http://greaterixnay.com/data/Raw_Map.png"
	rules:
		desc: "Golden Bull"
		text: "Our Rules: http://greaterixnay.com/data/GoldenBull.pdf"
	feed:
		desc: "Ixnet Feed"
		text: "IxFeed: https://greaterixnay.com/feed"
	rss:
		desc: "Ixnet RSS"
		text: "IxRSS: https://www.greaterixnay.com/forums/ixnay-central-news.25/index.rss"
	time:
		desc: "Show the current in-character date/time"
		text: setmetatable {}, __tostring: -> cur!
	help:
		desc: "Show help for commands"
		text: setmetatable {}, __tostring: ->
			out = {}
			for k, v in pairs snips
				table.insert out, "'?#{k}': #{v.desc}"
			return table.concat out, " | "
	fail:
		desc: "Purposefully error"
		text: setmetatable {}, __tostring: -> error "test"

command_pattern = re.compile "'?' {.+}"

IRCClient\add_handler 'PRIVMSG', (line)=>
	return if not @config.ixnay
	cmd = command_pattern\match line[2]
	if snips[cmd] and line[1]\lower! == "#ixnay"
		@send_raw "NOTICE %s :%s", line[1], tostring(snips[cmd].text)

IRCClient\add_hook 'CONNECT', (line)=>
	-- Use a counter every time the bot connects to automatically clean out the
	-- queue
	return if not @config.ixnay
	@counter = 0 if not @counter
	@counter += 1
	queue = require "queue"
	queue\wrap ->
		counter = @counter
		while counter == @counter
			sleep 60
			@send_raw "TOPIC #Ixnay"

escape = (text)-> text\gsub "[%[%]()%%%-+?*]", "%%%1"

IRCClient\add_handler 'TOPIC', (line)=>
	return if not @config.ixnay
	channel = line[1]
	return if channel\lower! != "#ixnay"
	topic = line[2]
	fmt = escape(topic)\gsub "IC Date: [^|]+", "IC Date: %%s"
	date = fmt\format cur "%B %Y"
	if topic != date
		@send_raw "PRIVMSG ChanServ :TOPIC %s %s",  channel, date

IRCClient\add_handler '332', (line)=>
	return if not @config.ixnay
	channel = line[2]
	return if channel\lower! != "#ixnay"
	topic = line[#line]
	fmt = escape(topic)\gsub "IC Date: [^|]+", "IC Date: %%s"
	date = fmt\format cur "%B %Y"
	if topic != date
		@send_raw "PRIVMSG ChanServ :TOPIC %s %s",  channel, date
