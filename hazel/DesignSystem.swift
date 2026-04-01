import SwiftUI
import AppKit

// ─────────────────────────────────────────────────────────────
// MARK: - Design Tokens
// ─────────────────────────────────────────────────────────────

enum Design {
    static let iconGradient = LinearGradient(
        colors: [.primary.opacity(0.65), .primary.opacity(0.28)],
        startPoint: .top, endPoint: .bottom)
    
    static let iconGradientDim = LinearGradient(
        colors: [.primary.opacity(0.42), .primary.opacity(0.18)],
        startPoint: .top, endPoint: .bottom)
    
    static let accentGradient = LinearGradient(
        colors: [.accentColor.opacity(0.90), .accentColor.opacity(0.50)],
        startPoint: .top, endPoint: .bottom)

    static let glassCornerRadius: CGFloat = 8
    static let rowCornerRadius: CGFloat = 6

    static func geist(_ size: CGFloat) -> Font {
        Font.custom("GeistPixel-Square", size: size)
    }
}

extension Color {
    static let neonRed    = Color(red: 0.95, green: 0.20, blue: 0.38)
    static let neonOrange = Color(red: 0.95, green: 0.52, blue: 0.05)
    static let neonYellow = Color(red: 0.90, green: 0.88, blue: 0.08)
    static let neonGreen  = Color(red: 0.10, green: 0.88, blue: 0.46)
    static let neonBlue   = Color(red: 0.12, green: 0.50, blue: 0.95)
}

// ─────────────────────────────────────────────────────────────
// MARK: - View Modifiers
// ─────────────────────────────────────────────────────────────

struct GlassEffectModifier<S: Shape>: ViewModifier {
    var material: NSVisualEffectView.Material
    var shape: S
    
    func body(content: Content) -> some View {
        content
            .background(
                VisualEffectView(material: material, blendingMode: .withinWindow)
                    .clipShape(shape)
            )
            .overlay(
                shape
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}

extension View {
    func glassEffect<S: Shape>(_ material: NSVisualEffectView.Material = .contentBackground, in shape: S) -> some View {
        self.modifier(GlassEffectModifier(material: material, shape: shape))
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - NSVisualEffectView Wrapper
// ─────────────────────────────────────────────────────────────

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Components
// ─────────────────────────────────────────────────────────────

struct PremiumButton: ButtonStyle {
    @State private var hovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.primary.opacity(hovered ? (configuration.isPressed ? 0.15 : 0.08) : 0.05))
                    .animation(.easeInOut(duration: 0.12), value: hovered)
            )
            .onHover { hovered = $0 }
    }
}

struct IconCircle: View {
    let systemName: String
    var tint: Color? = nil
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.primary.opacity(0.05))
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint.map { AnyShapeStyle(LinearGradient(colors: [$0, $0.opacity(0.55)], startPoint: .top, endPoint: .bottom)) } ?? AnyShapeStyle(Design.iconGradient))
        }
        .frame(width: 28, height: 28)
    }
}
