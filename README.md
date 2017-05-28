# irc-bot
IRC bot in FusionScript

## Configuration - in Lua

Configuration should be put in the `~/.config/irc-bot/` directory. Any file can
be used as long as it ends in .lua and multiple files can be used. The file
should contain something resembling the below code:

```lua
bot "#!" {
	server = "irc.hashbang.sh";
	autojoin = {
		"#!";
		"#!FusionScript";
		"#!social";
	}
};
```
