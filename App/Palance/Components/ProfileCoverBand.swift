import PalanceKit
import SwiftUI

/// The top of a profile screen (`DESIGN_BIBLE.md` §9 rule 9): a full-width
/// band showing the person's photo if they have one, otherwise a flat fill in
/// their member color with large initials. No card, no floating circle over a
/// banner — the band *is* the avatar at screen width. The person's name sits
/// below it as the screen's Title, placed by the caller.
struct ProfileCoverBand: View {
    let name: String
    let avatarKey: String?
    /// Tapping the band, when there's a photo to enlarge (`CHECKLIST.md` R7).
    var onTapPhoto: (() -> Void)?

    @Environment(\.avatarImageLoader) private var loader
    @State private var photo: UIImage?
    @ScaledMetric(relativeTo: .largeTitle) private var initialsSize: CGFloat = 64

    var body: some View {
        ZStack {
            MemberColor.color(for: name)
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Text(MemberAvatar.initials(from: name))
                    .font(.system(size: initialsSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { if photo != nil { onTapPhoto?() } }
        .accessibilityElement()
        .accessibilityLabel(photo == nil ? "" : "\(name)'s photo")
        .accessibilityAddTraits(photo != nil && onTapPhoto != nil ? .isButton : [])
        .accessibilityHidden(photo == nil)
        .task(id: TaskID(key: avatarKey, generation: loader?.generation ?? 0)) {
            guard let avatarKey, let loader else {
                photo = nil
                return
            }
            if let hit = loader.cached(avatarKey) {
                photo = hit
            } else {
                let resolved = await loader.load(avatarKey)
                withAnimation(.easeOut(duration: 0.2)) { photo = resolved }
            }
        }
    }

    private struct TaskID: Equatable {
        let key: String?
        let generation: Int
    }
}
