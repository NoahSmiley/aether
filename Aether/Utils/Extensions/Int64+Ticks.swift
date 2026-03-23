import Foundation

extension Int64 {
    /// Convert Jellyfin ticks to seconds (1 tick = 100 nanoseconds = 1/10,000,000 seconds).
    var asSeconds: Double {
        Double(self) / 10_000_000
    }

    /// Format Jellyfin ticks as a human-readable duration string ("1h 23m" or "45m").
    var asDuration: String {
        let totalSeconds = Int(asSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
