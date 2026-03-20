import SwiftUI

/// Banner shown when the daemon is not running.
struct DaemonBanner: View {
    let isConnected: Bool
    let onStartDaemon: () -> Void

    var body: some View {
        if !isConnected {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.lcAmber)

                Text("Daemon not running.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.lcTextPrimary)

                Button("Start Daemon") { onStartDaemon() }
                    .buttonStyle(.borderedProminent)
                    .tint(.lcAccent)
                    .controlSize(.small)

                Spacer()

                Text("Some features may be unavailable")
                    .font(.system(size: 11))
                    .foregroundColor(.lcTextMuted)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.lcAmber.opacity(0.1))
            .cornerRadius(LCRadius.card)
            .padding(.horizontal, 28)
            .transition(.lcFadeSlide)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Daemon not running. Activate Start Daemon button to start.")
        }
    }
}
