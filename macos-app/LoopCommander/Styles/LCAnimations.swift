import SwiftUI

extension Animation {
    /// General UI transition. JSX: transition "all 0.15s ease"
    static let lcQuick = Animation.easeInOut(duration: 0.15)
    /// Expand/collapse, modal appear. JSX: @keyframes fadeSlide 0.2s ease
    static let lcFadeSlide = Animation.easeOut(duration: 0.2)
    /// Running-task pulse. JSX: @keyframes pulse 0.5->1.0 opacity
    static let lcPulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
}

// fadeSlide transition: opacity 0->1, translateY -4->0
extension AnyTransition {
    static var lcFadeSlide: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)).animation(.lcFadeSlide),
            removal: .opacity.animation(.lcQuick)
        )
    }
}

// Modal shadow
extension View {
    /// Editor modal shadow. JSX: 0 24px 80px rgba(0,0,0,0.6)
    func lcModalShadow() -> some View {
        self.shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 24)
    }
}

// MARK: - Conditional Rotation for Running Status

struct ConditionalRotation: ViewModifier {
    let animate: Bool
    @State private var isRotating = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isRotating && animate ? 360 : 0))
            .animation(
                animate ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                value: isRotating
            )
            .onAppear { isRotating = true }
    }
}

// MARK: - LCBorder

enum LCBorder {
    /// 1px - Standard borders on cards, panels, inputs, dividers
    static let standard: CGFloat = 1
    /// 2px - Selected row left accent border
    static let selected: CGFloat = 2
}
