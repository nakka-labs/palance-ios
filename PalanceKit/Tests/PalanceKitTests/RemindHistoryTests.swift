import Testing
import Foundation
@testable import PalanceKit

@Suite("RemindHistory")
struct RemindHistoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - isInCooldown

    @Test("never reminded is never in cooldown")
    func testNeverRemindedNotInCooldown() {
        #expect(RemindHistory.isInCooldown(lastRemindedAt: nil, now: t0) == false)
    }

    @Test("just reminded is in cooldown")
    func testJustRemindedInCooldown() {
        #expect(RemindHistory.isInCooldown(lastRemindedAt: t0, now: t0.addingTimeInterval(60)) == true)
    }

    @Test("right at the cooldown boundary is no longer in cooldown")
    func testCooldownBoundary() {
        let now = t0.addingTimeInterval(RemindHistory.cooldown)
        #expect(RemindHistory.isInCooldown(lastRemindedAt: t0, now: now) == false)
        #expect(RemindHistory.isInCooldown(lastRemindedAt: t0, now: now.addingTimeInterval(-1)) == true)
    }

    // MARK: - relativeLabel

    /// Explicitly typed, plain-literal cases outside the macro — an inline
    /// array of `(TimeInterval(5 * 60), "…")` tuples in `@Test(arguments:)`
    /// timed out the Linux CI type-checker (Swift 6.0) on every push from
    /// 2026-09-13 on, while the Mac's newer compiler was fine.
    static let relativeLabelCases: [(TimeInterval, String)] = [
        (0, "Just now"), (30, "Just now"),
        (300, "5m ago"), (3_540, "59m ago"),           // 5 min, 59 min
        (7_200, "2h ago"), (82_800, "23h ago"),        // 2 h, 23 h
        (259_200, "3d ago"),                           // 3 days
    ]

    @Test("relativeLabel", arguments: relativeLabelCases)
    func testRelativeLabel(elapsed: TimeInterval, expected: String) {
        #expect(RemindHistory.relativeLabel(since: t0, now: t0.addingTimeInterval(elapsed)) == expected)
    }

    @Test("clock skew (a 'reminded' time in the future) floors at Just now, not a negative duration")
    func testClockSkewFloors() {
        #expect(RemindHistory.relativeLabel(since: t0.addingTimeInterval(60), now: t0) == "Just now")
    }
}

@Suite("RemindHistoryStore")
struct RemindHistoryStoreTests {
    @Test("in-memory store round-trips a map")
    func testInMemoryRoundTrip() {
        let date = Date(timeIntervalSince1970: 500_000)
        let store = InMemoryRemindHistoryStore()
        #expect(store.load() == [:])
        store.save(["a-b-INR": date])
        #expect(store.load() == ["a-b-INR": date])
    }

    @Test("UserDefaults store round-trips through encode/decode and clears on an empty save")
    func testUserDefaultsRoundTrip() {
        let defaults = UserDefaults(suiteName: "RemindHistoryStoreTests.\(UUID().uuidString)")!
        let store = UserDefaultsRemindHistoryStore(defaults: defaults)
        let date = Date(timeIntervalSince1970: 500_000)
        #expect(store.load() == [:])
        store.save(["a-b-INR": date])
        #expect(store.load() == ["a-b-INR": date])
        store.save([:])
        #expect(store.load() == [:])
    }
}
