import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var selectedBitrate: BitrateOption = .auto
    @State private var showSignOutConfirm = false

    var body: some View {
        List {
            // Server section with icon
            Section {
                HStack(spacing: AetherTheme.spacingMD) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 28))
                        .foregroundStyle(AetherTheme.accent)
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.serverName.isEmpty ? "Jellyfin Server" : viewModel.serverName)
                            .font(.system(size: AetherTheme.bodySize, weight: .semibold))
                            .foregroundStyle(.white)

                        if !viewModel.serverVersion.isEmpty {
                            Text("Version \(viewModel.serverVersion)")
                                .font(.system(size: AetherTheme.captionSize))
                                .foregroundStyle(AetherTheme.textSecondary)
                        }
                    }
                }

                if let url = try? KeychainHelper.read(forKey: KeychainHelper.Keys.serverURL), !url.isEmpty {
                    LabeledContent {
                        Text(url)
                            .foregroundStyle(AetherTheme.textSecondary)
                    } label: {
                        Label("Server URL", systemImage: "link")
                    }
                }
            } header: {
                Text("Server")
            }

            // User section
            Section {
                if !viewModel.userName.isEmpty {
                    LabeledContent {
                        Text(viewModel.userName)
                            .foregroundStyle(AetherTheme.textSecondary)
                    } label: {
                        Label("Username", systemImage: "person.fill")
                    }
                }
            } header: {
                Text("Account")
            }

            // Playback Quality section
            Section {
                Picker(selection: $selectedBitrate) {
                    Label("Auto / Direct Play", systemImage: "sparkles")
                        .tag(BitrateOption.auto)
                    Label("20 Mbps (1080p)", systemImage: "antenna.radiowaves.left.and.right")
                        .tag(BitrateOption.mbps20)
                    Label("10 Mbps (720p)", systemImage: "antenna.radiowaves.left.and.right")
                        .tag(BitrateOption.mbps10)
                    Label("5 Mbps (480p)", systemImage: "antenna.radiowaves.left.and.right")
                        .tag(BitrateOption.mbps5)
                } label: {
                    Label("Max Bitrate", systemImage: "gauge.with.dots.needle.67percent")
                }
                .onChange(of: selectedBitrate) { _, newValue in
                    viewModel.maxBitrate = newValue.rawValue
                    UserDefaults.standard.set(newValue.rawValue, forKey: "maxBitrate")
                }
            } header: {
                Text("Playback")
            }

            // About section
            Section {
                LabeledContent {
                    Text(appVersion)
                        .foregroundStyle(AetherTheme.textSecondary)
                } label: {
                    Label("App Version", systemImage: "info.circle")
                }
            } header: {
                Text("About")
            }

            // Sign Out — red at bottom
            Section {
                Button {
                    showSignOutConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 22))
                        Text("Sign Out")
                            .font(.system(size: AetherTheme.bodySize, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Sign Out", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
        } message: {
            Text("Are you sure you want to sign out? You will need to reconnect to your server.")
        }
        .task {
            await viewModel.loadInfo()
            selectedBitrate = BitrateOption(rawValue: viewModel.maxBitrate) ?? .auto
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Bitrate Option

enum BitrateOption: Int, CaseIterable, Identifiable {
    case auto = 0
    case mbps20 = 20_000_000
    case mbps10 = 10_000_000
    case mbps5 = 5_000_000

    var id: Int { rawValue }
}
