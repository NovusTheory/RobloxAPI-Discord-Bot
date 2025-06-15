# Roblox API Discord Bot
This repository is the code for the [Roblox API Discord bot](https://discord.com/oauth2/authorize?client_id=641655132400123906).

## Contributing
All contributions that improve the bot are welcome.

## Self Hosting
> [!NOTE]  
> The cron folder is not currently published which generates the meilisearch data.
>
> The bot will not have any data without this.
>
> Steps 4 and 5 will not work without the cron folder.

1. Have a [meilisearch](https://www.meilisearch.com/) server
2. Compile and use [my custom Lune build w/ branch nacl-and-async-fix](https://github.com/NovusTheory/lune/tree/nacl-and-async-fix)
3. Create a .env file at the root folder of this repository
```yaml
    # Your Discord application client id
    DISCORD_CLIENT_ID: ""
    # Your Discord application public key
    DISCORD_PUBLIC_KEY: ""
    # The port the HTTP server listens on
    LISTEN_PORT: 80
    # The address the HTTP server listens on
    LISTEN_ADDRESS: "http://0.0.0.0"
    # This is used to disable the signature check Discord requires on requests. DO NOT ENABLE THIS IN PRODUCTION!
    DEBUG: false
```
4. Execute `lune run cron docs:update`
5. Execute `lune run cron search:update`
6. Execute `lune run bot`