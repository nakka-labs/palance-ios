import Foundation
import Testing
@testable import PalanceKit

/// Runs every human-written scenario in `test-fixtures/splits/` through the
/// whole client path: form input → `ExpenseDraft.resolve()` → `Balances.compute`.
/// The worker runs the same files' expected payers/splits through its own
/// validators and balance math (`worker/test/splits.test.ts`), so the two
/// sides must agree on every scenario. Format: `test-fixtures/README.md`.
@Suite("Split scenarios (shared fixtures)")
struct SplitScenarioTests {

    struct Scenario: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let story: String
        let members: [String]
        let currency: String
        let amount: String
        let paidBy: String?
        let payers: [String: String]?
        let split: Split
        let expect: Expect

        var testDescription: String { name }

        struct Split: Decodable, Sendable {
            let type: SplitType
            let only: [String]?
            let amounts: [String: String]?
            let percents: [String: String]?
            let weights: [String: String]?
            let items: [Item]?
            let tax: String?
            let tip: String?
        }

        struct Item: Decodable, Sendable {
            let name: String
            let amount: String
            let `for`: [String]
        }

        struct Expect: Decodable, Sendable {
            let cannotSave: Bool?
            let payers: [String: Int64]?
            let splits: [String: Int64]?
            let balances: [String: Int64]?
        }

        /// The form, filled in the way a person would.
        var draft: ExpenseDraft {
            var d = ExpenseDraft(memberIds: members, payerId: paidBy ?? members[0])
            d.amountText = amount
            if let payers {
                d.isMultiPayer = true
                d.payerAmountText = payers
            }
            d.splitType = split.type
            if let only = split.only { d.includedMemberIds = Set(only) }
            d.exactAmountText = split.amounts ?? [:]
            d.percentText = split.percents ?? [:]
            d.shareText = split.weights ?? [:]
            d.itemDrafts = (split.items ?? []).enumerated().map { index, item in
                ItemDraft(id: "item-\(index)", name: item.name, amountText: item.amount, participantIds: Set(item.for))
            }
            d.taxText = split.tax ?? ""
            d.tipText = split.tip ?? ""
            return d
        }
    }

    @Test("every scenario", arguments: try SplitScenarioTests.loadScenarios())
    func scenario(_ s: Scenario) throws {
        let draft = s.draft

        if s.expect.cannotSave == true {
            #expect(!draft.canResolve, "\(s.story) — should not be saveable")
            #expect(throws: ValidationError.self) { try draft.resolve() }
            return
        }

        #expect(draft.canResolve, "\(s.story) — Save should be enabled")
        let resolved = try draft.resolve()

        let payers = Dictionary(uniqueKeysWithValues: resolved.payers.map { ($0.memberId, $0.amountMinor) })
        let splits = Dictionary(uniqueKeysWithValues: resolved.splits.map { ($0.memberId, $0.amountMinor) })
        #expect(payers == s.expect.payers, "payers")
        #expect(splits == s.expect.splits, "splits")

        let expense = Expense(
            id: "e", payers: resolved.payers, amountMinor: resolved.amountMinor, currency: s.currency,
            description: s.name, date: Date(timeIntervalSince1970: 0), splitType: s.split.type,
            splits: resolved.splits, items: resolved.items, shares: resolved.shares,
            taxMinor: resolved.taxMinor, tipMinor: resolved.tipMinor
        )
        let balances = Balances.compute(
            members: s.members.map { Member(id: $0, displayName: $0, isClaimed: false) },
            expenses: [expense],
            settlements: []
        )
        let byMember = Dictionary(uniqueKeysWithValues: balances.filter { $0.netMinor != 0 }.map { ($0.memberId, $0.netMinor) })
        #expect(byMember == s.expect.balances, "balances")
    }

    @Test("the catalogue isn't empty")
    func catalogueExists() throws {
        #expect(try Self.loadScenarios().count >= 12)
    }

    static func loadScenarios() throws -> [Scenario] {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PalanceKitTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // PalanceKit/
            .deletingLastPathComponent()   // <repo root>/
            .appendingPathComponent("test-fixtures/splits", isDirectory: true)
        return try FileManager.default
            .contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try JSONDecoder().decode(Scenario.self, from: Data(contentsOf: $0)) }
    }
}
