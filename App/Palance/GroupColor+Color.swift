import SwiftUI
import PalanceKit

extension GroupColor {
    /// The group's accent as a SwiftUI `Color` — a thin wrapper around
    /// PalanceKit's pure `GroupColor.rgb(forId:)`, same split as
    /// `MemberColor.color(for:)`.
    static func color(forId groupId: String) -> Color {
        swatch(forId: groupId, lightness: lightness)
    }

    /// A slightly darker take on the group's hue (`oklch 50%`, the
    /// `MemberColor` band) for a solid badge that carries white text — the
    /// header-accent `color(forId:)` at `55%` is a touch light for that.
    static func badge(forId groupId: String) -> Color {
        swatch(forId: groupId, lightness: 0.50)
    }

    /// The group's hue converted to a SwiftUI `Color` at a given point on the
    /// OKLCH lightness scale — `color(forId:)` and `badge(forId:)` differ only
    /// in that constant, so the `OKLCH.sRGB` call lives here once.
    private static func swatch(forId groupId: String, lightness: Double) -> Color {
        let c = OKLCH.sRGB(hue: hue(forId: groupId), lightness: lightness, chroma: chroma)
        return Color(red: c.red, green: c.green, blue: c.blue)
    }

    /// A flat, low-chroma fill in the group's hue (`DESIGN_BIBLE.md` §9 rule
    /// 1 — the focal surface is flat: no gradient, no pattern, no shadow). It
    /// carries the group's identity on the balance hero and behind a loading
    /// cover photo; resolves per light/dark like `Surface`'s tiers, at about
    /// a quarter of the accent's chroma so text on it stays calm.
    static func tint(forId groupId: String) -> Color {
        let h = hue(forId: groupId)
        return Color(uiColor: UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            let c = OKLCH.sRGB(hue: h, lightness: dark ? 0.27 : 0.945, chroma: dark ? 0.045 : 0.035)
            return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
        })
    }
}
