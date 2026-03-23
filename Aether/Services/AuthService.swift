import Foundation
import Observation

@MainActor
@Observable
final class AuthService {
    var isAuthenticated = false
    var isLoading = false
    var serverInfo: PublicServerInfo?
    var currentUser: UserDto?
    var error: String?

    private let api = JellyfinAPI.shared

    // MARK: - Server Connection

    func connectToServer(urlString: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // Normalize the URL string
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.lowercased().hasPrefix("http://") && !normalized.lowercased().hasPrefix("https://") {
            normalized = "http://\(normalized)"
        }
        // Strip trailing slash
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }

        guard let url = URL(string: normalized) else {
            error = JellyfinError.invalidURL.localizedDescription
            return
        }

        do {
            let info = try await api.validateServer(url: url)
            try KeychainHelper.save(normalized, forKey: KeychainHelper.Keys.serverURL)
            self.serverInfo = info
        } catch let jellyfinError as JellyfinError {
            self.error = jellyfinError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Login

    func login(username: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await api.login(username: username, password: password)
            try KeychainHelper.save(response.accessToken, forKey: KeychainHelper.Keys.accessToken)
            try KeychainHelper.save(response.user.id, forKey: KeychainHelper.Keys.userId)
            self.currentUser = response.user
            self.isAuthenticated = true
        } catch let jellyfinError as JellyfinError {
            self.error = jellyfinError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Session Restore

    func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let serverURL = try KeychainHelper.read(forKey: KeychainHelper.Keys.serverURL),
                  let url = URL(string: serverURL),
                  let token = try KeychainHelper.read(forKey: KeychainHelper.Keys.accessToken),
                  let userId = try KeychainHelper.read(forKey: KeychainHelper.Keys.userId) else {
                return
            }

            await api.configure(baseURL: url)
            await api.setAuth(token: token, userId: userId)

            // Validate the token is still valid by fetching user info
            let user: UserDto = try await api.get(path: "/Users/\(userId)")
            self.currentUser = user
            self.isAuthenticated = true
        } catch {
            // Token is invalid or server unreachable — clear credentials
            await api.clearAuth()
            try? KeychainHelper.delete(forKey: KeychainHelper.Keys.accessToken)
            try? KeychainHelper.delete(forKey: KeychainHelper.Keys.userId)
        }
    }

    // MARK: - Logout

    func logout() async {
        do {
            try await api.logout()
        } catch {
            // Even if server logout fails, clear local state
        }

        try? KeychainHelper.delete(forKey: KeychainHelper.Keys.accessToken)
        try? KeychainHelper.delete(forKey: KeychainHelper.Keys.userId)
        try? KeychainHelper.delete(forKey: KeychainHelper.Keys.serverURL)

        self.isAuthenticated = false
        self.currentUser = nil
        self.serverInfo = nil
        self.error = nil
    }
}
