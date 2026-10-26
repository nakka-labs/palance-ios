import PalanceKit
import SwiftUI

/// "Who Owes Whom" — the balance bubbles plus the group's simplified settle-up
/// plan, one screen reached from a row under Group Home's balance hero
/// (`DESIGN_BIBLE.md` §9: the hero stands alone, so the bubble view moved out
/// of the swipeable hero carousel it used to be page 2 of).
struct WhoOwesWhomView: View {
    let members: [Member]
    let balances: [Balance]
    let simplifiedSettlements: [SimplifiedSettlement]

    private func name(for memberId: String) -> String {
        members.first { $0.id == memberId }?.displayName ?? "Someone"
    }

    var body: some View {
        List {
            Section {
                BalanceBubbleView(members: members, balances: balances)
                    .padding(.vertical, 12)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if !simplifiedSettlements.isEmpty {
                Section {
                    ForEach(simplifiedSettlements, id: \.self) { edge in
                        LabeledContent(
                            "\(name(for: edge.fromId)) → \(name(for: edge.toId))",
                            value: MoneyFormat.string(minorUnits: edge.amountMinor, currency: edge.currency)
                        )
                    }
                } header: {
                    Text("To Settle Up")
                } footer: {
                    Text("The fewest payments that settle everyone. Each bubble is sized by how much that person owes or is owed.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Surface.canvas)
        .navigationTitle("Who Owes Whom")
        .navigationBarTitleDisplayMode(.inline)
    }
}
