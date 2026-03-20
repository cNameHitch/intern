import SwiftUI

struct MetricCard: View {
    let label: String
    let value: String
    var sub: String? = nil
    var accent: Color = .lcTextPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.lcMetricLabel)
                .foregroundColor(.lcTextMuted)
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)
                .padding(.bottom, 6)

            Text(value)
                .font(.lcMetricValue)
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if let sub = sub {
                Text(sub)
                    .font(.lcMetricSub)
                    .foregroundColor(.lcTextSubtle)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .background(Color.lcSurfaceRaised)
        .overlay(
            RoundedRectangle(cornerRadius: LCRadius.card)
                .stroke(Color.lcBorder, lineWidth: LCBorder.standard)
        )
        .cornerRadius(LCRadius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityValue(sub ?? "")
    }
}
