import Foundation
import Testing
@testable import PalanceKit

/// Property-style tests for `ExpenseDraft` (`CHECKLIST.md` "Test framework
/// rebuild" step 4): thousands of seeded random drafts per split type, each
/// checked against rules that must hold for *every* input, not just the
/// hand-picked examples in `ExpenseDraftTests` / the shared scenarios.
///
/// Dependency-free and deterministic — a failure message carries the seed,
/// and `Self.draft(type:seed:)` rebuilds that exact draft.
@Suite("ExpenseDraft invariants")
struct ExpenseDraftInvariantTests {
    static let runsPerType = 2_000

    // MARK: - Deterministic generator (xorshift64*)

    struct Rng {
        private var state: UInt64
        init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
        mutating func next() -> UInt64 {
            state ^= state >> 12; state ^= state << 25; state ^= state >> 27
            return state &* 0x2545_F491_4F6C_DD1D
        }
        /// Uniform in `range`.
        mutating func int(_ range: ClosedRange<Int64>) -> Int64 {
            range.lowerBound + Int64(next() % UInt64(range.upperBound - range.lowerBound + 1))
        }
        mutating func bool() -> Bool { next() & 1 == 0 }
        /// A non-empty random subset, in the original order.
        mutating func subset(of ids: [String]) -> [String] {
            let picked = ids.filter { _ in bool() }
            return picked.isEmpty ? [ids[Int(int(0...Int64(ids.count - 1)))]] : picked
        }
        /// `total` cut into `parts` positive pieces (requires total >= parts).
        mutating func partition(_ total: Int64, into parts: Int) -> [Int64] {
            var cuts = Set<Int64>()
            while cuts.count < parts - 1 { cuts.insert(int(1...(total - 1))) }
            let edges = [0] + cuts.sorted() + [total]
            return zip(edges, edges.dropFirst()).map { $1 - $0 }
        }
    }

    /// A small amount half the time (where remainders and rounding bite),
    /// a large one otherwise.
    static func amount(_ rng: inout Rng, atLeast minimum: Int64) -> Int64 {
        rng.bool() ? rng.int(minimum...max(minimum, 500)) : rng.int(max(minimum, 501)...50_000_000)
    }

    static func draft(type: SplitType, seed: UInt64) -> ExpenseDraft {
        var rng = Rng(seed: seed)
        let memberCount = Int(rng.int(1...8))
        let members = (0..<memberCount).map { "m\($0)" }
        let participants = rng.subset(of: members)
        // Enough minor units for every positive piece any split type cuts.
        let amount = amount(&rng, atLeast: Int64(max(participants.count, 4) + 2))

        var d = ExpenseDraft(memberIds: members, payerId: members[Int(rng.int(0...Int64(memberCount - 1)))])
        d.amountText = MoneyFormat.plainString(minorUnits: amount)
        d.splitType = type

        if memberCount > 1, rng.int(0...3) == 0 {
            let payers = rng.subset(of: members)
            if amount >= Int64(payers.count) {
                d.isMultiPayer = true
                for (id, piece) in zip(payers, rng.partition(amount, into: payers.count)) {
                    d.payerAmountText[id] = MoneyFormat.plainString(minorUnits: piece)
                }
            }
        }

        switch type {
        case .equal:
            d.includedMemberIds = Set(participants)
        case .exact:
            for (id, piece) in zip(participants, rng.partition(amount, into: participants.count)) {
                d.exactAmountText[id] = MoneyFormat.plainString(minorUnits: piece)
            }
        case .percentage:
            let n = min(participants.count, 100)
            for (id, pct) in zip(participants.prefix(n), rng.partition(100, into: n)) {
                d.percentText[id] = String(pct)
            }
        case .shares:
            for id in members { d.shareText[id] = String(rng.int(0...5)) }
            if d.shareTotal == 0 { d.shareText[participants[0]] = String(rng.int(1...5)) }
        case .itemized:
            let tax = rng.bool() ? rng.int(0...min(amount / 4, 50_000)) : 0
            let tip = rng.bool() ? rng.int(0...min(amount / 4, 50_000)) : 0
            let itemsTotal = amount - tax - tip
            let itemCount = Int(rng.int(1...min(4, itemsTotal)))
            d.itemDrafts = rng.partition(itemsTotal, into: itemCount).enumerated().map { index, piece in
                ItemDraft(
                    id: "i\(index)", name: "Item \(index)",
                    amountText: MoneyFormat.plainString(minorUnits: piece),
                    participantIds: Set(rng.subset(of: members))
                )
            }
            d.taxText = tax > 0 ? MoneyFormat.plainString(minorUnits: tax) : ""
            d.tipText = tip > 0 ? MoneyFormat.plainString(minorUnits: tip) : ""
        }
        return d
    }

