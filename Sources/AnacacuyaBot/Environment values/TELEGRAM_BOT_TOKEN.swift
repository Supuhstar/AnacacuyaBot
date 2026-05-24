//
//  TELEGRAM_BOT_TOKEN.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-16.
//



extension UnixEnvironmentKey
where Value == TelegramBotToken,
      Backup == Never
{
    
    /// The bot's login token from Telegram.
    ///
    /// You obtain this from [@BotFather](https://t.me/BotFather) on Telegram
    static let telegramBotToken: Self = "TELEGRAM_BOT_TOKEN"
}
