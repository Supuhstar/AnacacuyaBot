//
//  Deduplicate chat.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-18.
//

import Foundation

import CollectionTools



// MARK: - API

public extension [OllamaMessage] {
    
    /// Deduplicates consecutive identical messages. Use this before sending these messages to a smaller LLM.
    ///
    /// Small models can easily loop on themselves, especially when given the same message more than once in a context conversation.
    /// Stripping the repetition before sending is much cheaper than working around it in the model.
    ///
    /// This dedupe keeps _latest_ occurrence of any repeated content, so that the natural chronology of the conversation is preserved.
    func deduplicated() -> [OllamaMessage] {
        removeEarlierDuplicates(by: \.content)
    }
}



public extension [ChatMessage] {
    
    /// Deduplicates consecutive identical messages. Use this before sending these messages to a smaller LLM.
    ///
    /// Small models can easily loop on themselves, especially when given the same message more than once in a context conversation.
    /// Stripping the repetition before sending is much cheaper than working around it in the model.
    ///
    /// This dedupe keeps _latest_ occurrence of any repeated content, so that the natural chronology of the conversation is preserved.
    func deduplicated() -> [ChatMessage] {
        removeEarlierDuplicates(by: \.text)
    }
}



// MARK: - guts

private extension RangeReplaceableCollection where Self: CollectionWhichCanBeEmpty {
    
    /// Removes duplicate items in this array, running in reverse so that the last duplciate instance is the one that's kept
    ///
    /// - Parameter keyPath: Which field of the element defines equality in this context.
    ///                      To compare the elements themselves, just pass `\.self`.
    ///
    /// - Returns: A copy of this collection with all duplicate elements removed except the last
    func removeEarlierDuplicates<T: Equatable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        self
            .reversed()
            .withoutDuplicates(equatingBy: { lhs, rhs in
                lhs[keyPath: keyPath] == rhs[keyPath: keyPath]
            })
            .reversed()
            .collect()
    }
}
