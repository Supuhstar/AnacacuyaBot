//
//  ChatStateStore.swift
//  AnacacuyaBot
//
//  Made by Ky directing Claude 4.7 Opus 2026-05-07
//



/// Registry of `ChatState` instances keyed by Telegram chat ID.
///
/// Provides a single, consistent view of which chats the bot has seen.
/// The interjector enumerates known chats here when picking a target;
/// the polling loop fetches (or lazily creates) a state on every inbound
/// message.
actor ChatStateStore {
    private var states: [Int64: ChatState] = [:]

    /// Returns the existing state for `chatId`, creating one on first
    /// contact. Lazy creation means no explicit registration is needed
    /// when the bot joins a new group — the first message from that
    /// group implicitly initializes its state.
    func state(for chatId: Int64) -> ChatState {
        if let existing = states[chatId] { return existing }
        let fresh = ChatState(chatId: chatId)
        states[chatId] = fresh
        return fresh
    }

    /// Snapshot of all chat IDs the bot has interacted with. Used by the
    /// interjector to pick a random target each cycle.
    func allChatIds() -> [Int64] { Array(states.keys) }
}
