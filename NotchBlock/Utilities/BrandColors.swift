import AppKit
import SwiftUI

/// Adaptive minimalist frosted-glass color palette:
/// - Dark mode: obsidian black + deep purple
/// - Light mode: crisp white + soft pale green
enum BrandColors {
    // MARK: - Dynamic NSColors (shared by AppKit windows & SwiftUI views)

    static let canvasNS = dynamicNSColor(
        light: (1.00, 1.00, 1.00, 1.0),
        dark: (0.039, 0.035, 0.055, 1.0)
    )

    static let canvasGlassNS = dynamicNSColor(
        light: (0.996, 1.000, 0.997, 0.72),
        dark: (0.039, 0.031, 0.063, 0.68)
    )

    static let panelGlassNS = dynamicNSColor(
        light: (0.984, 0.998, 0.988, 0.76),
        dark: (0.047, 0.035, 0.078, 0.74)
    )

    static let surfaceNS = dynamicNSColor(
        light: (0.945, 0.984, 0.958, 0.66),
        dark: (0.094, 0.071, 0.149, 0.58)
    )

    static let surfaceSubtleNS = dynamicNSColor(
        light: (0.878, 0.957, 0.906, 0.66),
        dark: (0.141, 0.102, 0.227, 0.56)
    )

    static let hairlineNS = dynamicNSColor(
        light: (0.776, 0.894, 0.816, 0.75),
        dark: (0.282, 0.204, 0.459, 0.55)
    )

    static let specularTopNS = dynamicNSColor(
        light: (1.000, 1.000, 1.000, 0.88),
        dark: (0.769, 0.710, 0.992, 0.26)
    )

    static let specularBottomNS = dynamicNSColor(
        light: (0.678, 0.863, 0.745, 0.42),
        dark: (0.427, 0.157, 0.851, 0.14)
    )

    static let accentNS = dynamicNSColor(
        light: (0.455, 0.765, 0.576, 1.0),
        dark: (0.427, 0.157, 0.851, 1.0)
    )

    static let accentFillNS = dynamicNSColor(
        light: (0.776, 0.922, 0.827, 0.88),
        dark: (0.357, 0.129, 0.714, 0.88)
    )

    static let accentOnFillNS = dynamicNSColor(
        light: (0.086, 0.259, 0.169, 1.0),
        dark: (0.961, 0.953, 1.000, 1.0)
    )

    static let accentSoftNS = dynamicNSColor(
        light: (0.827, 0.941, 0.867, 0.72),
        dark: (0.427, 0.157, 0.851, 0.24)
    )

    static let accentBorderNS = dynamicNSColor(
        light: (0.478, 0.769, 0.584, 0.62),
        dark: (0.655, 0.545, 0.980, 0.45)
    )

    static let accentTextNS = dynamicNSColor(
        light: (0.204, 0.494, 0.333, 1.0),
        dark: (0.686, 0.584, 0.984, 1.0)
    )

    static let textPrimaryNS = dynamicNSColor(
        light: (0.075, 0.145, 0.106, 1.0),
        dark: (0.957, 0.949, 0.996, 1.0)
    )

    static let textSecondaryNS = dynamicNSColor(
        light: (0.337, 0.439, 0.376, 1.0),
        dark: (0.635, 0.596, 0.753, 1.0)
    )

    static let textTertiaryNS = dynamicNSColor(
        light: (0.549, 0.643, 0.584, 1.0),
        dark: (0.424, 0.384, 0.541, 1.0)
    )

    static let missedNS = dynamicNSColor(
        light: (0.788, 0.302, 0.302, 1.0),
        dark: (0.886, 0.384, 0.443, 1.0)
    )

    static let breakAccentNS = dynamicNSColor(
        light: (0.525, 0.761, 0.616, 1.0),
        dark: (0.514, 0.431, 0.690, 1.0)
    )

    static let overlayScrimNS = dynamicNSColor(
        light: (0.961, 0.992, 0.973, 0.66),
        dark: (0.024, 0.016, 0.043, 0.72)
    )

    // MARK: - SwiftUI Colors

    static let canvas = Color(nsColor: canvasNS)
    static let canvasGlass = Color(nsColor: canvasGlassNS)
    static let panelGlass = Color(nsColor: panelGlassNS)
    static let surface = Color(nsColor: surfaceNS)
    static let surfaceSubtle = Color(nsColor: surfaceSubtleNS)
    static let hairline = Color(nsColor: hairlineNS)
    static let specularTop = Color(nsColor: specularTopNS)
    static let specularBottom = Color(nsColor: specularBottomNS)

    static let accent = Color(nsColor: accentNS)
    static let accentFill = Color(nsColor: accentFillNS)
    static let accentOnFill = Color(nsColor: accentOnFillNS)
    static let accentSoft = Color(nsColor: accentSoftNS)
    static let accentBorder = Color(nsColor: accentBorderNS)
    static let accentText = Color(nsColor: accentTextNS)

    static let textPrimary = Color(nsColor: textPrimaryNS)
    static let textSecondary = Color(nsColor: textSecondaryNS)
    static let textTertiary = Color(nsColor: textTertiaryNS)

    static let active = accentText
    static let pending = textSecondary
    static let completed = textTertiary
    static let missed = Color(nsColor: missedNS)
    static let breakAccent = Color(nsColor: breakAccentNS)
    static let overlayScrim = Color(nsColor: overlayScrimNS)

    // MARK: - Semantic Mapping

    static func color(for block: TimeBlock, isActive: Bool) -> Color {
        if block.isBreak { return breakAccent }
        switch block.status {
        case .pending:   return isActive ? active : pending
        case .completed: return completed
        case .missed:    return missed
        }
    }

    static func heatmapColor(rate: Double, count: Int) -> Color {
        guard count > 0 else { return surfaceSubtle }
        if rate >= 0.8 { return accent }
        if rate >= 0.5 { return accent.opacity(0.65) }
        if rate > 0 { return accent.opacity(0.35) }
        return surfaceSubtle
    }

    private static func dynamicNSColor(
        light: (CGFloat, CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        }
    }
}
