import SwiftUI

struct LCPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lcButton)
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(Color.lcAccent)
            .cornerRadius(LCRadius.button)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct LCSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.5))
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.button)
                    .stroke(Color.lcBorderInput, lineWidth: 1)
            )
            .cornerRadius(LCRadius.button)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct LCDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lcButtonSmall)
            .foregroundColor(.lcRed)
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.button)
                    .stroke(Color.lcRedBorder, lineWidth: 1)
            )
            .cornerRadius(LCRadius.button)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct LCToolbarButtonStyle: ButtonStyle {
    var foreground: Color = .white.opacity(0.6)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lcButtonSmall)
            .foregroundColor(foreground)
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.button)
                    .stroke(Color.lcBorderInput, lineWidth: 1)
            )
            .cornerRadius(LCRadius.button)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
