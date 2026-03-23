import Foundation

enum JellyfinError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case unauthorized
    case serverUnreachable
    case decodingError(Error)
    case noToken
    case noUserId

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid server URL"
        case .invalidResponse: "Invalid response from server"
        case .httpError(let code): "Server error (\(code))"
        case .unauthorized: "Authentication required"
        case .serverUnreachable: "Cannot reach server"
        case .decodingError(let error): "Data error: \(error.localizedDescription)"
        case .noToken: "Not authenticated"
        case .noUserId: "No user ID available"
        }
    }
}
