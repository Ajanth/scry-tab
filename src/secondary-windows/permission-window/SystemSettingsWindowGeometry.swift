import Foundation

struct SystemSettingsScreenDescriptor: Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
    let cgBounds: CGRect
}

enum SystemSettingsWindowGeometry {
    static func appKitGeometry(
        from cgFrame: CGRect,
        screens: [SystemSettingsScreenDescriptor]
    ) -> (frame: CGRect, visibleFrame: CGRect) {
        guard let fallback = screens.first else {
            return (frame: .zero, visibleFrame: .zero)
        }
        let matchedScreen = screens
            .filter { $0.cgBounds.intersects(cgFrame) }
            .max { lhs, rhs in
                let left = lhs.cgBounds.intersection(cgFrame)
                let right = rhs.cgBounds.intersection(cgFrame)
                return left.width * left.height < right.width * right.height
            } ?? fallback
        return convert(cgFrame, on: matchedScreen)
    }

    static func isEligibleSettingsWindowFrame(_ frame: CGRect) -> Bool {
        return frame.width > 320 && frame.height > 240
    }

    private static func convert(
        _ cgFrame: CGRect,
        on screen: SystemSettingsScreenDescriptor
    ) -> (frame: CGRect, visibleFrame: CGRect) {
        let localX = cgFrame.minX - screen.cgBounds.minX
        let localY = cgFrame.minY - screen.cgBounds.minY
        let frame = CGRect(
            x: screen.frame.minX + localX,
            y: screen.frame.maxY - localY - cgFrame.height,
            width: cgFrame.width,
            height: cgFrame.height)
        return (frame: frame, visibleFrame: screen.visibleFrame)
    }
}
