import Foundation

struct PublicServerInfo: Codable {
    let localAddress: String?
    let serverName: String
    let version: String
    let productName: String?
    let operatingSystem: String?
    let id: String
    let startupWizardCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case localAddress = "LocalAddress"
        case serverName = "ServerName"
        case version = "Version"
        case productName = "ProductName"
        case operatingSystem = "OperatingSystem"
        case id = "Id"
        case startupWizardCompleted = "StartupWizardCompleted"
    }
}
