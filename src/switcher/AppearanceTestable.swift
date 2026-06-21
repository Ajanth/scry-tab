import Foundation

class AppearanceTestable {
    /// How wide should the TilesPanel be, for comfortable viewing?
    /// * a comfortable field-of-view is 50-60 degrees
    /// * people sit at various distances from the screen. We can't know how far they sit
    /// * most people will seat far enough so that they can view the whole width of the screen
    /// * some people use wide-screen or TV monitors. Those people tend to be too close to the screen, since they need to use keyboard and mouse on their desk
    /// Let's use this heuristic: let's assume that people can view 60cm comfortably. Bigger screens can only show parts of ScryTab
    /// Let's clamp at 90% like Windows 11
    /// Let's clamp at 45% (value for the biggest, 60" screens)
    static func comfortableWidth(_ physicalWidth: Double?) -> Double {
        if let physicalWidth {
            return min(0.9, max(0.45, 600.0 / physicalWidth))
        }
        return 0.9
    }
}
