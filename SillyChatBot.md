# SillyChatBot

A Swift 6 Telegram group chat bot backed by a local Ollama model.
Zero external dependencies. Long polling. Actor-isolated state throughout.

---

## Setup

```bash
# 1. Register your bot with @BotFather, get a token
# 2. Disable privacy mode: /setprivacy → your bot → Disable
# 3. Pull the model
ollama pull smollm2

# 4. Set env var and run
export TELEGRAM_BOT_TOKEN="123456:ABC-DEF..."
export OLLAMA_MODEL="smollm2"   # optional, this is the default
swift run
```

---

## Notes

- **Context window**: `smollm` (v1) has 2K tokens. Use `smollm2` (8K). The history buffer keeps the last 15 messages; smollm v1 will overflow.
- **Privacy mode**: Disable it in BotFather or the bot will only see @mentions and `/commands` — the interjection history buffer will be empty.
- **Interjection budget**: 4 per day per chat, randomly spaced 4–20h apart. Resets at midnight.
- **Multi-chat**: Each group the bot is in gets its own isolated `ChatState`. The interjector picks a random active chat per firing.
