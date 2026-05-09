//
//  ChatState.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//

import Foundation



/// Per-chat memory holding a sliding window of recent messages and the
/// independent state for two interjection triggers.
///
/// The two triggers are deliberately independent:
///
/// - **Time-based**: a daily budget of `dailyTimeBasedLimit`
///   interjections driven by `BotRunner`'s random scheduler. Suited to
///   keeping the bot present in quiet chats.
/// - **Message-count**: fires when a randomized number of non-bot
///   messages accumulate in a chat. Naturally scales with chat activity,
///   so busy groups receive more interjections without the bot needing
///   to know anything about them.
///
/// Exists as an actor because two concurrent flows touch this state: the
/// polling loop appends incoming messages while the time-based
/// interjector reads history and updates counters. Actor isolation
/// provides mutual exclusion without hand-rolled locks.
///
/// Obtain instances via `ChatStateStore.state(for:)` rather than
/// constructing directly — the store guarantees one instance per chat ID.
actor ChatState {
    /// Telegram chat ID this state belongs to. Stored so the interjector
    /// can route outbound messages without a separate lookup.
    let chat: TGChat

    /// Sliding window of the most recent messages, oldest first. Capped
    /// at `maxMessages` to keep prompts within the model's context
    /// budget.
    private(set) var recentMessages: [ChatMessage] = []

    /// Number of time-based interjections fired so far in the current
    /// day. Reset by `rolloverDayIfNeeded()` whenever a new local day
    /// begins.
    private var interjectionCount = -1

    /// Midnight anchor for the current day. Used to detect day rollover
    /// without needing a wall-clock timer.
    private var dayStart: Date = .distantPast

    /// Countdown toward the next message-count interjection. Decremented
    /// by `add(_:)` for each non-bot message; on reaching zero, the
    /// trigger fires and the value re-randomizes inside the configured
    /// range. Crosses day boundaries deliberately — message-count pacing
    /// is about volume, not time.
    private var messagesUntilCountTrigger: Int = 0

    /// History window size. Tuned for `smollm2`'s 8K context — keep this
    /// in sync with the active model if you swap to one with different
    /// context headroom.
    private let maxMessagesInHistory = Limits.contextWindow_messageCount

    /// Hard cap on time-based interjections per chat per day. Does not
    /// constrain the message-count trigger; the two triggers pace
    /// themselves independently.
    private let maxDailyInterjections = Limits.maxAutonomousMessagesPerDay

    /// Range from which each fresh message-count target is drawn. The
    /// lower bound prevents the bot from reacting to short bursts of
    /// activity; the upper keeps it from going silent in slow channels.
    private static let messageCountTriggerRange 
        = Limits.minMessagesBeforeAutonomousMessageAllowed ... Limits.maxMessagesBeforeAutonomousMessageGuaranteed
    
    
    init(chat: TGChat) async {
        self.chat = chat
        rolloverDayIfNeeded()
        registerInterjection()
    }
}



// MARK: - Message registration

extension ChatState {
    
    
    /// Records an incoming message and reports what to do next.
    ///
    /// Returning the event from the mutating call (rather than requiring
    /// a follow-up check) keeps cause and effect in the same step. Under
    /// actor isolation this is also the only race-free way to observe
    /// the trigger: a separate check method would create a window in
    /// which two arrivals could both see a zero counter and each act on
    /// it. Bot-authored messages are exempt from the countdown so the
    /// bot's own activity cannot trigger itself.
    ///
    /// - Parameter message: The recently-received message
    /// - Returns: What to do next, if anything
    func register(didReceiveMessage message: ChatMessage) -> NextStep? {
        register(message)
        
        messagesUntilCountTrigger -= 1
        
        if shouldInterjectNow {
            return .interject
        }
        else {
            return .none
        }
    }
    
    
    /// Records an outgoing message
    ///
    /// - Parameter message: The message that the bot just sent
    func register(didSendMessage message: ChatMessage) {
        register(message)
        
        if message.isBotInterjection {
            registerInterjection()
        }
    }
    
    
    /// Records that the given message was received or sent
    private func register(_ message: ChatMessage) {
        recentMessages.append(message)
        if recentMessages.count > maxMessagesInHistory {
            recentMessages.removeFirst()
        }
    }
}



// MARK: - Interjection

extension ChatState {
    
    var shouldInterjectNow: Bool {
        0 >= messagesUntilCountTrigger
        || interjectionCount >= maxDailyInterjections
    }
    
    
    func registerInterjection() {
        interjectionCount += 1
        messagesUntilCountTrigger = Int.random(in: Self.messageCountTriggerRange)
        
        if stillAllowedToInterjectToday() {
            print(chat.nameForLog, "•", "Interjection \(interjectionCount)/\(maxDailyInterjections). Next interjection in \(messagesUntilCountTrigger) messages")
        }
        else {
            print(chat.nameForLog, "•", "No more interjections today")
        }
    }
    
    
    /// Reports whether the time-based interjector is currently allowed
    /// to speak in this chat. Combines the daily budget with a sanity
    /// check that there is any recent context to riff on.
    func stillAllowedToInterjectToday() -> Bool {
        rolloverDayIfNeeded()
        return interjectionCount < maxDailyInterjections
    }

    /// Lazily resets the daily counter when the local day has advanced.
    /// Called from every read or write of the time-based budget, so we
    /// never need a separate timer firing at midnight.
    private func rolloverDayIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        if today > dayStart {
            dayStart = today
            interjectionCount = 0
        }
    }
}



extension ChatState {
    
    /// What to do next
    enum NextStep {
        
        /// Send an autonomous interjection message
        case interject
    }
}



// MARK: - Logging

private extension TGChat {
    var nameForLog: String {
        self.title
        ?? self.firstName.map { firstName in
            if let lastName {
                "\(firstName) \(lastName)"
            }
            else {
                firstName
            }
        }
        ?? self.username
        ?? self.id.description
    }
}
