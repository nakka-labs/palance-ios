import SwiftUI

/// The occasional "back up your data" card on Group Home
/// (`FEATURE_BACKLOG.md` "Backup, in two tiers" — Tier 1). Reuses the
/// existing CSV export entirely: this just adds visibility for a share-sheet
/// path ("Save to Files", which already supports iCloud Drive and Google
/// Drive) that was previously buried in the "Share" menu. Recurs every 30
/// days rather than a one-time dismiss (`AuthViewModel.shouldShowBackupNudge`).
struct BackupNudgeCard: View {
    /// `nil` while the group state hasn't loaded yet — the card renders once
    /// there's actually something to export.
    let csvURL: URL?
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Back up your data", systemImage: "arrow.down.doc")
                    .labelStyle(.row)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Not now")
            }

            Text("Export a CSV and save it to Files — it already offers iCloud Drive and Google Drive. Palance keeps the real copy on the server either way.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let csvURL {
                ShareLink(item: csvURL) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                        .labelStyle(.row)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
