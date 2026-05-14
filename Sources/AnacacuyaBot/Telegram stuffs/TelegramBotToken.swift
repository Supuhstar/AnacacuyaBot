//
//  TelegramBotToken.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-14.
//

import Foundation

import SpecialString



public typealias TelegramBotToken = SpecialString<TelegramBotTokenSpecialType>
public struct TelegramBotTokenSpecialType: SpecialStringSpecialType, Sendable {}
