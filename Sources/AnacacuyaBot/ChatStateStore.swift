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
    private var states: [TGChat.ID: ChatState] = [:]

    /// Returns the existing state for `chatId`, creating one on first
    /// contact. Lazy creation means no explicit registration is needed
    /// when the bot joins a new group — the first message from that
    /// group implicitly initializes its state.
    func state(for chat: TGChat) -> ChatState {
        if let existing = states[chat.id] { return existing }
        let fresh = ChatState(chat: chat)
        states[chat.id] = fresh
        return fresh
    }

    /// Snapshot of all chat IDs the bot has interacted with. Used by the
    /// interjector to pick a random target each cycle.
    func allChats() -> [TGChat] { states.values.map(\.chat) }
}
