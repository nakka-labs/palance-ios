import Testing
@testable import PalanceKit

@Suite("BalanceHeroState")
struct BalanceHeroStateTests {
    private let me = "m-me"
    private let other = "m-other"

    /// An equal 2-person split of 100.00 paid by `other`: they're owed 50.00,
    /// `me` owes 50.00 — the owner's 2026-10-27 report.
    private var twoPersonBalances: [Balance] {
        [
            Balance(memberId: other, currency: "INR", netMinor: 5_000),
            Balance(memberId: me, currency: "INR", netMinor: -5_000),
        ]
    }

    @Test("group state not loaded yet → loading")
    func groupNotLoaded() {
        let state = BalanceHeroState.resolve(
            groupLoaded: false, membershipKnown: true, myMemberId: me, balances: twoPersonBalances
        )
        #expect(state == .loading)
    }

    @Test("membership list not loaded yet → loading, never 'not a member' or 'settled'")
    func membershipUnknown() {
        let state = BalanceHeroState.resolve(
            groupLoaded: true, membershipKnown: false, myMemberId: nil, balances: twoPersonBalances
        )
        #expect(state == .loading)
    }

    @Test("signed in as an identity that hasn't claimed a member → not a member, never 'settled'")
    func notAMember() {
        // The bug: this used to render "You're all settled up" while the
        // Members list showed real balances.
        let state = BalanceHeroState.resolve(
            groupLoaded: true, membershipKnown: true, myMemberId: nil, balances: twoPersonBalances
        )
        #expect(state == .notAMember)
    }

    @Test("a member who owes → their own balances only")
    func memberOwes() {
        let state = BalanceHeroState.resolve(
            groupLoaded: true, membershipKnown: true, myMemberId: me, balances: twoPersonBalances
        )
        #expect(state == .balances([Balance(memberId: me, currency: "INR", netMinor: -5_000)]))
    }

    @Test("a member with no nonzero balance → settled")
    func memberSettled() {
        let state = BalanceHeroState.resolve(
            groupLoaded: true, membershipKnown: true, myMemberId: me,
            balances: [Balance(memberId: me, currency: "INR", netMinor: 0), Balance(memberId: other, currency: "INR", netMinor: 0)]
        )
        #expect(state == .settled)
    }

    @Test("multi-currency member keeps every nonzero currency, drops zeros")
    func multiCurrency() {
        let state = BalanceHeroState.resolve(
            groupLoaded: true, membershipKnown: true, myMemberId: me,
            balances: [
                Balance(memberId: me, currency: "INR", netMinor: -5_000),
                Balance(memberId: me, currency: "USD", netMinor: 0),
                Balance(memberId: me, currency: "EUR", netMinor: 1_200),
            ]
        )
        #expect(state == .balances([
            Balance(memberId: me, currency: "INR", netMinor: -5_000),
            Balance(memberId: me, currency: "EUR", netMinor: 1_200),
        ]))
    }
}
