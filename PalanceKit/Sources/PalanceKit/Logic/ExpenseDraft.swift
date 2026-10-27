import Foundation

/// One editable line item for an `.itemized` split — the mutable, string-typed
/// counterpart to `LineItem`, resolved to exact splits only by
/// `ExpenseDraft.resolve()`.
public struct ItemDraft: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var amountText: String
    public var participantIds: Set<String>

    public init(id: String = UUID().uuidString, name: String = "", amountText: String = "", participantIds: Set<String>) {
        self.id = id
        self.name = name
        self.amountText = amountText
        self.participantIds = participantIds
    }
}

/// Totals shared by the itemized editor's own row coloring and
/// `ExpenseDraft` — one implementation so the two can never drift.
public enum ItemizedSplitMath {
    public static func itemsOnlyTotal(_ drafts: [ItemDraft]) -> Int64 {
        drafts.reduce(Int64(0)) { $0 + (MoneyFormat.minorUnits(from: $1.amountText) ?? 0) }
    }

    /// Items + tax + tip — what must equal the expense's own amount, not the
    /// items alone.
    public static func total(_ drafts: [ItemDraft], taxMinor: Int64, tipMinor: Int64) -> Int64 {
        itemsOnlyTotal(drafts) + taxMinor + tipMinor
    }
}

/// The money half of the Add/Edit Expense form — the amount, who paid, and
/// how it's split — as plain, string-typed form state, plus the pure logic
/// that turns it into exactly what goes on the wire (`resolve()`).
///
/// This used to live as ~15 `@State` properties and their helpers inside
/// `AddExpenseView` with no tests (`CHECKLIST.md` "Test framework rebuild"
/// step 2). It's a move, not a rewrite: every rule here is the view's own,
/// verbatim, so `ExpenseDraftTests` pins today's behavior. Description,
/// category, date, currency, and receipts stay in the view — none of them
/// affect the math.
///
/// Member order (`memberIds`) is the group's order and is load-bearing: it
/// decides the order splits come out in, and breaks remainder-recipient ties.
public struct ExpenseDraft: Equatable, Sendable {
    /// Every member of the group, in group order.
    public var memberIds: [String]

    public var amountText = ""

    /// The single payer, used when `isMultiPayer` is false.
    public var payerId: String
    public var isMultiPayer = false
    /// Per-member contributions while `isMultiPayer`.
    public var payerAmountText: [String: String] = [:]

    public var splitType: SplitType = .equal
    /// Who's on an `.equal` split.
    public var includedMemberIds: Set<String>
    public var exactAmountText: [String: String] = [:]
    public var percentText: [String: String] = [:]
    /// Whole-number ratio weights for `.shares`, as typed.
    public var shareText: [String: String] = [:]
    public var itemDrafts: [ItemDraft] = []
    public var taxText = ""
    public var tipText = ""

    /// A blank draft: everyone included, `payerId` paying.
    public init(memberIds: [String], payerId: String) {
        self.memberIds = memberIds
        self.payerId = payerId
        self.includedMemberIds = Set(memberIds)
    }

    // MARK: - Parsed values

    /// The typed amount, resolving a `+`/`-` expression; `nil` while it
    /// doesn't fully parse.
    public var amountMinor: Int64? { MoneyFormat.evaluate(amountText) }

    public var payersTotal: Int64 {
        memberIds.reduce(Int64(0)) { $0 + (MoneyFormat.minorUnits(from: payerAmountText[$1] ?? "") ?? 0) }
    }

    /// The entered payers, zero/blank rows dropped, in member order.
    public var enteredPayers: [ExpensePayment] {
        memberIds.compactMap { id in
            guard let value = MoneyFormat.minorUnits(from: payerAmountText[id] ?? ""), value > 0 else { return nil }
            return ExpensePayment(memberId: id, amountMinor: value)
        }
    }

    public var exactSplitsTotal: Int64 {
        memberIds.reduce(Int64(0)) { $0 + (MoneyFormat.minorUnits(from: exactAmountText[$1] ?? "") ?? 0) }
    }

