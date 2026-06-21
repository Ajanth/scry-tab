import XCTest

final class AppearanceTests: XCTestCase {
    func testComfortableWidth() throws {
        var actual: Double
        for (model, (physicalWidth, physicalHeight), (expectedHorizontal, expectedVertical)) in screens {
            // screen used horizontally
            actual = AppearanceTestable.comfortableWidth(physicalWidth)
            XCTAssertEqual(actual, expectedHorizontal, accuracy: 0.01, model)
            // screen used vertically
            actual = AppearanceTestable.comfortableWidth(physicalHeight)
            XCTAssertEqual(actual, expectedVertical, accuracy: 0.01, model)
        }
    }

    /// Screens that don't report their physical dimensions (`physicalWidth == nil`) get the 0.9
    /// default — the same clamp Windows 11 uses. Without this, ultrawides would fall to 0.45 just
    /// because we lack the data, which is worse than picking a sane default.
    func testComfortableWidthFallsBackToDefaultWhenPhysicalWidthIsNil() throws {
        XCTAssertEqual(AppearanceTestable.comfortableWidth(nil), 0.9)
    }

    private let screens: [(String, (CGFloat, CGFloat), (CGFloat, CGFloat))] = [
        // screen model, (physicalWidthInMM, physicalHeightInMM), (expectedWidthForHorizontal, expectedWidthForVertical)
        ("11\" Laptop: MacBook Air 11\": HD", (255.7, 178.6), (0.90, 0.90)),
        ("13\" Laptop: MacBook Air 13\": WXGA+", (304.1, 197.8), (0.90, 0.90)),
        ("14\" Laptop: MacBook Pro 14\": 3K", (311.0, 221.1), (0.90, 0.90)),
        ("15\" Laptop: MacBook Pro 15\": QXGA", (344.4, 233.0), (0.90, 0.90)),
        ("16\" Laptop: MacBook Pro 16\": 3.5K", (358.4, 245.9), (0.90, 0.90)),
        ("19\" Monitor: Apple Studio Display 19\": HD", (403.0, 236.0), (0.90, 0.90)),
        ("20\" Monitor: Apple Cinema Display 20\": WSXGA+", (440.0, 268.0), (0.90, 0.90)),
        ("21\" Monitor: LG 21:9 UltraWide: UWHD", (470.0, 290.0), (0.90, 0.90)),
        ("22\" Monitor: ASUS 22\" Full HD: Full HD", (485.0, 290.0), (0.90, 0.90)),
        ("24\" Monitor: Dell P2419H: Full HD", (531.3, 298.6), (0.90, 0.90)),
        ("27\" Monitor: LG 27UK850-W: 4K", (596.8, 336.4), (0.90, 0.90)),
        ("30\" Monitor: BenQ PD3200U: 4K", (657.5, 376.3), (0.90, 0.90)),
        ("32\" Monitor: BenQ EW3270U: 4K", (711.5, 398.9), (0.84, 0.90)),
        ("34\" UltraWide Monitor: LG 34UC79G-B: UWHD", (798.5, 336.5), (0.75, 0.90)),
        ("34\" UltraWide Monitor: LG 34WN80C-B: UWQHD", (799.8, 334.8), (0.75, 0.90)),
        ("32\" TV: Samsung UE32T5300: Full HD", (715.0, 406.0), (0.83, 0.90)),
        ("40\" TV: Samsung Q60B: 4K", (889.0, 510.0), (0.67, 0.90)),
        ("43\" TV: LG 43UN7300: 4K", (956.0, 551.0), (0.62, 0.90)),
        ("50\" TV: Samsung TU8000: 4K", (1110.0, 630.0), (0.54, 0.90)),
        ("55\" TV: LG OLED55CXPUA: 4K", (1210.0, 715.0), (0.49, 0.83)),
        ("60\" TV: Vizio 60-inch 4K: 4K", (1320.0, 750.0), (0.45, 0.80)),
    ]
}
