//
//  DateIsSoonerTests.swift
//  AnacacuyaBot
//
//  Created by Ky on 2026-05-15.
//


import Foundation
import Testing

import AnacacuyaBot



@Suite("Date.isSooner(than:) tests")
struct DateIsSoonerTests {
    @Test("Returns true when the date is within the given past duration")
    func withinDurationPastIsTrue() async throws {
        let now = Date()
        let duration: Duration = .seconds(5)
        let threeSecondsAgo = now.addingTimeInterval(-3)
        #expect(threeSecondsAgo.isSooner(than: duration) == true)
    }

    @Test("Returns false when the date is older than the given past duration")
    func olderThanDurationPastIsFalse() async throws {
        let now = Date()
        let duration: Duration = .seconds(5)
        let tenSecondsAgo = now.addingTimeInterval(-10)
        #expect(tenSecondsAgo.isSooner(than: duration) == false)
    }

    @Test("Returns false at the boundary (exactly duration ago) due to strict < comparison")
    func boundaryIsFalse() async throws {
        // isSooner uses: self.addingTimeInterval(duration.timeInterval) < .now
        // So if self == now - duration, the left side equals now and the result is false
        let now = Date()
        let duration: Duration = .seconds(5)
        let exactlyFiveSecondsAgo = now.addingTimeInterval(-5)
        #expect(exactlyFiveSecondsAgo.isSooner(than: duration) == false)
    }

    @Test("Returns false for future dates regardless of duration")
    func futureDateIsFalse() async throws {
        let now = Date()
        let fiveSecondsAgo: Duration = .seconds(5)
        let inTwoSeconds = now.addingTimeInterval(2)
        #expect(inTwoSeconds.isSooner(than: fiveSecondsAgo) == true)
    }
}
