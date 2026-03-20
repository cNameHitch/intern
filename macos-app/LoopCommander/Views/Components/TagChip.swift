import SwiftUI

/// Tag chip with optional remove button (for editor context).
struct TagChip: View {
    let text: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        if let onRemove = onRemove {
            Button(action: onRemove) {
                HStack(spacing: 4) {
                    Text(text)
                    Text("\u{2715}")
                }
                .font(.lcTag)
                .foregroundColor(.lcAccentLight)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.lcAccentBg)
                .cornerRadius(LCRadius.badge)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tag: \(text)")
            .accessibilityHint("Activate to remove")
        } else {
            // Read-only tag (in detail view)
            Text(text)
                .font(.lcTag)
                .foregroundColor(.lcAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.lcTagBg)
                .cornerRadius(LCRadius.badge)
                .accessibilityLabel("Tag: \(text)")
        }
    }
}
