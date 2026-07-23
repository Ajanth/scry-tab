import XCTest

final class MenubarStatusIconTests: XCTestCase {
    /// `makeImage(from:)` returns an `NSImage` with `size == 18×18` and `isTemplate == false`.
    func testMakeImageSetsPointSizeAndIsNotTemplate() throws {
        let cgImage = try XCTUnwrap(Self.makeSyntheticCGImage())
        let image = MenubarStatusIcon.makeImage(from: cgImage)
        XCTAssertEqual(image.size, MenubarStatusIcon.pointSize)
        XCTAssertFalse(image.isTemplate)
    }

    private static func makeSyntheticCGImage() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return context.makeImage()
    }
}
