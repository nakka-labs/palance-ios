import Foundation
import Testing
@testable import PalanceKit

/// `ExpenseDraft` — the Add/Edit Expense form's money logic, moved out of
/// `AddExpenseView` (`CHECKLIST.md` "Test framework rebuild" step 2). These
/// pin the behavior the view had at the move, scenario by scenario, in the
/// words a person would describe the expense in.
@Suite("ExpenseDraft")
struct ExpenseDraftTests {
    // Group order matters (split order, remainder tie-breaks).
    static let asha = "asha", ben = "ben", chen = "chen", dev = "dev", eli = "eli"
    static let five = [asha, ben, chen, dev, eli]

    private func draft(_ members: [String], paidBy payer: String, amount: String) -> ExpenseDraft {
        var d = ExpenseDraft(memberIds: members, payerId: payer)
        d.amountText = amount
        return d
    }

    private func split(_ id: String, _ minor: Int64) -> ExpenseSplit { ExpenseSplit(memberId: id, amountMinor: minor) }
    private func paid(_ id: String, _ minor: Int64) -> ExpensePayment { ExpensePayment(memberId: id, amountMinor: minor) }

    // MARK: - Equal

    @Test("owner's case: ₹100 split equally between 2, Asha paid → 50 / 50")
    func equalTwo() throws {
        let r = try draft([Self.asha, Self.ben], paidBy: Self.asha, amount: "100").resolve()
        #expect(r.payers == [paid(Self.asha, 10_000)])
        #expect(r.splits == [split(Self.asha, 5_000), split(Self.ben, 5_000)])
    }

    @Test("₹100 equally among 3, Ben paid → the odd paisa goes to Ben")
    func equalThreeRemainderToPayer() throws {
        let r = try draft([Self.asha, Self.ben, Self.chen], paidBy: Self.ben, amount: "100").resolve()
        #expect(r.splits == [split(Self.asha, 3_333), split(Self.ben, 3_334), split(Self.chen, 3_333)])
    }

