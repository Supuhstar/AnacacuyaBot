//
//  main.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation



/// Entry point. The bot's work is launched on a detached task because
/// top-level code in `main.swift` runs on `@MainActor`, and we don't
/// want that isolation boundary leaking into every internal call.
/// `RunLoop.main.run()` then keeps the process alive indefinitely while
/// the detached task does the work.
Task.detached {
    do {
        let bot = try await BotRunner.start()
        await bot.run()
    }
    catch {
        print("❌ Fatal: \(error)")
        exit(.init((error as NSError).code))
    }
}

RunLoop.main.run()
