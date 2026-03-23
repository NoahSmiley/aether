import SwiftUI
import NukeUI

struct LiveTVView: View {
    @State private var viewModel = LiveTVViewModel()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Sports & NFL
                if !viewModel.sportsPrograms.isEmpty {
                    programRow(title: "Sports & NFL", items: viewModel.sportsPrograms)
                        .padding(.bottom, AetherTheme.spacingXXL)
                }

                // Now Airing
                if !viewModel.nowAiring.isEmpty {
                    programRow(title: "Live Now", items: viewModel.nowAiring)
                        .padding(.bottom, AetherTheme.spacingXXL)
                }

                // All Channels
                if !viewModel.channels.isEmpty {
                    channelsRow
                        .padding(.bottom, AetherTheme.spacingXXL)
                }

                Spacer()
                    .frame(height: AetherTheme.spacingHuge)
            }
        }
        .background(AetherTheme.deepBlack)
        .navigationTitle("Live TV")
        .task {
            await viewModel.loadAll()
        }
    }

    // MARK: - Program Row

    @ViewBuilder
    private func programRow(title: String, items: [MockProgram]) -> some View {
        VStack(alignment: .leading, spacing: AetherTheme.spacingSM) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AetherTheme.textPrimary)
                .padding(.leading, 50)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 25) {
                    ForEach(items) { program in
                        ProgramCard(program: program)
                    }
                }
                .padding(.leading, 50)
                .padding(.trailing, 60)
                .padding(.vertical, AetherTheme.spacingLG)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Channels Row

    private var channelsRow: some View {
        VStack(alignment: .leading, spacing: AetherTheme.spacingSM) {
            Text("All Channels")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AetherTheme.textPrimary)
                .padding(.leading, 50)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(viewModel.channels) { channel in
                        ChannelCard(channel: channel)
                    }
                }
                .padding(.leading, 50)
                .padding(.trailing, 60)
                .padding(.vertical, AetherTheme.spacingLG)
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - Program Card

struct ProgramCard: View {
    let program: MockProgram

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button { } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail area with gradient and icon
                ZStack(alignment: .topLeading) {
                    // Background with sport-appropriate gradient
                    RoundedRectangle(cornerRadius: AetherTheme.cardCornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Image(systemName: program.systemIcon)
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.white.opacity(0.12))
                        }
                        .frame(width: AetherTheme.thumbnailWidth, height: AetherTheme.thumbnailHeight)

                    // LIVE badge
                    if program.isLive {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(.red)
                                .frame(width: 7, height: 7)
                            Text("LIVE")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.red.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .padding(10)
                    }

                    // Channel label bottom-right
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(program.channelName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .padding(10)
                        }
                    }
                    .frame(width: AetherTheme.thumbnailWidth, height: AetherTheme.thumbnailHeight)
                }

                // Info below
                VStack(alignment: .leading, spacing: 3) {
                    Text(program.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AetherTheme.textPrimary)
                        .lineLimit(1)

                    Text(program.subtitle)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(AetherTheme.textSecondary)
                        .lineLimit(1)
                }
                .padding(.top, 8)
            }
            .frame(width: AetherTheme.thumbnailWidth)
        }
        .buttonStyle(.card)
    }
}

// MARK: - Channel Card

struct ChannelCard: View {
    let channel: MockChannel

    var body: some View {
        Button { } label: {
            VStack(spacing: 6) {
                // Channel icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 140, height: 90)

                    VStack(spacing: 4) {
                        Image(systemName: channel.systemIcon)
                            .font(.system(size: 26))
                            .foregroundColor(.white.opacity(0.5))

                        Text(channel.number)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                // Channel name
                Text(channel.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AetherTheme.textPrimary)
                    .lineLimit(1)

                // Current program
                Text(channel.currentProgram)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AetherTheme.textTertiary)
                    .lineLimit(1)
            }
            .frame(width: 140)
        }
        .buttonStyle(.card)
    }
}
