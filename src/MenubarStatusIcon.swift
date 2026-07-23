import Cocoa

/// Builds a status-bar-sized branded app icon without mutating the shared `NSImage.applicationIconName` cache.
enum MenubarStatusIcon {
    static let pointSize = NSSize(width: 18, height: 18)

    static func makeImage(from cgImage: CGImage) -> NSImage {
        let image = NSImage(cgImage: cgImage, size: pointSize)
        image.isTemplate = false
        return image
    }
}
