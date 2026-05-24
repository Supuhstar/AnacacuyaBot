//
//  main.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation

@unsafe @preconcurrency import SimpleLogging




// Originally, the bot was launched on a `Task.detached` because top-level code in `main.swift` runs on `@MainActor`,
// and we don't want that isolation boundary leaking into every internal call. We then used `RunLoop.main.run()` to
// keep the process alive indefinitely while the detached task did the work.
//
// However, on Linux and Windows, this just resulted in the program exiting immediately.
// So as ideal as that original code was, we run directly on the main actor now.
//
// – Ky, 2026-05-19 (on edits made 2026-05-09)

// MARK: - Argument parsing

let arguments = CommandLine.arguments
let verbose = arguments.contains("--verbose")
print("✳️ CommandLine.arguments             == ", CommandLine.arguments)
print("✳️ ProcessInfo.processInfo.arguments == ", ProcessInfo.processInfo.arguments)



// MARK: - Set up logging

LogManager.defaultChannels = [
    LogChannel.standardOutAndError(
        name: "Terminal output",
        lowestAllowedSeverity: verbose ? .verbose : .info,
    )
    
    // TODO: Would prefer this, but it currently crashes because SimpleLogging is pre-concurrency
//    LogChannel.customRaw(
//        name: "Terminal output",
//        severityFilter: .specificAndHigher(lowest: verbose ? .verbose : .info),
//        logger: { rawLogMessage in
//            Task { @MainActor in
//                print(
//                    rawLogMessage.dateLogged.ISO8601Format(),
//                    rawLogMessage.severity.name(style: .emoji),
//                    rawLogMessage.message
//                )
//            }
//        })
]


log(verbose: "Verbose logging enabled")
log(debug: "Debug logging enabled")
log(info: "Info logging enabled")
log(warning: "Warning logging enabled")
log(error: "Error logging enabled")
log(fatal: "Fatal logging enabled")



// MARK: - Run the bot

do {
    let bot = try await BotRunner.start()
    await bot.run()
}
catch {
    log(fatal: error)
    let code = (error as NSError).code
    if code == 0 {
        exit(-1)
    }
    else {
        exit(.init(code))
    }
}