    /// Whole-number percent for a member; blank or non-numeric is `0`.
    public func percent(for memberId: String) -> Int {
        Int(percentText[memberId]?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
    }

    public var percentTotal: Int {
        memberIds.reduce(0) { $0 + percent(for: $1) }
    }

    /// Whole-number share weight for a member; blank or non-numeric is `0`,
    /// never negative.
    public func share(for memberId: String) -> Int {
        max(0, Int(shareText[memberId]?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0)
    }

    public var shareTotal: Int {
        memberIds.reduce(0) { $0 + share(for: $1) }
    }

    public var taxMinor: Int64 { MoneyFormat.minorUnits(from: taxText) ?? 0 }
    public var tipMinor: Int64 { MoneyFormat.minorUnits(from: tipText) ?? 0 }

    public var itemizedTotal: Int64 {
        ItemizedSplitMath.total(itemDrafts, taxMinor: taxMinor, tipMinor: tipMinor)
    }

    /// Who the remainder of an uneven split lands on — the payer, or with
    /// several payers the largest contributor (ties → earliest in member
    /// order), falling back to the first member.
    public var remainderRecipient: String {
        guard isMultiPayer else { return payerId }
        return enteredPayers.max { $0.amountMinor < $1.amountMinor }?.memberId ?? memberIds.first ?? payerId
    }

    // MARK: - Readiness

    /// Whether the money half of the form is complete enough to save — the
    /// split/payer half of the view's `canSubmit` (it adds the description
    /// check itself).
    public var canResolve: Bool {
        guard let amountMinor, amountMinor > 0 else { return false }
        if isMultiPayer {
            guard payersTotal == amountMinor, !enteredPayers.isEmpty else { return false }
        } else {
            guard !payerId.isEmpty else { return false }
        }

        switch splitType {
        case .equal:
            return !includedMemberIds.isEmpty
        case .exact:
            return exactSplitsTotal == amountMinor
        case .percentage:
            return percentTotal == 100
        case .shares:
            return shareTotal > 0
        case .itemized:
            guard !itemDrafts.isEmpty, itemizedTotal == amountMinor else { return false }
            return itemDrafts.allSatisfy { item in
                (MoneyFormat.minorUnits(from: item.amountText) ?? 0) > 0 && !item.participantIds.isEmpty
            }
        }
    }

    /// The live per-member amounts for a `.shares` split at the current
    /// amount, matching what `resolve()` will send (remainder rule included).
    public func previewShareSplits() -> [ExpenseSplit] {
        guard let amountMinor else { return [] }
        let weights = memberIds
            .map { (memberId: $0, weight: share(for: $0)) }
            .filter { $0.weight > 0 }
        guard !weights.isEmpty else { return [] }
        return Validation.sharesSplit(amountMinor: amountMinor, weights: weights, remainderRecipient: remainderRecipient)
    }

    // MARK: - Resolve

    /// Exactly what the request carries for the money half of an expense.
    public struct Resolution: Equatable, Sendable {
        public let amountMinor: Int64
        public let payers: [ExpensePayment]
        public let splits: [ExpenseSplit]
        /// Only for `.itemized`.
        public let items: [LineItem]?
        /// Only for `.shares` — the raw weights, for re-edit.
        public let shares: [ShareWeight]?
        /// Only for `.itemized`, and only when positive.
        public let taxMinor: Int64?
        public let tipMinor: Int64?
    }

    /// Turns the draft into payers + splits, running the same checks the
    /// server enforces (`DESIGN.md` §6) so a bad draft fails here with a clear
    /// error rather than on the network.
    public func resolve() throws -> Resolution {
        guard let amountMinor, amountMinor > 0 else { throw ValidationError.invalidAmount(amountMinor ?? 0) }

        let payers: [ExpensePayment] = isMultiPayer
            ? enteredPayers
            : [ExpensePayment(memberId: payerId, amountMinor: amountMinor)]
        try Validation.validatePayersSum(amountMinor: amountMinor, payers: payers)

        let splits: [ExpenseSplit]
        var items: [LineItem]?
        var shares: [ShareWeight]?
        switch splitType {
        case .equal:
            let included = memberIds.filter { includedMemberIds.contains($0) }
            guard !included.isEmpty else { throw ValidationError.emptySplits }
            splits = Validation.equalSplit(amountMinor: amountMinor, memberIds: included, remainderRecipient: remainderRecipient)
        case .exact:
            splits = memberIds.compactMap { id in
                guard let value = MoneyFormat.minorUnits(from: exactAmountText[id] ?? ""), value > 0 else { return nil }
                return ExpenseSplit(memberId: id, amountMinor: value)
            }
        case .percentage:
            // Percentages are resolved to exact minor units here — the wire
            // only ever carries `amountMinor` shares (DESIGN.md §6).
            let weights = memberIds
                .map { (memberId: $0, weight: percent(for: $0)) }
                .filter { $0.weight > 0 }
            guard !weights.isEmpty else { throw ValidationError.emptySplits }
            splits = Validation.percentageSplit(amountMinor: amountMinor, weights: weights, remainderRecipient: remainderRecipient)
        case .shares:
            let entered = memberIds
                .map { (memberId: $0, weight: share(for: $0)) }
                .filter { $0.weight > 0 }
            let weights = entered.map { ShareWeight(memberId: $0.memberId, weight: $0.weight) }
            try Validation.validateShares(weights: weights, validMemberIds: Set(memberIds))
            shares = weights
            splits = Validation.sharesSplit(amountMinor: amountMinor, weights: entered, remainderRecipient: remainderRecipient)
        case .itemized:
            // Participants in group order, so the result doesn't depend on
            // tap order.
            let resolved = itemDrafts.map { draft in
                LineItem(
                    id: draft.id,
                    name: draft.name.trimmingCharacters(in: .whitespaces),
                    amountMinor: MoneyFormat.minorUnits(from: draft.amountText) ?? 0,
                    participantIds: memberIds.filter { draft.participantIds.contains($0) }
                )
            }
            try Validation.validateItems(
                amountMinor: amountMinor, items: resolved, validMemberIds: Set(memberIds),
                taxMinor: taxMinor, tipMinor: tipMinor
            )
            items = resolved
            splits = Validation.itemizedSplit(
                items: resolved, remainderRecipient: remainderRecipient,
                taxMinor: taxMinor, tipMinor: tipMinor
            )
        }

        try Validation.validateSplitsSum(amountMinor: amountMinor, splits: splits)

        return Resolution(
            amountMinor: amountMinor,
            payers: payers,
            splits: splits,
            items: items,
            shares: shares,
            taxMinor: (splitType == .itemized && taxMinor > 0) ? taxMinor : nil,
            tipMinor: (splitType == .itemized && tipMinor > 0) ? tipMinor : nil
        )
    }

    // MARK: - Re-opening a saved expense

    /// Rehydrates a saved expense into a draft — for editing, or for
    /// duplicating (`keepItemIds: false` gives line items fresh ids, since a
    /// duplicate is a new expense).
    ///
    /// - Parameter fallbackPayerId: the single-payer picker's value when the
    ///   expense has several payers (or, defensively, none).
    public init(rehydrating expense: Expense, memberIds: [String], fallbackPayerId: String, keepItemIds: Bool) {
        self.init(memberIds: memberIds, payerId: fallbackPayerId)
        amountText = MoneyFormat.plainString(minorUnits: expense.amountMinor)

        if expense.payers.count > 1 {
            isMultiPayer = true
            payerAmountText = Dictionary(
                uniqueKeysWithValues: expense.payers.map { ($0.memberId, MoneyFormat.plainString(minorUnits: $0.amountMinor)) }
            )
        } else {
            payerId = expense.payerId ?? fallbackPayerId
        }

        splitType = expense.splitType
        includedMemberIds = Set(expense.splits.map(\.memberId))
        exactAmountText = Dictionary(
            uniqueKeysWithValues: expense.splits.map { ($0.memberId, MoneyFormat.plainString(minorUnits: $0.amountMinor)) }
        )

        if expense.splitType == .percentage, expense.amountMinor > 0 {
            // Percentages aren't stored — only the resolved minor-unit shares.
            // Back-computed per member, rounded.
            var percent: [String: String] = [:]
            for split in expense.splits {
                let pct = (Double(split.amountMinor) / Double(expense.amountMinor) * 100).rounded()
                percent[split.memberId] = String(Int(pct))
            }
            percentText = percent
        }

        if expense.splitType == .itemized, let items = expense.items {
            itemDrafts = items.map { item in
                ItemDraft(
                    id: keepItemIds ? item.id : UUID().uuidString,
                    name: item.name,
                    amountText: MoneyFormat.plainString(minorUnits: item.amountMinor),
                    participantIds: Set(item.participantIds)
                )
            }
            taxText = expense.taxMinor.map { MoneyFormat.plainString(minorUnits: $0) } ?? ""
            tipText = expense.tipMinor.map { MoneyFormat.plainString(minorUnits: $0) } ?? ""
        }

        if expense.splitType == .shares, let shares = expense.shares {
            shareText = Dictionary(uniqueKeysWithValues: shares.map { ($0.memberId, String($0.weight)) })
        }
    }
}
