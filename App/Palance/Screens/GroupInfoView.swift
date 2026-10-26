import SwiftUI
import PhotosUI
import PalanceKit

/// Join code + invite link, and the cover image — pulled out of
/// `GroupSettingsView`'s own `Form` into their own screen (`CHECKLIST.md`
/// R3: that Form covered too many concerns in one place). Reached the same
/// way `SettingsView` reaches `MySpendingView` — a plain `NavigationLink`
/// inside a `Section`, since `GroupSettingsView` is already hosted in its
/// own `NavigationStack` by `GroupHomeView`'s `.sheet`.
///
/// **Scope note vs. the original R3 ticket text**: that ticket assumed an
/// "Export" row lived in this Form too — it doesn't; CSV/JSON/PDF export
/// lives only in `GroupHomeView`'s own "…" menu. So this pulls out Join
/// Code + Cover Image instead (the two sections that were actually here),
/// which still cuts the top-level Form from ~9 sections to ~7.
struct GroupInfoView: View {
    let groupId: String
    let joinCode: String
    /// `state.group.coverKey` — re-read on every re-render the same way
    /// `GroupSettingsView`'s own `state` does, so a change here (upload,
    /// remove) is visible the moment the parent's `onChanged` refetch lands.
    let coverKey: String?
    let client: PalanceClient
    let accessToken: String?
    /// Needed by the media-presign endpoint for the cover-image upload
    /// (`CHECKLIST.md` "Group cover image").
    let sessionToken: String?
    let onChanged: () -> Void

    @State private var pickedCover: PhotosPickerItem?
    @State private var isSavingCover = false
    @State private var errorMessage: String?
    @Environment(\.avatarImageLoader) private var avatarLoader

    private var coverImageKey: String { "groups/\(groupId)/cover" }

    var body: some View {
        Form {
            joinCodeSection
            coverImageSection
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Group Info")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickedCover) { _, item in
            guard let item else { return }
            Task { await handlePickedCover(item) }
        }
    }

    // Join code as a key-value row and every action as a row-standard row
    // (`DESIGN_BIBLE.md` §9 rules 4-5).
    private var joinCodeSection: some View {
        Section {
            LabeledContent("Join Code") {
                HStack(spacing: 12) {
                    Text(joinCode)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = joinCode
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Copy Join Code")
                }
            }
            ShareLink(item: AppConfig.groupShareURL(groupId: groupId, accessToken: accessToken)) {
                Label("Share Invite Link", systemImage: "square.and.arrow.up")
                    .labelStyle(.row)
            }
        } footer: {
            Text("Anyone with this code can join the group from \"Join with a Code.\"")
        }
    }

    /// The cover itself as a full-width band (same shape as a profile's
    /// `ProfileCoverBand`, §9 rule 9), then its actions as rows — was a
    /// 72×48 thumbnail beside a text button.
    @ViewBuilder
    private var coverImageSection: some View {
        Section {
            Group {
                if coverKey != nil {
                    GroupCoverImage(groupId: groupId, coverKey: coverImageKey, accessToken: accessToken)
                } else {
                    GroupColor.tint(forId: groupId)
                        .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.tertiary))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipped()
            .listRowInsets(EdgeInsets())

            PhotosPicker(
                selection: $pickedCover,
                matching: .images,
                preferredItemEncoding: .compatible,
                photoLibrary: .shared()
            ) {
                HStack {
                    Label(coverKey == nil ? "Add Cover Image" : "Change Cover", systemImage: "photo")
                        .labelStyle(.row)
                    Spacer()
                    if isSavingCover { ProgressView() }
                }
            }
            .disabled(isSavingCover)

            if coverKey != nil {
                Button { Task { await removeCover() } } label: {
                    Label("Remove Cover", systemImage: "trash")
                        .labelStyle(.destructiveRow)
                }
                .disabled(isSavingCover)
            }
        } header: {
            Text("Cover Image")
        } footer: {
            Text("Shown on the group's card and at the top of the group. Any member can change it.")
        }
    }

    private func handlePickedCover(_ item: PhotosPickerItem) async {
        errorMessage = nil
        defer { pickedCover = nil }
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let picked = UIImage(data: data),
            let jpeg = CoverImage.jpegData(from: picked),
            let compressed = UIImage(data: jpeg)
        else {
            errorMessage = "Couldn't read that photo. Try another."
            return
        }

        isSavingCover = true
        defer { isSavingCover = false }
        do {
            guard let sessionToken else {
                errorMessage = "Sign in to set a cover image."
                return
            }
            let ticket = try await client.presignMediaUpload(
                .groupCover, contentType: "image/jpeg", contentLength: jpeg.count,
                groupId: groupId, token: sessionToken, accessToken: accessToken
            )
            try await client.uploadImage(jpeg, using: ticket)
            _ = try await client.updateGroup(groupId: groupId, coverImage: .commit, accessToken: accessToken)
            avatarLoader?.prime(coverImageKey, with: compressed) // show it instantly everywhere
            onChanged()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func removeCover() async {
        errorMessage = nil
        isSavingCover = true
        defer { isSavingCover = false }
        do {
            _ = try await client.updateGroup(groupId: groupId, coverImage: .remove, accessToken: accessToken)
            avatarLoader?.invalidate(coverImageKey)
            onChanged()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }
}