    @Test("Asha paid ₹90 for Ben and Chen's dinner but didn't eat → 45 / 45, Asha owes nothing")
    func equalPayerExcluded() throws {
        var d = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.asha, amount: "90")
        d.includedMemberIds = [Self.ben, Self.chen]
        let r = try d.resolve()
        #expect(r.splits == [split(Self.ben, 4_500), split(Self.chen, 4_500)])
    }

    @Test("payer excluded and the split is uneven → the remainder goes to the first included member")
    func equalPayerExcludedRemainder() throws {
        var d = draft([Self.asha, Self.ben, Self.chen, Self.dev], paidBy: Self.asha, amount: "100")
        d.includedMemberIds = [Self.ben, Self.chen, Self.dev]
        let r = try d.resolve()
        #expect(r.splits == [split(Self.ben, 3_334), split(Self.chen, 3_333), split(Self.dev, 3_333)])
    }

    @Test("dinner for 5, Eli skipped → 4 ways")
    func equalFiveOneSkipped() throws {
        var d = draft(Self.five, paidBy: Self.chen, amount: "2000.02")
        d.includedMemberIds = Set(Self.five).subtracting([Self.eli])
        let r = try d.resolve()
        #expect(r.splits == [split(Self.asha, 50_000), split(Self.ben, 50_000), split(Self.chen, 50_002), split(Self.dev, 50_000)])
    }

    @Test("nobody included → can't save, and resolve throws instead of crashing")
    func equalNobody() {
        var d = draft([Self.asha, Self.ben], paidBy: Self.asha, amount: "10")
        d.includedMemberIds = []
        #expect(!d.canResolve)
        #expect(throws: ValidationError.emptySplits) { try d.resolve() }
    }

    // MARK: - Amount entry

    @Test("the amount field's calculator: '12 + 8.50' → ₹20.50")
    func amountExpression() throws {
        let r = try draft([Self.asha, Self.ben], paidBy: Self.asha, amount: "12 + 8.50").resolve()
        #expect(r.amountMinor == 2_050)
    }

    @Test("blank, zero, or unparseable amount → can't save", arguments: ["", "0", "abc", "12 +"])
    func badAmount(_ text: String) {
        let d = draft([Self.asha, Self.ben], paidBy: Self.asha, amount: text)
        #expect(!d.canResolve)
        #expect(throws: ValidationError.self) { try d.resolve() }
    }

    // MARK: - Exact

    @Test("exact amounts that add up; blank rows are left off the expense")
    func exactAddsUp() throws {
        var d = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.asha, amount: "100")
        d.splitType = .exact
        d.exactAmountText = [Self.asha: "70", Self.ben: "30", Self.chen: ""]
        #expect(d.canResolve)
        #expect(try d.resolve().splits == [split(Self.asha, 7_000), split(Self.ben, 3_000)])
    }

    @Test("exact amounts ₹1 short → can't save; resolve names the mismatch")
    func exactShort() {
        var d = draft([Self.asha, Self.ben], paidBy: Self.asha, amount: "100")
        d.splitType = .exact
        d.exactAmountText = [Self.asha: "70", Self.ben: "29"]
        #expect(!d.canResolve)
        #expect(throws: ValidationError.splitMismatch(expected: 10_000, actual: 9_900)) { try d.resolve() }
    }

    // MARK: - Percentage

    @Test("50 / 30 / 20 percent of ₹1000")
    func percentClean() throws {
        var d = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.asha, amount: "1000")
        d.splitType = .percentage
        d.percentText = [Self.asha: "50", Self.ben: "30", Self.chen: "20"]
        #expect(try d.resolve().splits == [split(Self.asha, 50_000), split(Self.ben, 30_000), split(Self.chen, 20_000)])
    }

    @Test("percentages adding to 99 → can't save")
    func percentNinetyNine() {
        var d = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.asha, amount: "100")
        d.splitType = .percentage
        d.percentText = [Self.asha: "33", Self.ben: "33", Self.chen: "33"]
        #expect(d.percentTotal == 99)
        #expect(!d.canResolve)
        #expect(throws: ValidationError.percentageTotal(99)) { try d.resolve() }
    }

    @Test("33 / 33 / 34 percent of ₹100.01 → leftover paisa to the payer")
    func percentRemainder() throws {
        var d = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.ben, amount: "100.01")
        d.splitType = .percentage
        d.percentText = [Self.asha: "33", Self.ben: "33", Self.chen: "34"]
        let r = try d.resolve()
        #expect(r.splits.reduce(0) { $0 + $1.amountMinor } == 10_001)
        #expect(r.splits == [split(Self.asha, 3_300), split(Self.ben, 3_301), split(Self.chen, 3_400)])
    }

    // MARK: - Shares

    @Test("rent by rooms 2 : 1 : 1 of ₹100 → 50 / 25 / 25, weights kept for re-edit")
    func sharesRatio() throws {
        var d = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.asha, amount: "100")
        d.splitType = .shares
        d.shareText = [Self.asha: "2", Self.ben: "1", Self.chen: "1"]
        let r = try d.resolve()
        #expect(r.splits == [split(Self.asha, 5_000), split(Self.ben, 2_500), split(Self.chen, 2_500)])
        #expect(r.shares == [ShareWeight(memberId: Self.asha, weight: 2), ShareWeight(memberId: Self.ben, weight: 1), ShareWeight(memberId: Self.chen, weight: 1)])
        #expect(d.previewShareSplits() == r.splits, "the live preview must match what saves")
    }

    @Test("all shares zero → can't save")
    func sharesAllZero() {
        var d = draft([Self.asha, Self.ben], paidBy: Self.asha, amount: "100")
        d.splitType = .shares
        d.shareText = [Self.asha: "0", Self.ben: ""]
        #expect(!d.canResolve)
        #expect(throws: ValidationError.self) { try d.resolve() }
    }

    // MARK: - Itemized

    @Test("pizza ₹30 (Asha + Ben), beer ₹20 (Ben), tax ₹5 → tax follows what each ordered")
    func itemizedWithTax() throws {
        var d = draft([Self.asha, Self.ben], paidBy: Self.asha, amount: "55")
        d.splitType = .itemized
        d.itemDrafts = [
            ItemDraft(id: "pizza", name: " Pizza ", amountText: "30", participantIds: [Self.ben, Self.asha]),
            ItemDraft(id: "beer", name: "Beer", amountText: "20", participantIds: [Self.ben]),
        ]
        d.taxText = "5"
        let r = try d.resolve()
        // Asha: 15 + 5×15/50 = 16.50; Ben: 35 + 5×35/50 = 38.50.
        #expect(r.splits == [split(Self.asha, 1_650), split(Self.ben, 3_850)])
        #expect(r.items?.first?.name == "Pizza", "names are trimmed")
        #expect(r.items?.first?.participantIds == [Self.asha, Self.ben], "participants in group order, not tap order")
        #expect(r.taxMinor == 500)
        #expect(r.tipMinor == nil, "a blank tip isn't sent")
    }

    @Test("items that don't add up to the total → can't save")
    func itemizedMismatch() {
        var d = draft([Self.asha, Self.ben], paidBy: Self.asha, amount: "55")
        d.splitType = .itemized
        d.itemDrafts = [ItemDraft(id: "x", amountText: "50", participantIds: [Self.asha])]
        #expect(!d.canResolve)
        #expect(throws: ValidationError.itemSumMismatch(expected: 5_500, actual: 5_000)) { try d.resolve() }
    }

    // MARK: - Multiple payers

    @Test("Asha paid ₹60 and Ben ₹40 of a ₹100 split 3 ways → odd paisa to the bigger payer")
    func multiPayer() throws {
        var d = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.asha, amount: "100")
        d.isMultiPayer = true
        d.payerAmountText = [Self.asha: "60", Self.ben: "40"]
        let r = try d.resolve()
        #expect(r.payers == [paid(Self.asha, 6_000), paid(Self.ben, 4_000)])
        #expect(r.splits == [split(Self.asha, 3_334), split(Self.ben, 3_333), split(Self.chen, 3_333)])
    }

    @Test("two payers tied → the remainder goes to the earlier one in the group")
    func multiPayerTie() {
        var d = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.chen, amount: "100")
        d.isMultiPayer = true
        d.payerAmountText = [Self.ben: "50", Self.asha: "50"]
        #expect(d.remainderRecipient == Self.asha)
    }

    @Test("payers ₹10 short → can't save; resolve names the mismatch")
    func multiPayerShort() {
        var d = draft([Self.asha, Self.ben], paidBy: Self.asha, amount: "100")
        d.isMultiPayer = true
        d.payerAmountText = [Self.asha: "60", Self.ben: "30"]
        #expect(!d.canResolve)
        #expect(throws: ValidationError.payerSumMismatch(expected: 10_000, actual: 9_000)) { try d.resolve() }
    }

    // MARK: - Re-opening a saved expense

    private func saved(_ r: ExpenseDraft.Resolution, _ type: SplitType) -> Expense {
        Expense(
            id: "e1", payers: r.payers, amountMinor: r.amountMinor, currency: "INR", description: "x",
            date: Date(timeIntervalSince1970: 0), splitType: type, splits: r.splits,
            items: r.items, shares: r.shares, taxMinor: r.taxMinor, tipMinor: r.tipMinor
        )
    }

    /// Resolve → save → reopen → resolve again must give the same expense.
    private func roundTrips(_ d: ExpenseDraft) throws -> Bool {
        let first = try d.resolve()
        let reopened = ExpenseDraft(rehydrating: saved(first, d.splitType), memberIds: d.memberIds, fallbackPayerId: d.memberIds[0], keepItemIds: true)
        guard reopened.canResolve else { return false }
        return try reopened.resolve() == first
    }

    @Test("re-opening an equal split saves unchanged, excluded members still excluded")
    func roundTripEqual() throws {
        var d = draft(Self.five, paidBy: Self.chen, amount: "100")
        d.includedMemberIds = [Self.ben, Self.chen, Self.eli]
        #expect(try roundTrips(d))
    }

    @Test("re-opening exact, shares, itemized, and multi-payer expenses saves unchanged")
    func roundTripOthers() throws {
        var exact = draft([Self.asha, Self.ben], paidBy: Self.asha, amount: "100")
        exact.splitType = .exact
        exact.exactAmountText = [Self.asha: "70", Self.ben: "30"]
        #expect(try roundTrips(exact))

        var shares = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.asha, amount: "100")
        shares.splitType = .shares
        shares.shareText = [Self.asha: "2", Self.ben: "1", Self.chen: "1"]
        #expect(try roundTrips(shares))

        var items = draft([Self.asha, Self.ben], paidBy: Self.asha, amount: "55")
        items.splitType = .itemized
        items.itemDrafts = [
            ItemDraft(id: "p", name: "Pizza", amountText: "30", participantIds: [Self.asha, Self.ben]),
            ItemDraft(id: "b", name: "Beer", amountText: "20", participantIds: [Self.ben]),
        ]
        items.taxText = "5"
        #expect(try roundTrips(items))

        var multi = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.asha, amount: "100")
        multi.isMultiPayer = true
        multi.payerAmountText = [Self.asha: "60", Self.ben: "40"]
        #expect(try roundTrips(multi))
    }

    @Test("re-opening a clean percentage split (50 / 30 / 20) saves unchanged")
    func roundTripPercentClean() throws {
        var d = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.asha, amount: "1000")
        d.splitType = .percentage
        d.percentText = [Self.asha: "50", Self.ben: "30", Self.chen: "20"]
        #expect(try roundTrips(d))
    }

    @Test("re-opening a 3-way percentage split gives back the same whole percents", arguments: ["100", "100.01", "999.99"])
    func roundTripPercentThirds(_ amount: String) throws {
        // Percents are stored only as resolved amounts and back-computed on
        // re-open. Whole-number entry + a remainder of at most a few paisa
        // means rounding always lands back on what was typed.
        var d = draft([Self.asha, Self.ben, Self.chen], paidBy: Self.ben, amount: amount)
        d.splitType = .percentage
        d.percentText = [Self.asha: "34", Self.ben: "33", Self.chen: "33"]
        let reopened = ExpenseDraft(rehydrating: saved(try d.resolve(), .percentage), memberIds: d.memberIds, fallbackPayerId: Self.asha, keepItemIds: true)
        #expect(reopened.percentText == d.percentText)
        #expect(try roundTrips(d))
    }

    @Test("duplicating an itemized expense gives its line items fresh ids")
    func duplicateFreshItemIds() throws {
        var d = draft([Self.asha, Self.ben], paidBy: Self.asha, amount: "30")
        d.splitType = .itemized
        d.itemDrafts = [ItemDraft(id: "orig", name: "Pizza", amountText: "30", participantIds: [Self.asha, Self.ben])]
        let copy = ExpenseDraft(rehydrating: saved(try d.resolve(), .itemized), memberIds: d.memberIds, fallbackPayerId: Self.asha, keepItemIds: false)
        #expect(copy.itemDrafts.map(\.id) != ["orig"])
    }
}
