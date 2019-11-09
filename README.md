# Roblox API Discord Bot
This project is a Discord bot which allows you to quickly lookup and reference the Roblox API.

## Contributing
All contributions that improve the bot are welcome.

## Self Hosting
Want to self host this bot for yourself? There's a few things you'll need

- [Lit](https://luvit.io) 3.7.3^
- [Luvit](https://luvit.io/) 2.16.0^
- [Elasticsearch](https://www.elastic.co/) 7.4.2^

Once you have the required software installed and ready to use `git clone` this repository somewhere on your server.

### Environment Files
Inside cron & bot folders create an `env.lua` file
Inside cron/env.lua paste the following replacing the variables as necessary
```lua
return {
    ELASTICSEARCH_ENDPOINT = "YOUR_ELASTICSEARCH_SERVER"
}
```
Inside bot/env.lua paste the following replacing the variables as necessary
```lua
return {
    ELASTICSEARCH_ENDPOINT = "YOUR_ELASTICSEARCH_SERVER",
    BOT_TOKEN = "YOUR_DISCORD_BOT_TOKEN"
}
```

### Dependency Setup
In the root repository directory run `lit install` and any dependencies required will be automatically installed

### Elasticsearch Setup
Initially you should run the `cron/rbxapi_dump.lua` which will generate an rbxapi_elasticsearch.json file in the current working directory and proceed to upload that file to your elasticsearch server. After this you should setup this file to run on a cron job to automatically keep everything up to date.

### Running the bot
Once all the steps above are complete you can run `bot/main.lua` to start everything up. You should now see your bot online and working.
