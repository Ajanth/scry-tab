import Foundation

enum Endpoints {
    static let domain = Bundle.main.object(forInfoDictionaryKey: "Domain") as! String
    static let website = "https://\(domain)"
    static let appcastUrl = "\(website)/appcast.xml"
}
