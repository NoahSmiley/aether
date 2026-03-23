import SwiftUI

struct DetailView: View {
    let itemId: String
    @State private var viewModel = MediaDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ZStack {
                    AetherTheme.deepBlack.ignoresSafeArea()
                    VStack(spacing: AetherTheme.spacingMD) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .font(.system(size: AetherTheme.captionSize))
                            .foregroundStyle(AetherTheme.textTertiary)
                    }
                }
            } else if let item = viewModel.item {
                switch item.type {
                case .series:
                    ShowDetailView(item: item, viewModel: viewModel)
                default:
                    MovieDetailView(item: item, viewModel: viewModel)
                }
            } else if let error = viewModel.error {
                ZStack {
                    AetherTheme.deepBlack.ignoresSafeArea()
                    VStack(spacing: AetherTheme.spacingMD) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(AetherTheme.textTertiary)
                        Text(error)
                            .font(.system(size: AetherTheme.bodySize))
                            .foregroundStyle(AetherTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 80)
                    }
                }
            }
        }
        .task { await viewModel.loadItem(id: itemId) }
    }
}
