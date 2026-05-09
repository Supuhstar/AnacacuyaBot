# AnacacuyaBot

A gemful Telegram group chat bot backed by a local Ollama model.

This will talk in DMs, respond to any mentions/replies to it, and randomly send a message in a group it's in a few times per day.

---

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

---

## Notes

- **Limits**: General limits are defined in `Sources/AnacacuyaBot/LIMITS.swift`. Tweak those if you need to.
- **Multi-chat**: Each group the bot is in gets its own isolated `ChatState`. The interjector picks a random active chat each time.
