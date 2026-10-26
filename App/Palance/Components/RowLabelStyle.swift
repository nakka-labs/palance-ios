import SwiftUI

/// The row standard (`DESIGN_BIBLE.md` §9 rule 4): a leading SF Symbol in a
/// fixed 28pt frame, monochrome `.secondary` — never accent-tinted, never
/// multicolor — then a `.body` label. Fixed width so labels line up down a
/// list regardless of each glyph's own width. A `NavigationLink` adds the
/// chevron itself; a trailing value goes in the row, not in this style.
struct RowLabelStyle: LabelStyle {
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.monochrome)
                .frame(width: iconWidth)
            configuration.title
                .foregroundStyle(.primary)
        }
    }
}

extension LabelStyle where Self == RowLabelStyle {
    /// `Label("Spending Insights", systemImage: "chart.bar").labelStyle(.row)`
    static var row: RowLabelStyle { RowLabelStyle() }
}
