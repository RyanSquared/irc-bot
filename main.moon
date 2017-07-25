moonscript = require "moonscript.base"
moonscript.errors = require "moonscript.errors"

trace_in_xpcall = (err)->
	return moonscript.errors.rewrite_traceback debug.traceback!, err

moonscript.errors.trace_pcall = (fn, ...)->
	return xpcall(fn, trace_in_xpcall, ...)


cqueues = require "cqueues"
lfs = require "lfs"

{:IRCClient} = require "lib.irc"

table.unpack = table.unpack or unpack

os.execute "stty -echo"

lfs.full_dir = (folder)-> coroutine.wrap ->
	for path in lfs.dir folder
		coroutine.yield "#{folder}/#{path}"

load_modules = (folder)->
	for file in lfs.full_dir folder
		assert(moonscript.loadfile file)() if file\match "%.moon$"

reload = (clean = true)->
	IRCClient\clear_modules! if clean
	load_modules "plugins"

reload!

bots = {}
conf_home = os.getenv('XDG_CONFIG_HOME') or os.getenv('HOME') .. '/.config'

for file in lfs.full_dir conf_home .. "/irc-bot"
	if file\match "%.lua$"
		file_func = loadfile file, nil,
			bot: (name) ->
				(file_data) ->
					file_data.name = name
					file_data.file = file
					print "Adding new bot: #{name}"
					table.insert bots, IRCClient(file_data.server,
						file_data.port, file_data)
		file_func!

queue = cqueues.new!
package.loaded.queue = queue

for bot in *bots
	queue\wrap ->
		bot.config.debug = true if os.getenv "DEBUG"
		while true
			local success, err
			for i=1, 3
				success, err = moonscript.errors.trace_pcall bot.connect, bot
				break if success
			if not success
				error("Bot #{bot.config.name} can't connect: #{err}")
			ok, err = moonscript.errors.trace_pcall bot.loop, bot
			if not ok
				print "error in bot"
				print err

assert queue\loop!
