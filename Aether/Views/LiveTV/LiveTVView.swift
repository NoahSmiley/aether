import SwiftUI
import NukeUI

struct LiveTVView: View {
    @State private var viewModel = LiveTVViewModel()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoading {
                    SkeletonRow()
                        .padding(.bottom, LumaTheme.spacingXXL)
                    SkeletonRow()
                        .padding(.bottom, LumaTheme.spacingXXL)
                } else if !viewModel.sportsChannels.isEmpty || !viewModel.nflChannels.isEmpty || !viewModel.golfChannels.isEmpty {
                    if !viewModel.nflChannels.isEmpty {
                        channelRow(title: "NFL", icon: "football", channels: viewModel.nflChannels)
                            .padding(.bottom, LumaTheme.spacingXXL)
                    }

                    if !viewModel.golfChannels.isEmpty {
                        channelRow(title: "Golf", icon: "figure.golf", channels: viewModel.golfChannels)
                            .padding(.bottom, LumaTheme.spacingXXL)
                    }

                    if !viewModel.sportsChannels.isEmpty {
                        channelRow(title: "Sports", icon: "sportscourt", channels: viewModel.sportsChannels)
                            .padding(.bottom, LumaTheme.spacingXXL)
                    }
                } else {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 150)
                        Image(systemName: "tv.slash")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundColor(LumaTheme.textTertiary)
                        Text("No live channels right now")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(LumaTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer()
                    .frame(height: LumaTheme.spacingHuge)
            }
        }
        .background(LumaTheme.deepBlack)
        .navigationTitle("Live TV")
        .task {
            await viewModel.loadAll()
        }
    }

    // MARK: - Channel Row

    @ViewBuilder
    private func channelRow(title: String, icon: String, channels: [LiveChannel]) -> some View {
        VStack(alignment: .leading, spacing: LumaTheme.spacingSM) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(LumaTheme.textPrimary)
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(LumaTheme.textPrimary)
            }
            .padding(.leading, 50)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 25) {
                    ForEach(channels) { channel in
                        LiveChannelCard(channel: channel, viewModel: viewModel)
                    }
                }
                .padding(.leading, 50)
                .padding(.trailing, 60)
                .padding(.vertical, LumaTheme.spacingLG)
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - Live Channel Card

struct LiveChannelCard: View {
    let channel: LiveChannel
    let viewModel: LiveTVViewModel

    @State private var isShowingPlayer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isShowingPlayer = true
            } label: {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            if let iconURL = channel.stream.streamIcon,
                               !iconURL.isEmpty,
                               let url = URL(string: iconURL) {
                                LazyImage(url: url) { state in
                                    if let image = state.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 100, height: 100)
                                    } else {
                                        Image(systemName: "play.tv.fill")
                                            .font(.system(size: 40, weight: .light))
                                            .foregroundColor(.white.opacity(0.15))
                                    }
                                }
                            } else {
                                Image(systemName: "play.tv.fill")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundColor(.white.opacity(0.15))
                            }
                        }
                        .frame(width: LumaTheme.thumbnailWidth, height: LumaTheme.thumbnailHeight)

                    // ON NOW badge
                    if !channel.startTime.isEmpty {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(.green)
                                .frame(width: 7, height: 7)
                            Text("ON NOW")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.green.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .padding(10)
                    }

                    // Time range bottom-right
                    if !channel.startTime.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(channel.startTime) - \(channel.endTime)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .padding(10)
                            }
                        }
                        .frame(width: LumaTheme.thumbnailWidth, height: LumaTheme.thumbnailHeight)
                    }
                }
            }
            .buttonStyle(.card)

            // Program info
            VStack(alignment: .leading, spacing: 3) {
                Text(channel.programTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(LumaTheme.textPrimary)
                    .lineLimit(1)

                Text(channel.channelName)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(LumaTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.top, 10)
            .padding(.leading, 5)
            .frame(width: LumaTheme.thumbnailWidth, alignment: .leading)
        }
        .frame(width: LumaTheme.thumbnailWidth)
        .fullScreenCover(isPresented: $isShowingPlayer) {
            if let url = viewModel.streamURL(for: channel.stream) {
                LiveStreamPlayerView(
                    streamName: channel.channelName,
                    streamURL: url
                )
            }
        }
    }
}
