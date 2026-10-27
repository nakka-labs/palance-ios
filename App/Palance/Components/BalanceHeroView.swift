import SwiftUI
import PalanceKit

/// The "You are owed ₹1,200" / "You owe ₹350" hero card on Group Home. With
/// multi-currency a member can be owed in one currency and owe in another, so
/// each currency gets its own line and they're never blended.
struct BalanceHeroView: View {
    /// What to say (`BalanceHeroState` — decided and tested in PalanceKit,
    /// not inferred here from an empty array).
    let state: BalanceHeroState
    /// This group's formula accent (`CHECKLIST.md` "Per-group accent color")
    /// — tints the card's one accent action (Settle Up, or Claim Your Spot).
    var accent: Color?
    /// The group's flat tint for the card fill (`GroupColor.tint(forId:)`),
    /// so the focal card carries the group's identity. `nil` → a neutral
    /// `Surface.raised` card.
    var tint: Color?
    /// A persistent "Settle Up" CTA on the card itself (`CHECKLIST.md` UX
    /// audit [6] step 4); `nil` hides it.
    var onSettleUp: (() -> Void)?
    /// Offered when this identity hasn't claimed a member here
    /// (`BalanceHeroState.notAMember`) — opens `ClaimMemberView`.
    var onClaim: (() -> Void)?

    /// The `.balances` payload, or empty.
    private var balances: [Balance] {
        if case .balances(let balances) = state { return balances }
        return []
    }

    var body: some View {
        VStack(spacing: 8) {
            switch state {
            case .loading:
                Text("Your balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("₹0,000")
                    .font(heroFont)
                    .redacted(reason: .placeholder)
            case .notAMember:
                // Was "You're all settled up" — wrong whenever the Members
                // list showed real balances (`CHECKLIST.md` "Test framework
                // rebuild").
                message("You're not in this group yet")
                if let onClaim {
                    accentButton("Claim Your Spot", systemImage: "person.crop.circle.badge.plus", action: onClaim)
                }
            case .settled:
                message("You're all settled up")
            case .balances(let balances):
                // `.fixedSize` so this always wraps in full rather than
                // truncating (`CHECKLIST.md` "UI audit, fresh eyes pass").
                Text(balances.count == 1 ? headline(for: balances[0]) : "Your balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 4) {
                    ForEach(balances, id: \.currency) { balance in
                        Text(amountLine(for: balance))
                            .font(heroFont)
                            .foregroundStyle(balance.netMinor > 0 ? .green : .red)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                }
                if let onSettleUp {
                    accentButton("Settle Up", systemImage: "checkmark.circle", action: onSettleUp)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        // The one focal point on Group Home, and flat (`DESIGN_BIBLE.md` §9
        // rules 1-2): a solid fill in the group's tint — no gradient wash, no
        // shadow. It used to be a raised card with a two-stop wash and an
        // accent glow; the restraint pass retired both.
        .background(
            tint ?? Surface.raised,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .padding(.horizontal)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    /// The balance is the number a person looks at most, so it stays on SF
    /// Rounded rather than the display face (Space Grotesk's geometric digits
    /// and cramped ₹ read a touch calculator-ish at this size — owner call);
    /// still tabular so it doesn't jiggle as balances change.
    private var heroFont: Font { .hero }

    /// The card's whole message when there's no number to show — Body, not
    /// Secondary (`DESIGN_BIBLE.md` §9 rule 3).
    private func message(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The card's one accent action (§9 rule 6).
    private func accentButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent ?? .accentColor)
        .controlSize(.small)
        .padding(.top, 6)
    }

    private func headline(for balance: Balance) -> String {
        balance.netMinor > 0 ? "You are owed" : "You owe"
    }

    /// For a single currency the sign is carried by the headline, so show the
    /// bare amount; for multiple, prefix each so a mixed row still reads. A
    /// thin space sits between the currency symbol and the first digit — calmer
    /// than "₹1,200" jammed together at hero size, and only here (list rows
    /// stay tight).
    private func amountLine(for balance: Balance) -> String {
        let amount = MoneyFormat.string(minorUnits: abs(balance.netMinor), currency: balance.currency)
        let spaced = Self.spacingCurrencySymbol(amount)
        guard balances.count > 1 else { return spaced }
        return balance.netMinor > 0 ? "owed \(spaced)" : "owe \(spaced)"
    }

    /// Insert a thin space (U+2009) before the first digit when it's preceded
    /// by a currency symbol — "₹ 1,200", "$ 5". Leaves an already-spaced or
    /// suffix-symbol format untouched. Internal + `static` so `BalanceHeroViewTests`
    /// can exercise the string manipulation directly.
    static func spacingCurrencySymbol(_ s: String) -> String {
        guard let firstDigit = s.firstIndex(where: \.isNumber), firstDigit != s.startIndex else { return s }
        let before = s[s.index(before: firstDigit)]
        guard !before.isWhitespace, !before.isNumber else { return s }
        return s[..<firstDigit] + "\u{2009}" + s[firstDigit...]
    }
}
