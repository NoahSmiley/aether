import SwiftUI

@MainActor
@Observable
class AuthViewModel {
    var serverURL: String = ""
    var username: String = ""
    var password: String = ""

    var isConnecting = false
    var isLoggingIn = false
    var isConnected = false
    var isAuthenticated = false
    var error: String?
    var serverInfo: PublicServerInfo?

    private let api = JellyfinAPI.shared

    func connectToServer() async {
        guard !serverURL.isEmpty else { return }
        isConnecting = true
        error = nil

        // Normalize URL
        var urlString = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://" + urlString
        }

        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            isConnecting = false
            return
        }

        do {
            await api.configure(baseURL: url)
            let info = try await api.validateServer(url: url)
            serverInfo = info
            try KeychainHelper.save(urlString, forKey: KeychainHelper.Keys.serverURL)
            isConnected = true
        } catch {
            self.error = error.localizedDescription
        }
        isConnecting = false
    }

    func login() async {
        guard !username.isEmpty else { return }
        isLoggingIn = true
        error = nil

        do {
            let response = try await api.login(username: username, password: password)
            try KeychainHelper.save(response.accessToken, forKey: KeychainHelper.Keys.accessToken)
            try KeychainHelper.save(response.user.id, forKey: KeychainHelper.Keys.userId)
            await api.setAuth(token: response.accessToken, userId: response.user.id)
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }
        isLoggingIn = false
    }

    func restoreSession() async {
        guard let urlString = try? KeychainHelper.read(forKey: KeychainHelper.Keys.serverURL),
              let url = URL(string: urlString),
              let token = try? KeychainHelper.read(forKey: KeychainHelper.Keys.accessToken),
              let userId = try? KeychainHelper.read(forKey: KeychainHelper.Keys.userId) else {
            return
        }

        await api.configure(baseURL: url)
        await api.setAuth(token: token, userId: userId)

        // Validate the token still works
        do {
            let info = try await api.validateServer(url: url)
            serverInfo = info
            serverURL = urlString
            isConnected = true
            isAuthenticated = true
        } catch {
            // Token expired, clear and require re-auth
            try? KeychainHelper.clear()
            await api.clearAuth()
        }
    }

    func logout() async {
        try? await api.logout()
        try? KeychainHelper.clear()
        await api.clearAuth()
        isAuthenticated = false
        isConnected = false
        serverInfo = nil
        username = ""
        password = ""
    }
}
