import AppKit
import SwiftUI

/// Native AppKit vibrancy backdrop for genuine frosted-glass surfaces.
struct VisualEffectBackdrop: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

/// Frosted glass container combining native blur with adaptive tint and specular border.
struct FrostedGlassBackground: View {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var tint: Color = BrandColors.canvasGlass
    var cornerRadius: CGFloat = 0
    var showBorder: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            VisualEffectBackdrop(material: material, blendingMode: blendingMode)
            tint
        }
        .clipShape(shape)
        .overlay {
            if showBorder {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [BrandColors.specularTop, BrandColors.specularBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
        }
    }
}

/// Crisp 1px hairline divider matching the adaptive frosted palette.
struct MinimalHairline: View {
    var body: some View {
        Rectangle()
            .fill(BrandColors.hairline)
            .frame(height: 1)
    }
}

/// Primary rounded action button: frosted pale green in light mode, frosted deep purple in dark mode.
struct MinimalPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var cornerRadius: CGFloat = 8
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(BrandColors.accentOnFill)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                ZStack {
                    VisualEffectBackdrop(material: .popover, blendingMode: .withinWindow)
                    BrandColors.accentFill
                }
                .clipShape(shape)
            }
            .overlay(shape.strokeBorder(BrandColors.accentBorder, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1.0) : 0.45)
            .contentShape(shape)
    }
}

/// Quiet frosted secondary action button with specular hairline border.
struct MinimalSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var cornerRadius: CGFloat = 8
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 8
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isDestructive ? BrandColors.missed : BrandColors.textPrimary)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                ZStack {
                    VisualEffectBackdrop(material: .popover, blendingMode: .withinWindow)
                    configuration.isPressed ? BrandColors.surfaceSubtle : BrandColors.surface
                }
                .clipShape(shape)
            }
            .overlay(shape.strokeBorder(BrandColors.hairline, lineWidth: 1))
            .opacity(isEnabled ? 1.0 : 0.45)
            .contentShape(shape)
    }
}

/// Minimalist pill-style segmented selector over frosted glass.
struct MinimalSegmentedControl<Option: Hashable>: View {
    let options: [(value: Option, label: String)]
    @Binding var selection: Option

    var body: some View {
        let outerShape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let isSelected = selection == option.value
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        selection = option.value
                    }
                } label: {
                    Text(option.label)
                        .font(.caption.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? BrandColors.accentOnFill : BrandColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? BrandColors.accentFill : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background {
            ZStack {
                VisualEffectBackdrop(material: .popover, blendingMode: .withinWindow)
                BrandColors.surface
            }
            .clipShape(outerShape)
        }
        .overlay(outerShape.strokeBorder(BrandColors.hairline, lineWidth: 1))
    }
}

/// Shared frosted-glass card container modifier.
struct MinimalCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var fill: Color = BrandColors.surface
    var border: Color = BrandColors.hairline
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                ZStack {
                    VisualEffectBackdrop(material: .popover, blendingMode: blendingMode)
                    fill
                }
                .clipShape(shape)
            }
            .overlay(shape.strokeBorder(border, lineWidth: 1))
    }
}

/// Clean frosted single-line input box style for minimalist forms.
struct MinimalInputContainerModifier: ViewModifier {
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .textFieldStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(BrandColors.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    VisualEffectBackdrop(material: .popover, blendingMode: .withinWindow)
                    BrandColors.surface
                }
                .clipShape(shape)
            }
            .overlay(shape.strokeBorder(BrandColors.hairline, lineWidth: 1))
    }
}

extension View {
    func minimalCard(
        cornerRadius: CGFloat = 12,
        fill: Color = BrandColors.surface,
        border: Color = BrandColors.hairline,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    ) -> some View {
        modifier(MinimalCardModifier(cornerRadius: cornerRadius, fill: fill, border: border, blendingMode: blendingMode))
    }

    func minimalInput(cornerRadius: CGFloat = 8) -> some View {
        modifier(MinimalInputContainerModifier(cornerRadius: cornerRadius))
    }
}
