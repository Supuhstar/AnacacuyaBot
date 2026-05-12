# AnacacuyaBot

A gemful Telegram group chat bot backed by a local Ollama model.

This will talk in DMs, respond to any mentions/replies to it, and randomly send a message in a group it's in a few times per day.



## Setup

1. Register your bot with [@BotFather](https://t.me/BotFather), get a token
2. Disable privacy mode with [@BotFather](https://t.me/BotFather): /setprivacy → your bot → Disable
    - Only necessary if you want this bot to autonomously interject
3. Get your bot's token from [@BotFather](https://t.me/BotFather): /token  → your bot
4. Set environment variables
    ```bash
    export TELEGRAM_BOT_TOKEN="hrgailrhjfirnnenmocuesznclizejjsnfzdls"
    export OLLAMA_MODEL="smollm2" # optional, this is the default
    export OLLAMA_BASE_URL="http://localhost:11434" # optional, this is the default 
    ```

5. Set up Ollama integration
    ```bash
    ollama pull $OLLAMA_MODEL # optional, only if you haven't already done this
    ```

6. And run!
    ```bash
    swift run
    ```



## Customization

You may customize the bot in a few ways:


### Limits

General limits are defined in `Sources/AnacacuyaBot/LIMITS.swift`. Tweak those if you need to.


### Persona

The bot adopts a persona when it's using its LLM to generate messages. You can change which one it uses by default in the `Sources/AnacacuyaBot/DEFAULT Persona.swift` file.



## Commands

This bot can accept commands. These are in the form of `/command arg1:val1 arg2:val2 Any arbitrary text you want`. Optionally you can also specify this bot by placing its `@handle` on the command name, like `/prompt@AnacacuyaBot`.

When a command has an argument, it's given in the form of `label:value`. For example, if you're telling the bot to print out its current context, you might send `/debug:fullcontext purpose:interjection`.

> ℹ️ If what you send just looks like a command but isn't one, then it'll be sent to the LLM just like any other message.

You can send the following commands to this bot:


### `/prompt`
Only sends the current system prompts to the current chat


### `/debug:fullcontext`
Sends all messages in its context to the current chat.

> ⚠️ This command spams the chat with its full context (history of seen messages + system prompts). ONLY use this if absolutely necessary

#### Arguments
- `purpose:` - Accepts a bot message purpose, which changes what kinda system prompts will be in the LLM's context
    - `response` - View the context as if the bot is directly responding to an existing message.
    - `interjection` - View the context as if the bot is randomly sending a message on its own accord.



## Notes

- **Multi-chat**: Each group the bot is in gets its own isolated `ChatState`. The interjector picks a random active chat each time.
