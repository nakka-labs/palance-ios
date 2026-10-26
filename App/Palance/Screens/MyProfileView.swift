import PhotosUI
import SwiftUI

/// The signed-in user's own profile, reached from the top row of Settings
/// (`DESIGN_BIBLE.md` §9 rule 9 — cover band, name as the Title, then flat
/// rows). Photo, name, and sign-in method used to sit inline in Settings'
/// Account section as a mix of an icon'd status line, an avatar row, a text
/// field, and blue text buttons.
struct MyProfileView: View {
    let auth: AuthViewModel

    @Environment(\.avatarImageLoader) private var avatarLoader
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var photoError: String?
    @State private var nameDraft = ""
    @State private var showingPhotoViewer = false

    /// The identity's central name (`CHECKLIST.md` R1) once it has one, else
    /// their name in the most-recently-claimed group, else a placeholder.
    private var myDisplayName: String {
        auth.myDisplayName ?? auth.groups.first?.displayName ?? "You"
    }

    private var trimmedNameDraft: String { nameDraft.trimmingCharacters(in: .whitespaces) }
    private var isNameDirty: Bool { !trimmedNameDraft.isEmpty && trimmedNameDraft != (auth.myDisplayName ?? "") }

    var body: some View {
        List {
            headerSection

            Section {
                LabeledContent("Name") {
                    HStack {
                        TextField("Name", text: $nameDraft, prompt: Text("Your Name"))
                            .multilineTextAlignment(.trailing)
                        if auth.isUpdatingDisplayName {
                            ProgressView()
                        } else if isNameDirty {
                            Button("Save") { Task { await auth.setDisplayName(trimmedNameDraft) } }
                        }
                    }
                }
                LabeledContent("Signed In With", value: auth.session?.provider == .google ? "Google" : "Apple")
            }

            photoSection

            Section {
                Button { auth.signOut() } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .labelStyle(.row)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Surface.canvas)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: auth.myDisplayName, initial: true) { _, newValue in
            // Don't clobber an in-progress edit if the fetch resolves late.
            if nameDraft.isEmpty { nameDraft = newValue ?? "" }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await handlePickedPhoto(item) }
        }
        .fullScreenCover(isPresented: $showingPhotoViewer) {
            if let key = auth.myAvatarKey {
                ReceiptViewer(key: key, accessToken: nil)
            }
        }
    }

    /// Cover band + your name (`DESIGN_BIBLE.md` §9 rule 9).
    @ViewBuilder
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                ProfileCoverBand(name: myDisplayName, avatarKey: auth.myAvatarKey) {
                    showingPhotoViewer = true
                }
                Text(myDisplayName)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                    .padding(.horizontal)
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    /// Add / change / remove your photo; errors in the footer.
    @ViewBuilder
    private var photoSection: some View {
        Section {
            PhotosPicker(
                selection: $pickedPhoto,
                matching: .images,
                preferredItemEncoding: .compatible,
                photoLibrary: .shared()
            ) {
                HStack {
                    Label(auth.myAvatarKey == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                        .labelStyle(.row)
                    Spacer()
                    if auth.isUpdatingAvatar { ProgressView() }
                }
            }
            .disabled(auth.isUpdatingAvatar)

            if auth.myAvatarKey != nil {
                Button {
                    Task {
                        if let key = await auth.removeAvatar() {
                            avatarLoader?.invalidate(key)
                        }
                    }
                } label: {
                    Label("Remove Photo", systemImage: "person.crop.circle.badge.minus")
                        .labelStyle(.row)
                }
                .disabled(auth.isUpdatingAvatar)
            }
        } footer: {
            if let message = photoError ?? auth.errorMessage {
                Text(message).foregroundStyle(.red)
            }
        }
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        photoError = nil
        defer { pickedPhoto = nil }

        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let picked = UIImage(data: data),
            let jpeg = ProfileImage.jpegData(from: picked),
            let compressed = UIImage(data: jpeg)
        else {
            photoError = "Couldn't read that photo. Try another."
            return
        }

        if let key = await auth.setAvatar(jpegData: jpeg) {
            // Show the new photo immediately, everywhere, without a round-trip.
            avatarLoader?.prime(key, with: compressed)
        }
        // A failure leaves `auth.errorMessage` set (shown in the footer).
    }
}
