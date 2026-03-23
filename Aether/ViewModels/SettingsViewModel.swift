import Foundation

@MainActor
@Observable
class SettingsViewModel {
    var serverName: String = ""
    var serverVersion: String = ""
    var userName: String = ""
    var maxBitrate: Int = 0

    private let api = JellyfinAPI.shared

    func loadInfo() async {
        if let urlString = try? KeychainHelper.read(forKey: KeychainHelper.Keys.serverURL),
           let url = URL(string: urlString) {
            do {
                let serverInfo = try await api.validateServer(url: url)
                serverName = serverInfo.serverName
                serverVersion = serverInfo.version
            } catch {
                // Non-critical; leave fields empty
            }
        }

        // Read username from keychain
        if let storedUser = try? KeychainHelper.read(forKey: KeychainHelper.Keys.userId) {
            userName = storedUser
        }
    }

    func signOut() async {
        try? await api.logout()
        try? KeychainHelper.clear()
        await api.clearAuth()
    }
}
