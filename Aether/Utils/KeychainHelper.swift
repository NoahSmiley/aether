import Foundation

enum KeychainHelper {
    private static let defaults = UserDefaults.standard
    private static let prefix = "me.athion.luma."

    static func save(_ value: String, forKey key: String) throws {
        defaults.set(value, forKey: prefix + key)
    }

    static func read(forKey key: String) throws -> String? {
        defaults.string(forKey: prefix + key)
    }

    static func delete(forKey key: String) throws {
        defaults.removeObject(forKey: prefix + key)
    }

    static func clear() throws {
        for key in Keys.all {
            defaults.removeObject(forKey: prefix + key)
        }
    }

    enum Keys {
        static let accessToken = "accessToken"
        static let userId = "userId"
        static let serverURL = "serverURL"
        static let deviceId = "deviceId"

        static let all = [accessToken, userId, serverURL, deviceId]
    }
}
