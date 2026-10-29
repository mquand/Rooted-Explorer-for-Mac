import SwiftUI

struct UpdateBanner: View {
    @EnvironmentObject private var updates: UpdateService
    let release: GitHubRelease

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Rooted \(release.displayVersion) is available")
                    .font(.headline)
                Text(release.summary)
                    .font(.caption)
                    .lineLimit(2)
                    .opacity(0.9)
            }

            Spacer(minLength: 8)

            if updates.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }

            Button("Update") {
                Task { await updates.downloadAndInstall(release) }
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundColor(.blue)
            .disabled(updates.isBusy)

            Button("Later") {
                updates.dismissBanner()
            }
            .foregroundColor(.white)

            Button("Skip") {
                updates.skip(release)
            }
            .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.34, blue: 0.86),
                    Color(red: 0.04, green: 0.60, blue: 0.64)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}
