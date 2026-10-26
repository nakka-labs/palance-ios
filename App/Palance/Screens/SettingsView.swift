import SwiftUI
import PalanceKit

/// Account settings — a top-level tab (`CHECKLIST.md` UX audit [6]; used to be
/// a sheet reached from the start screen and Group Home's toolbar gear).
/// Sign in is mandatory (`MANDATORY_LOGIN_PLAN.md` Part 3) — this screen
/// still shows a sign-in prompt for the brief window between "signed out"
/// and "signed back in," plus — Apple Guideline 5.1.1(v) — "Delete Account"
/// once signed in. `ACCOUNTS_DESIGN.md` §10/§11.
struct SettingsView: View {
    let auth: AuthViewModel
    let knownGroups: KnownGroupsStoring
    /// Needed only for `MySpendingView`'s per-group state fetch
    /// (`CHECKLIST.md` D14) — this screen otherwise never talks to the
    /// network directly.
    let client: PalanceClient
    /// "Show tips again" (`CHECKLIST.md`) resets both of these.
    let onboarding: OnboardingStoring
    let coachMarks: CoachMarkStoring?
    /// Fires once, right after "Delete Account" actually succeeds — there's
    /// no sheet to dismiss anymore now that this is a tab, so `RootView`
    /// just uses it to switch back to the Home tab (which reacts to
    /// `auth.isSignedIn` on its own).
    let onDone: () -> Void

    @State private var confirmingDelete = false
    @State private var tipsResetConfirmation = false
    @State private var sheetError: String?
    @AppStorage("palance.theme") private var theme = AppTheme.system
    /// Which screen a returning user lands on (`CHECKLIST.md` "Settings:
    /// launch-screen preference"). `""` — the dashboard; a groupId — that
    /// group. Read on launch by `RootView.launchRoute`.
    @AppStorage("palance.launchGroupId") private var launchGroupId = ""

    private let deletionCaveat =
        "Your groups and expenses stay. You'll lose cross-device sync and can't recover this account."

    // Laid out per `DESIGN_BIBLE.md` §9: your profile as one row at the top
    // (photo, name, sign-in method, and Sign Out live on `MyProfileView` now);
    // every other row follows the row standard; the version is the last
    // section's footer rather than a fact row among menu rows; Delete Account
    // is a plain red row, last, with its consequence in the footer (it used
    // to be a red-captioned row under a red "Danger Zone" header).
    var body: some View {
        Form {
            accountSections

            appSection

            deleteSection
        }
        .alert("Tips Reset", isPresented: $tipsResetConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The walkthrough and every one-time tip will show again.")
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Delete your account?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { if await auth.deleteAccount() { onDone() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deletionCaveat)
        }
    }

    /// Signed in: your profile row, then My Spending + iCloud status. Signed out: the sign-in buttons.
    @ViewBuilder
    private var accountSections: some View {
        if auth.isSignedIn {
            Section {
                NavigationLink {
                    MyProfileView(auth: auth)
                } label: {
                    HStack(spacing: 12) {
                        MemberAvatar(name: myDisplayName, avatarKey: auth.myAvatarKey, size: 40)
                        Text(myDisplayName)
                    }
                }
            }

            Section {
                NavigationLink {
                    MySpendingView(client: client, knownGroups: knownGroups, auth: auth)
                } label: {
                    Label("My Spending", systemImage: "chart.pie")
                        .labelStyle(.row)
                }
                // `CloudKitGroupBackup` only ever runs for a claimed group
                // (`CHECKLIST.md` R15), so this is signed-in only too.
                CloudBackupStatusRow(knownGroups: knownGroups)
            }
        } else {
            signedOutSection
        }
    }

    /// Appearance, launch screen, tips.
    @ViewBuilder
    private var appSection: some View {
        Section {
            Picker(selection: $theme) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
            } label: {
                Label("Appearance", systemImage: "circle.lefthalf.filled")
                    .labelStyle(.row)
            }
            if auth.isSignedIn, !launchGroups.isEmpty {
                Picker(selection: $launchGroupId) {
                    Text("Dashboard").tag("")
                    ForEach(launchGroups) { group in
                        Text(Self.launchLabel(for: group)).tag(group.groupId)
                    }
                } label: {
                    Label("Open at Launch", systemImage: "house")
                        .labelStyle(.row)
                }
            }
            Button {
                onboarding.reset()
                coachMarks?.resetAll()
                tipsResetConfirmation = true
            } label: {
                Label("Show Tips Again", systemImage: "lightbulb")
                    .labelStyle(.row)
            }
        } footer: {
            if !auth.isSignedIn {
                Text("Palance \(Self.appVersion) · Nakka-Labs")
            }
        }
    }

    /// Delete Account — last, plain red row, consequence + version in the footer (§9 rule 8).
    @ViewBuilder
    private var deleteSection: some View {
        if auth.isSignedIn {
            Section {
                Button { confirmingDelete = true } label: {
                    HStack {
                        Label("Delete Account", systemImage: "person.crop.circle.badge.xmark")
                            .labelStyle(.destructiveRow)
                        Spacer()
                        if auth.isBusy { ProgressView() }
                    }
                }
                .disabled(auth.isBusy)
            } footer: {
                VStack(alignment: .leading, spacing: 12) {
                    if let message = auth.errorMessage {
                        Text(message).foregroundStyle(.red)
                    }
                    Text(deletionCaveat)
                    Text("Palance \(Self.appVersion) · Nakka-Labs")
                }
            }
        }
    }

    /// The brief window between "signed out" and "signed back in" — sign-in
    /// is mandatory (`MANDATORY_LOGIN_PLAN.md` Part 3), so this rarely shows.
    private var signedOutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                AppleSignInButton(
                    onCredential: { token, userID, authCode in
                        sheetError = nil
                        Task { await auth.signIn(identityToken: token, userID: userID, authorizationCode: authCode) }
                    },
                    onFailure: { sheetError = $0 }
                )
                .frame(height: 40)
                GoogleSignInButton(
                    onCredential: { token in
                        sheetError = nil
                        Task { await auth.signInWithGoogle(identityToken: token) }
                    },
                    onFailure: { sheetError = $0 }
                )
                .frame(height: 40)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Sign In")
        } footer: {
            if let message = auth.errorMessage ?? sheetError {
                Text(message).foregroundStyle(.red)
            } else {
                Text("Sign in so you don't lose your groups if you switch phones.")
            }
        }
    }

    /// The signed-in user's name for the profile row — the identity's central
    /// name (`CHECKLIST.md` R1) once it has one, else their name in the
    /// most-recently-claimed group, else a neutral placeholder.
    private var myDisplayName: String {
        auth.myDisplayName ?? auth.groups.first?.displayName ?? "You"
    }

    /// The known-groups list for the "Open at Launch" picker — same source and
    /// order (most-recently-opened first) as the start screen's list.
    private var launchGroups: [KnownGroup] { knownGroups.all() }

    /// A group's row label in the launch picker: its emoji (if any) + name,
    /// matching `GroupsListView`'s `"Group"` fallback for an unnamed group.
    static func launchLabel(for group: KnownGroup) -> String {
        let name = group.name.isEmpty ? "Group" : group.name
        if let emoji = group.emoji, !emoji.isEmpty { return "\(emoji) \(name)" }
        return name
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}
