import Foundation

enum TilePresentationResolver {
    static func usesAppIconLayout(profileUsesAppIcons: Bool,
                                  presentationUsesAppIcons: Bool?) -> Bool {
        presentationUsesAppIcons ?? profileUsesAppIcons
    }

    static func highlightFrame(usesAppIconLayout: Bool,
                               frameSize: CGSize,
                               iconHeight: CGFloat,
                               edgeInsets: CGFloat,
                               scale: CGFloat) -> CGRect {
        guard usesAppIconLayout else { return CGRect(origin: .zero, size: frameSize) }
        return CGRect(
            x: 0,
            y: 0,
            width: frameSize.width,
            height: iconHeight + edgeInsets * scale * 2)
    }

    static func iconSize(usesAppIconLayout: Bool,
                         baseIconSize: CGFloat,
                         minimumTileWidth: CGFloat,
                         edgeInsets: CGFloat) -> CGSize {
        guard usesAppIconLayout else {
            return CGSize(width: baseIconSize, height: baseIconSize)
        }
        let frameWidth = baseIconSize + edgeInsets * 2
        guard minimumTileWidth > frameWidth else {
            return CGSize(width: baseIconSize, height: baseIconSize)
        }
        let iconSize = max(frameWidth, minimumTileWidth).rounded() - edgeInsets * 2
        return CGSize(width: iconSize, height: iconSize)
    }
}