    // MARK: - The invariants

    @Test("every random draft obeys the split rules", arguments: SplitType.allCases)
    func invariants(_ type: SplitType) throws {
        for seed in UInt64(1)...UInt64(Self.runsPerType) {
            let d = Self.draft(type: type, seed: seed)
            let where_ = "\(type) seed \(seed): \(d.amountText) among \(d.memberIds.count)"

            #expect(d.canResolve, "\(where_) — a well-formed draft must be saveable")
            let r = try d.resolve()
            let amount = try #require(d.amountMinor)

            // 1. Not a paisa gained or lost — on either side of the ledger.
            #expect(r.splits.reduce(0) { $0 + $1.amountMinor } == amount, "\(where_): splits sum")
            #expect(r.payers.reduce(0) { $0 + $1.amountMinor } == amount, "\(where_): payers sum")
            // 2. Nobody owes or pays a negative amount; nobody appears twice.
            #expect(r.splits.allSatisfy { $0.amountMinor >= 0 }, "\(where_): negative split")
            #expect(Set(r.splits.map(\.memberId)).count == r.splits.count, "\(where_): duplicate member")
            // 3. Deterministic.
            #expect(try d.resolve() == r, "\(where_): not deterministic")
            // 4. Fair remainders.
            try checkRemainder(d, r, where_)
            // 5. The ledger nets to zero.
            let balances = Balances.compute(
                members: d.memberIds.map { Member(id: $0, displayName: $0, isClaimed: false) },
                expenses: [expense(r, type)],
                settlements: []
            )
            #expect(balances.reduce(0) { $0 + $1.netMinor } == 0, "\(where_): balances don't net to zero")
            // 6. Save → re-open → save changes nothing — for every split
            //    type and amount, now that typed percents are stored
            //    (`CHECKLIST.md` "Store the typed percentages"; before that,
            //    tiny percentage splits could drift by a point).
            let reopened = ExpenseDraft(rehydrating: expense(r, type), memberIds: d.memberIds, fallbackPayerId: d.payerId, keepItemIds: true)
            #expect(reopened.canResolve, "\(where_): re-opened expense can't be saved")
            #expect((try? reopened.resolve()) == r, "\(where_): re-opening changes the expense")
            // 7. What's sent passes the server's own percentage check.
            if let percentages = r.percentages {
                #expect(throws: Never.self, "\(where_): percentages rejected") {
                    try Validation.validatePercentages(percentages, splits: r.splits, validMemberIds: Set(d.memberIds))
                }
            }
        }
    }

    /// Equal / percentage / shares: everyone gets the floor of their exact
    /// share, and only the documented recipient gets more — by fewer minor
    /// units than there are people.
    private func checkRemainder(_ d: ExpenseDraft, _ r: ExpenseDraft.Resolution, _ where_: String) throws {
        let weights: [(String, Int64)]
        switch d.splitType {
        case .equal: weights = d.memberIds.filter { d.includedMemberIds.contains($0) }.map { ($0, 1) }
        case .percentage: weights = d.memberIds.map { ($0, Int64(d.percent(for: $0))) }.filter { $0.1 > 0 }
        case .shares: weights = d.memberIds.map { ($0, Int64(d.share(for: $0))) }.filter { $0.1 > 0 }
        case .exact, .itemized: return
        }
        let total = weights.reduce(0) { $0 + $1.1 }
        let amount = r.amountMinor
        let recipient = weights.contains { $0.0 == d.remainderRecipient } ? d.remainderRecipient : weights[0].0
        for (id, w) in weights {
            let floor = amount * w / total
            let got = try #require(r.splits.first { $0.memberId == id }?.amountMinor, "\(where_): \(id) missing")
            if id == recipient {
                #expect(got >= floor && got - floor < Int64(weights.count), "\(where_): recipient \(id) got \(got), floor \(floor)")
            } else {
                #expect(got == floor, "\(where_): \(id) got \(got), expected \(floor)")
            }
        }
    }

    private func expense(_ r: ExpenseDraft.Resolution, _ type: SplitType) -> Expense {
        Expense(
            id: "e", payers: r.payers, amountMinor: r.amountMinor, currency: "INR", description: "x",
            date: Date(timeIntervalSince1970: 0), splitType: type, splits: r.splits,
            items: r.items, shares: r.shares, percentages: r.percentages, taxMinor: r.taxMinor, tipMinor: r.tipMinor
        )
    }
}
