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
//Task.detached {
    do {
        let bot = try await BotRunner.start()
        await bot.run()
    }
    catch {
        print("❌ Fatal: \(error)")
        let code = (error as NSError).code
        if code == 0 {
            exit(-1)
        }
        else {
            exit(.init(code))
        }
    }
//}

//RunLoop.main.run()
