import SwiftUI

@MainActor
@Observable
class LiveTVViewModel {
    var channels: [MockChannel] = []
    var nowAiring: [MockProgram] = []
    var sportsPrograms: [MockProgram] = []
    var isLoading = false

    func loadAll() async {
        isLoading = true

        // Use mock data for now — replace with real API calls when tuner is configured
        channels = MockChannel.allChannels
        nowAiring = MockProgram.nowAiring
        sportsPrograms = MockProgram.sports

        isLoading = false
    }
}

// MARK: - Mock Data Models

struct MockChannel: Identifiable {
    let id: String
    let name: String
    let number: String
    let currentProgram: String
    let systemIcon: String

    static let allChannels: [MockChannel] = [
        MockChannel(id: "espn", name: "ESPN", number: "206", currentProgram: "SportsCenter", systemIcon: "sportscourt"),
        MockChannel(id: "espn2", name: "ESPN2", number: "209", currentProgram: "First Take", systemIcon: "sportscourt"),
        MockChannel(id: "nfl", name: "NFL Network", number: "212", currentProgram: "NFL Total Access", systemIcon: "football"),
        MockChannel(id: "fox-sports", name: "FOX Sports 1", number: "219", currentProgram: "NASCAR Race Hub", systemIcon: "flag.checkered"),
        MockChannel(id: "nba-tv", name: "NBA TV", number: "216", currentProgram: "NBA GameTime", systemIcon: "basketball"),
        MockChannel(id: "mlb", name: "MLB Network", number: "213", currentProgram: "MLB Tonight", systemIcon: "baseball"),
        MockChannel(id: "tnt", name: "TNT", number: "245", currentProgram: "Inside the NBA", systemIcon: "tv"),
        MockChannel(id: "cbs-sports", name: "CBS Sports", number: "221", currentProgram: "CBS Sports HQ", systemIcon: "sportscourt"),
        MockChannel(id: "fox", name: "FOX", number: "5", currentProgram: "The Masked Singer", systemIcon: "tv"),
        MockChannel(id: "abc", name: "ABC", number: "7", currentProgram: "The Bachelor", systemIcon: "tv"),
        MockChannel(id: "nbc", name: "NBC", number: "4", currentProgram: "The Voice", systemIcon: "tv"),
        MockChannel(id: "cbs", name: "CBS", number: "2", currentProgram: "NCIS", systemIcon: "tv"),
        MockChannel(id: "hbo", name: "HBO", number: "501", currentProgram: "The Last of Us", systemIcon: "play.tv"),
        MockChannel(id: "showtime", name: "Showtime", number: "545", currentProgram: "Billions", systemIcon: "play.tv"),
        MockChannel(id: "cnn", name: "CNN", number: "200", currentProgram: "CNN Newsroom", systemIcon: "newspaper"),
        MockChannel(id: "discovery", name: "Discovery", number: "278", currentProgram: "Gold Rush", systemIcon: "globe"),
    ]
}

struct MockProgram: Identifiable {
    let id: String
    let name: String
    let channelName: String
    let channelNumber: String
    let subtitle: String
    let isLive: Bool
    let systemIcon: String

    static let nowAiring: [MockProgram] = [
        MockProgram(id: "p1", name: "SportsCenter", channelName: "ESPN", channelNumber: "206", subtitle: "Top plays and highlights", isLive: true, systemIcon: "sportscourt"),
        MockProgram(id: "p2", name: "The Last of Us", channelName: "HBO", channelNumber: "501", subtitle: "S2 E4 — \"Ellie\"", isLive: true, systemIcon: "play.tv"),
        MockProgram(id: "p3", name: "CNN Newsroom", channelName: "CNN", channelNumber: "200", subtitle: "Breaking news coverage", isLive: true, systemIcon: "newspaper"),
        MockProgram(id: "p4", name: "The Voice", channelName: "NBC", channelNumber: "4", subtitle: "Blind Auditions — Part 3", isLive: true, systemIcon: "music.mic"),
        MockProgram(id: "p5", name: "Gold Rush", channelName: "Discovery", channelNumber: "278", subtitle: "S14 E8 — \"Parker's Gamble\"", isLive: true, systemIcon: "globe"),
        MockProgram(id: "p6", name: "NCIS", channelName: "CBS", channelNumber: "2", subtitle: "S22 E12 — \"Cold Case\"", isLive: true, systemIcon: "tv"),
    ]

    static let sports: [MockProgram] = [
        MockProgram(id: "s1", name: "NFL: Cowboys vs Eagles", channelName: "ESPN", channelNumber: "206", subtitle: "NFC East Rivalry — 4th Quarter", isLive: true, systemIcon: "football"),
        MockProgram(id: "s2", name: "NBA: Lakers vs Celtics", channelName: "TNT", channelNumber: "245", subtitle: "3rd Quarter — LAL 78, BOS 82", isLive: true, systemIcon: "basketball"),
        MockProgram(id: "s3", name: "NFL RedZone", channelName: "NFL Network", channelNumber: "212", subtitle: "Every touchdown, every game", isLive: true, systemIcon: "football"),
        MockProgram(id: "s4", name: "UEFA Champions League", channelName: "CBS Sports", channelNumber: "221", subtitle: "Real Madrid vs Man City", isLive: true, systemIcon: "soccerball"),
        MockProgram(id: "s5", name: "MLB: Yankees vs Red Sox", channelName: "MLB Network", channelNumber: "213", subtitle: "Top of the 6th", isLive: true, systemIcon: "baseball"),
        MockProgram(id: "s6", name: "NASCAR Cup Series", channelName: "FOX Sports 1", channelNumber: "219", subtitle: "Daytona 500 — Lap 142/200", isLive: true, systemIcon: "flag.checkered"),
        MockProgram(id: "s7", name: "NHL: Rangers vs Bruins", channelName: "ESPN2", channelNumber: "209", subtitle: "2nd Period — NYR 2, BOS 1", isLive: true, systemIcon: "hockey.puck"),
        MockProgram(id: "s8", name: "March Madness", channelName: "CBS", channelNumber: "2", subtitle: "Sweet 16 — Duke vs Houston", isLive: true, systemIcon: "basketball"),
    ]
}
