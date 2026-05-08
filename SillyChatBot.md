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

## Project structure

```
SillyChatBot/
├── Package.swift
└── Sources/
    └── SillyChatBot/
        ├── main.swift
        ├── Telegram Models.swift
        ├── Telegram Client.swift
        ├── Ollama Client.swift
        ├── Chat State.swift
        └── Bot Runner.swift
```

---

## Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SillyChatBot",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SillyChatBot",
            path: "Sources/SillyChatBot"
        )
    ]
)
```

---

## Sources/SillyChatBot/main.swift

```swift
import Foundation

Task.detached {
    do {
        let bot = try await BotRunner.start()
        await bot.run()
    } catch {
        print("❌ Fatal: \(error)")
        exit(1)
    }
}

RunLoop.main.run()
```

---

## Sources/SillyChatBot/Telegram Models.swift

```swift
import Foundation

// MARK: - Incoming

struct TGUpdate: Decodable, Sendable {
    let updateId: Int
    let message: TGMessage?

    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case message
    }
}

struct TGMessage: Decodable, Sendable {
    let messageId: Int
    let from: TGUser?
    let chat: TGChat
    let text: String?
    let replyToMessage: TGMessage?
    let entities: [TGMessageEntity]?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case from, chat, text
        case replyToMessage = "reply_to_message"
        case entities
    }
}

struct TGUser: Decodable, Sendable {
    let id: Int64
    let isBot: Bool
    let firstName: String
    let username: String?

    enum CodingKeys: String, CodingKey {
        case id
        case isBot = "is_bot"
        case firstName = "first_name"
        case username
    }
}

struct TGChat: Decodable, Sendable {
    let id: Int64
    let type: String
    let title: String?
}

struct TGMessageEntity: Decodable, Sendable {
    let type: String
    let offset: Int
    let length: Int
}

struct TGGetUpdatesResponse: Decodable, Sendable {
    let ok: Bool
    let result: [TGUpdate]
}

// MARK: - Outgoing

struct TGSendMessageBody: Encodable, Sendable {
    let chatId: Int64
    let text: String
    let replyToMessageId: Int?

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case text
        case replyToMessageId = "reply_to_message_id"
    }
}
```

---

## Sources/SillyChatBot/Telegram Client.swift

```swift
import Foundation

