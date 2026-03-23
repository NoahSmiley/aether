import SwiftUI

/// Quality metadata for a channel
enum StreamQuality: String {
    case uhd4K = "4K"
    case fhd = "1080p"
    case hd = "720p"
    case sd = "SD"

    var color: Color {
        switch self {
        case .uhd4K: return .purple
        case .fhd: return .blue
        case .hd: return .green
        case .sd: return .gray
        }
    }
}

/// A stream paired with its current EPG program info and quality
struct LiveChannel: Identifiable {
    let stream: XtreamStream
    let programTitle: String
    let programDescription: String
    let startTime: String
    let endTime: String
    let quality: StreamQuality
    let is60fps: Bool

    var id: Int { stream.streamId }

    var channelName: String {
        var name = stream.name
        if let range = name.range(of: #"^[A-Z0-9]{2,3}\|\s*"#, options: .regularExpression) {
            name.removeSubrange(range)
        }
        // Clean up quality tags from display name
        for tag in [" HD", " FHD", " SD", " UHD", " ᴴᴰ ⁶⁰ᶠᵖˢ", " ᴴᴰ ²⁵ᶠᵖˢ", " ᴴᴰ", " UHD/4K"] {
            name = name.replacingOccurrences(of: tag, with: "")
        }
        return name.trimmingCharacters(in: .whitespaces)
    }
}

@MainActor
@Observable
class LiveTVViewModel {
    var sportsChannels: [LiveChannel] = []
    var nflChannels: [LiveChannel] = []
    var golfChannels: [LiveChannel] = []
    var isLoading = false
    var error: String?

    private let api = XtreamAPI.shared

    // Channel definitions: (streamId, quality, is60fps)
    private let sportsChannelDefs: [(Int, StreamQuality, Bool)] = [
        (1921356, .fhd, true),   // ESPN ᴴᴰ ⁶⁰ᶠᵖˢ
        (1921353, .fhd, true),   // ESPN 2 ᴴᴰ ⁶⁰ᶠᵖˢ
        (1921360, .fhd, true),   // ESPN NEWS ᴴᴰ ⁶⁰ᶠᵖˢ
        (1921359, .fhd, true),   // ESPN U ᴴᴰ ⁶⁰ᶠᵖˢ
        (45601,   .hd,  false),  // CBS SPORTS NETWORK HD
        (234677,  .hd,  false),  // NBC SPORTS NETWORK
        (45571,   .hd,  false),  // FOX SPORTS 1 HD
        (45570,   .hd,  false),  // FOX SPORTS 2 HD
        (1481941, .uhd4K, true), // ESPN UHD 4K
    ]

    private let nflChannelDefs: [(Int, StreamQuality, Bool)] = [
        (45526, .hd, false),  // NFL NETWORK HD
        (45524, .hd, false),  // NFL REDZONE HD
    ]

    private let golfChannelDefs: [(Int, StreamQuality, Bool)] = [
        (45554, .sd,  false),  // GOLF CHANNEL (540p)
        (45532, .sd,  false),  // NBC GOLF
    ]

    private var qualityMap: [Int: (StreamQuality, Bool)] = [:]

    func loadAll() async {
        isLoading = true
        error = nil

        // Build quality lookup
        for (id, quality, fps60) in sportsChannelDefs + nflChannelDefs + golfChannelDefs {
            qualityMap[id] = (quality, fps60)
        }

        let allIds = Set((sportsChannelDefs + nflChannelDefs + golfChannelDefs).map(\.0))

        do {
            async let sportsResult = api.getLiveStreams(categoryId: "680")
            async let espnResult = api.getLiveStreams(categoryId: "2232")
            async let nflResult = api.getLiveStreams(categoryId: "675")
            async let uhd4kResult = api.getLiveStreams(categoryId: "1673")

            let all = try await sportsResult + espnResult + nflResult + uhd4kResult
            let wanted = all.filter { allIds.contains($0.streamId) }

            let sportsIds = Set(sportsChannelDefs.map(\.0))
            let nflIds = Set(nflChannelDefs.map(\.0))
            let golfIds = Set(golfChannelDefs.map(\.0))

            let wantedSports = wanted.filter { sportsIds.contains($0.streamId) }
            let wantedNfl = wanted.filter { nflIds.contains($0.streamId) }
            let wantedGolf = wanted.filter { golfIds.contains($0.streamId) }

            async let sportsLive = loadLiveChannels(wantedSports)
            async let nflLive = loadLiveChannels(wantedNfl)
            async let golfLive = loadLiveChannels(wantedGolf)

            sportsChannels = await sportsLive
            nflChannels = await nflLive
            golfChannels = await golfLive
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func streamURL(for stream: XtreamStream) -> URL? {
        api.streamURL(for: stream.streamId)
    }

    // MARK: - EPG

    private func loadLiveChannels(_ streams: [XtreamStream]) async -> [LiveChannel] {
        await withTaskGroup(of: LiveChannel?.self) { group in
            for stream in streams {
                group.addTask {
                    await self.checkEPG(for: stream)
                }
            }

            var results: [(LiveChannel, Int)] = []
            for await channel in group {
                if let channel,
                   let idx = streams.firstIndex(where: { $0.streamId == channel.stream.streamId }) {
                    results.append((channel, idx))
                }
            }
            return results.sorted(by: { $0.1 < $1.1 }).map(\.0)
        }
    }

    private func checkEPG(for stream: XtreamStream) async -> LiveChannel? {
        let (quality, is60fps) = qualityMap[stream.streamId] ?? (.hd, false)

        do {
            let epg = try await api.getEPG(streamId: stream.streamId)
            guard !epg.isEmpty else {
                return makeFallbackChannel(stream, quality: quality, is60fps: is60fps)
            }

            let now = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")

            for entry in epg {
                guard let start = formatter.date(from: entry.start),
                      let end = formatter.date(from: entry.end) else { continue }

                if start <= now && end > now {
                    let displayFormatter = DateFormatter()
                    displayFormatter.dateFormat = "h:mm a"
                    displayFormatter.timeZone = .current

                    return LiveChannel(
                        stream: stream,
                        programTitle: entry.decodedTitle,
                        programDescription: entry.decodedDescription,
                        startTime: displayFormatter.string(from: start),
                        endTime: displayFormatter.string(from: end),
                        quality: quality,
                        is60fps: is60fps
                    )
                }
            }

            return makeFallbackChannel(stream, quality: quality, is60fps: is60fps)
        } catch {
            return makeFallbackChannel(stream, quality: quality, is60fps: is60fps)
        }
    }

    private func makeFallbackChannel(_ stream: XtreamStream, quality: StreamQuality, is60fps: Bool) -> LiveChannel {
        LiveChannel(
            stream: stream,
            programTitle: cleanName(stream.name),
            programDescription: "",
            startTime: "",
            endTime: "",
            quality: quality,
            is60fps: is60fps
        )
    }

    private func cleanName(_ name: String) -> String {
        var n = name
        if let range = n.range(of: #"^[A-Z0-9]{2,3}\|\s*"#, options: .regularExpression) {
            n.removeSubrange(range)
        }
        for tag in [" HD", " FHD", " SD", " UHD", " ᴴᴰ ⁶⁰ᶠᵖˢ", " ᴴᴰ ²⁵ᶠᵖˢ", " ᴴᴰ", " UHD/4K"] {
            n = n.replacingOccurrences(of: tag, with: "")
        }
        return n.trimmingCharacters(in: .whitespaces)
    }
}
