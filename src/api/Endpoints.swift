import Foundation

enum Endpoints {
    static let domain = Bundle.main.object(forInfoDictionaryKey: "Domain") as! String
    static let website = "https://\(domain)"
    static let appcastUrl = "\(website)/appcast.xml"
    /// GPL-3.0 requires the app to show the user how to view a copy of the licence. The canonical
    /// FSF-hosted text is used rather than a `\(website)` route so the link cannot break with a
    /// website redeploy.
    static let licenceUrl = "https://www.gnu.org/licenses/gpl-3.0.html"
    /// Corresponding Source offer under GPL-3.0 §6(d); must stay reachable for as long as any
    /// binary release is downloadable.
    static let sourceUrl = "\(website)/source"
}