actor TelegramClient {
    private let token: String
    private let base: String
    private var offset: Int = 0

    init(token: String) {
        self.token = token
        self.base = "https://api.telegram.org/bot\(token)"
    }

    func getMe() async throws -> TGUser {
        let url = URL(string: "\(base)/getMe")!
        let (data, _) = try await URLSession.shared.data(from: url)
        struct R: Decodable { let result: TGUser }
        return try JSONDecoder().decode(R.self, from: data).result
    }

    func getUpdates(timeout: Int = 30) async throws -> [TGUpdate] {
        var comps = URLComponents(string: "\(base)/getUpdates")!
        comps.queryItems = [
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "timeout", value: "\(timeout)"),
            URLQueryItem(name: "allowed_updates", value: "[\"message\"]"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let response = try JSONDecoder().decode(TGGetUpdatesResponse.self, from: data)
        if let last = response.result.last {
            offset = last.updateId + 1
        }
        return response.result
    }

    func sendMessage(chatId: Int64, text: String, replyTo: Int? = nil) async throws {
        let url = URL(string: "\(base)/sendMessage")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = TGSendMessageBody(chatId: chatId, text: text, replyToMessageId: replyTo)
        req.httpBody = try JSONEncoder().encode(body)
        _ = try await URLSession.shared.data(for: req)
    }
}
```

---

## Sources/SillyChatBot/Ollama Client.swift

```swift
import Foundation

struct OllamaMessage: Codable, Sendable {
    let role: String
    let content: String
}

actor OllamaClient {
    private let baseURL: String
    let model: String

    init(baseURL: String = "http://localhost:11434", model: String = "smollm2") {
        self.baseURL = baseURL
        self.model = model
    }

    func chat(messages: [OllamaMessage]) async throws -> String {
        let url = URL(string: "\(baseURL)/api/chat")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120  // small models can still take a moment

        struct Body: Encodable {
            let model: String
            let messages: [OllamaMessage]
            let stream: Bool
        }
        struct Response: Decodable {
            struct Msg: Decodable { let content: String }
            let message: Msg
        }

        req.httpBody = try JSONEncoder().encode(Body(model: model, messages: messages, stream: false))
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(Response.self, from: data).message.content
    }
}
```

---

## Sources/SillyChatBot/Chat State.swift

```swift
import Foundation

struct ChatMessage: Sendable {
    let senderName: String
    let text: String
    let isBot: Bool
}

actor ChatState {
    let chatId: Int64
    private(set) var recentMessages: [ChatMessage] = []
    private var dailyInterjectionCount = 0
    private var dayStart: Date

    private let maxMessages = 15
    private let dailyInterjectionLimit = 4

    init(chatId: Int64) {
        self.chatId = chatId
        self.dayStart = Calendar.current.startOfDay(for: .init())
    }

    func add(_ message: ChatMessage) {
        recentMessages.append(message)
        if recentMessages.count > maxMessages {
            recentMessages.removeFirst()
        }
    }

    func canInterject() -> Bool {
        rolloverDayIfNeeded()
        return dailyInterjectionCount < dailyInterjectionLimit && !recentMessages.isEmpty
    }

    func recordInterjection() {
        rolloverDayIfNeeded()
        dailyInterjectionCount += 1
    }

    private func rolloverDayIfNeeded() {
        let today = Calendar.current.startOfDay(for: .init())
        if today > dayStart {
            dayStart = today
            dailyInterjectionCount = 0
        }
    }
}

actor ChatStateStore {
    private var states: [Int64: ChatState] = [:]

    func state(for chatId: Int64) -> ChatState {
        if nil == states[chatId] {
            states[chatId] = ChatState(chatId: chatId)
        }
        return states[chatId]!
    }

    func allChatIds() -> [Int64] { Array(states.keys) }
}
```

---

## Sources/SillyChatBot/Bot Runner.swift

```swift
import Foundation

struct BotRunner: Sendable {
    let telegram: TelegramClient
    let ollama: OllamaClient
    let store: ChatStateStore
    let botUsername: String

    // MARK: - Startup

    static func start() async throws -> BotRunner {
        guard let token = ProcessInfo.processInfo.environment["TELEGRAM_BOT_TOKEN"],
              false == token.isEmpty
        else {
            throw BotError.missingToken
        }
        let model = ProcessInfo.processInfo.environment["OLLAMA_MODEL"] ?? "smollm2"
        let ollamaURL = ProcessInfo.processInfo.environment["OLLAMA_BASE_URL"] ?? "http://localhost:11434"

        let telegram = TelegramClient(token: token)
        let me = try await telegram.getMe()
        let username = me.username ?? "bot"

        print("🤖 Logged in as @\(username) | model: \(model)")

        return BotRunner(
            telegram: telegram,
            ollama: OllamaClient(baseURL: ollamaURL, model: model),
            store: ChatStateStore(),
            botUsername: username
        )
    }

    // MARK: - Main loop

    func run() async {
        async let _ = runInterjector()
        await runPollingLoop()
    }

    // MARK: - Polling

    private func runPollingLoop() async {
        print("📡 Polling for updates...")
        while true {
            do {
                let updates = try await telegram.getUpdates(timeout: 30)
                for update in updates {
                    if let message = update.message {
                        await handleMessage(message)
                    }
                }
            } catch {
                print("⚠️ Poll error: \(error). Retrying in 5s...")
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func handleMessage(_ msg: TGMessage) async {
        guard let text = msg.text, false == text.isEmpty else { return }
        let sender = msg.from?.username ?? msg.from?.firstName ?? "someone"

        let state = await store.state(for: msg.chat.id)
        await state.add(ChatMessage(senderName: sender, text: text, isBot: false))

        guard isMentioned(msg) || isReplyToBot(msg) else { return }

        await generateAndSend(chatId: msg.chat.id, state: state, replyTo: msg.messageId)
    }

    // MARK: - Mention detection

    private func isMentioned(_ msg: TGMessage) -> Bool {
        guard let text = msg.text else { return false }
        if text.localizedCaseInsensitiveContains("@\(botUsername)") { return true }
        guard let entities = msg.entities else { return false }
        for entity in entities where entity.type == "mention" {
            if let start = text.index(text.startIndex, offsetBy: entity.offset, limitedBy: text.endIndex),
               let end = text.index(start, offsetBy: entity.length, limitedBy: text.endIndex) {
                let mentioned = String(text[start..<end])
                if mentioned.lowercased() == "@\(botUsername.lowercased())" { return true }
            }
        }
        return false
    }

    private func isReplyToBot(_ msg: TGMessage) -> Bool {
        guard let reply = msg.replyToMessage, let from = reply.from else { return false }
        return true == (from.username?.lowercased() == botUsername.lowercased())
    }

    // MARK: - Response generation

    private func generateAndSend(chatId: Int64, state: ChatState, replyTo: Int? = nil) async {
        let history = await state.recentMessages
        let messages = buildConversationMessages(history: history)

        do {
            let reply = try await ollama.chat(messages: messages)
            let cleaned = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard false == cleaned.isEmpty else { return }
            try await telegram.sendMessage(chatId: chatId, text: cleaned, replyTo: replyTo)
            await state.add(ChatMessage(senderName: botUsername, text: cleaned, isBot: true))
        } catch {
            print("⚠️ Generation error: \(error)")
        }
    }

    private func buildConversationMessages(history: [ChatMessage]) -> [OllamaMessage] {
        let system = """
        You are a participant in a group chat. Keep replies to 1–3 sentences. \
        Be casual, a little weird, and unpredictable. No formalities. No bullet points. \
        Just respond naturally.
        """
        var messages: [OllamaMessage] = [.init(role: "system", content: system)]
        for msg in history {
            let role = msg.isBot ? "assistant" : "user"
            let content = msg.isBot ? msg.text : "\(msg.senderName): \(msg.text)"
            messages.append(.init(role: role, content: content))
        }
        return messages
    }

    // MARK: - Random interjector

    private func runInterjector() async {
        // Initial delay so the bot doesn't fire immediately on startup
        try? await Task.sleep(for: .seconds(Int.random(in: 1800...7200)))

        while true {
            // Sleep a random time between 4h and 20h before each interjection attempt
            let delay = Int.random(in: 4 * 3600 ... 20 * 3600)
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return  // task cancelled
            }

            let chatIds = await store.allChatIds()
            guard let chatId = chatIds.randomElement() else { continue }

            let state = await store.state(for: chatId)
            guard await state.canInterject() else { continue }

            await state.recordInterjection()
            await sendInterjection(chatId: chatId, state: state)
        }
    }

    private func sendInterjection(chatId: Int64, state: ChatState) async {
        let history = await state.recentMessages
        guard false == history.isEmpty else { return }

        let context = history.map { "\($0.senderName): \($0.text)" }.joined(separator: "\n")
        let prompt = """
        Here's a recent group chat:

        \(context)

        Chime in with one short, unexpected comment. Don't just repeat what was said.
        """

        let messages: [OllamaMessage] = [
            .init(role: "system", content: "You're a quirky group chat participant. 1–2 sentences max."),
            .init(role: "user", content: prompt),
        ]

        do {
            let reply = try await ollama.chat(messages: messages)
            let cleaned = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard false == cleaned.isEmpty else { return }
            try await telegram.sendMessage(chatId: chatId, text: cleaned)
            await state.add(ChatMessage(senderName: botUsername, text: cleaned, isBot: true))
            print("💬 Interjected in chat \(chatId)")
        } catch {
            print("⚠️ Interjection error: \(error)")
        }
    }

    // MARK: -

    enum BotError: Error {
        case missingToken
    }
}
```

---

## Notes

- **Context window**: `smollm` (v1) has 2K tokens. Use `smollm2` (8K). The history buffer keeps the last 15 messages; smollm v1 will overflow.
- **Privacy mode**: Disable it in BotFather or the bot will only see @mentions and `/commands` — the interjection history buffer will be empty.
- **Interjection budget**: 4 per day per chat, randomly spaced 4–20h apart. Resets at midnight.
- **Multi-chat**: Each group the bot is in gets its own isolated `ChatState`. The interjector picks a random active chat per firing.
