import Foundation

extension Double {
    /// Convert seconds to Jellyfin ticks (1 tick = 100 nanoseconds = 1/10,000,000 seconds).
    var asTicks: Int64 {
        Int64(self * 10_000_000)
    }
}