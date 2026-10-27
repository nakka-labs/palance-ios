/// What Group Home's balance hero should say — decided here, as a pure
/// function, rather than inferred from an empty array in the view.
///
/// The bug this replaced (`CHECKLIST.md` "Test framework rebuild"): the hero
/// read "my balances" as `[]` both when the member was genuinely settled *and*
/// when the signed-in identity simply hadn't claimed a member in this group
/// (or its membership list hadn't loaded yet), so a signed-in-but-unclaimed
/// viewer was told "You're all settled up" while the Members list showed real
/// debts.
public enum BalanceHeroState: Equatable, Sendable {
    /// The group's state, or the identity's membership list, isn't in hand yet.
    case loading
    /// Signed in, membership list loaded, and no member of this group is
    /// claimed by this identity — there is no "my balance" to show.
    case notAMember
    /// A claimed member whose every balance is zero.
    case settled
    /// A claimed member's nonzero balances, one per currency, in the order
    /// given (never blended across currencies).
    case balances([Balance])

    /// - Parameters:
    ///   - groupLoaded: the group's state has been fetched at least once.
    ///   - membershipKnown: the signed-in identity's group list has been
    ///     fetched at least once, so a `nil` `myMemberId` really means
    ///     "not a member" rather than "not known yet".
    ///   - myMemberId: the member this identity claimed in this group, if any.
    ///   - balances: every member's balances in the group.
    public static func resolve(
        groupLoaded: Bool,
        membershipKnown: Bool,
        myMemberId: String?,
        balances: [Balance]
    ) -> BalanceHeroState {
        guard groupLoaded else { return .loading }
        guard let myMemberId else { return membershipKnown ? .notAMember : .loading }
        let mine = balances.filter { $0.memberId == myMemberId && $0.netMinor != 0 }
        return mine.isEmpty ? .settled : .balances(mine)
    }
}
