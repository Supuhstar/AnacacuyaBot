//
//  TGChat.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-10.
//



/// Data directly from Telegram's API about a chat
struct TGChat: Decodable, Sendable, Identifiable {
    let id: Int64
    let type: TGChatType
    let title: String?
    
    let username: String?
    let firstName: String?
    let lastName: String?
}



extension TGChat {
    
    /// The name for this chat which would be best to pass to an LLM
    var nameForLlm: String {
        switch type {
        case .channel, .group, .supergroup:
            groupNameForLlm
            
        case .private:
            dmNameForLlm
        }
    }
}



private extension TGChat {
    
    /// The name for this chat, assuming this is a group chat, which would be best to pass to an LLM
    var groupNameForLlm: String {
        title ?? username ?? "a group chat"
    }
    
    
    /// The name for this chat, assuming this is DMs, which would be best to pass to an LLM
    var dmNameForLlm: String {
        if let firstName {
            if let lastName {
                "\(firstName) \(lastName)"
            }
            else {
                firstName
            }
        }
        else {
            title ?? username ?? "DMs with a user"
        }
    }
}
