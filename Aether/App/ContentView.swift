import SwiftUI

struct ContentView: View {
    @State private var selectedTab: String = "home"

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: "search") {
                NavigationStack {
                    SearchView()
                }
            } label: {
                Label("Search", systemImage: "magnifyingglass")
                    .labelStyle(.iconOnly)
            }

            Tab(value: "home") {
                HomeView()
            } label: {
                Label("Home", systemImage: "house.fill")
                    .labelStyle(.iconOnly)
            }

            Tab(value: "movies") {
                NavigationStack {
                    LibraryGridView(parentId: nil, includeTypes: ["Movie"], title: "Movies")
                }
            } label: {
                Label("Movies", systemImage: "film.stack")
                    .labelStyle(.iconOnly)
            }

            Tab(value: "tvshows") {
                NavigationStack {
                    LibraryGridView(parentId: nil, includeTypes: ["Series"], title: "TV Shows")
                }
            } label: {
                Label("TV Shows", systemImage: "tv")
                    .labelStyle(.iconOnly)
            }

            Tab(value: "livetv") {
                NavigationStack {
                    LiveTVView()
                }
            } label: {
                Label("Live TV", systemImage: "antenna.radiowaves.left.and.right")
                    .labelStyle(.iconOnly)
            }

            Tab(value: "settings") {
                NavigationStack {
                    SettingsView()
                }
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
                    .labelStyle(.iconOnly)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
