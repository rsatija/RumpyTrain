import SwiftUI
import UIKit

enum AppTypography {
    struct FontToken {
        let size: CGFloat
        let weight: Font.Weight
        let monospacedDigits: Bool
    }

    private static let fontCandidates = [
        "InterVariable",
        "Inter",
        "Inter-Regular",
        "Inter-Medium",
        "Inter-SemiBold",
        "Inter-Bold",
        "InterVariable-Italic"
    ]

    private static let interFontFamily: String? = {
        fontCandidates.first { UIFont(name: $0, size: 12) != nil }
    }()

    private static let title = FontToken(size: 34, weight: .bold, monospacedDigits: false)
    private static let section = FontToken(size: 18, weight: .semibold, monospacedDigits: false)
    private static let body = FontToken(size: 16, weight: .regular, monospacedDigits: false)
    private static let caption = FontToken(size: 14, weight: .regular, monospacedDigits: false)
    private static let numericStatus = FontToken(size: 13, weight: .medium, monospacedDigits: true)
    private static let routeBadge = FontToken(size: 13, weight: .bold, monospacedDigits: false)
    private static let control = FontToken(size: 14, weight: .medium, monospacedDigits: false)

    private static func resolveFont(size: CGFloat, weight: Font.Weight, monospacedDigits: Bool) -> Font {
        let base: Font
        if let interFontFamily {
            base = Font.custom(interFontFamily, size: size, relativeTo: .body).weight(weight)
        } else {
            base = Font.system(size: size, weight: weight)
        }

        guard monospacedDigits else { return base }
        return base.monospacedDigit()
    }

    private static func resolve(_ token: FontToken, sizeOverride: CGFloat?) -> Font {
        let size = sizeOverride ?? token.size
        return resolveFont(size: size, weight: token.weight, monospacedDigits: token.monospacedDigits)
    }

    static func title(_ size: CGFloat? = nil) -> Font {
        resolve(title, sizeOverride: size)
    }

    static func section(_ size: CGFloat? = nil) -> Font {
        resolve(section, sizeOverride: size)
    }

    static func bodyText(_ size: CGFloat? = nil) -> Font {
        resolve(body, sizeOverride: size)
    }

    static func caption(_ size: CGFloat? = nil) -> Font {
        resolve(caption, sizeOverride: size)
    }

    static func numericStatus(_ size: CGFloat? = nil) -> Font {
        resolve(numericStatus, sizeOverride: size)
    }

    static func routeBadge(size: CGFloat) -> Font {
        resolve(routeBadge, sizeOverride: size)
    }

    static func control(_ size: CGFloat? = nil) -> Font {
        resolve(control, sizeOverride: size)
    }
}
