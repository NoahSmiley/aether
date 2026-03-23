import SwiftUI

struct DetailView: View {
    let itemId: String
    @State private var viewModel = MediaDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ZStack {
                    LumaTheme.deepBlack.ignoresSafeArea()
                    VStack(spacing: LumaTheme.spacingMD) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .font(.system(size: LumaTheme.captionSize))
                            .foregroundStyle(LumaTheme.textTertiary)
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
                    LumaTheme.deepBlack.ignoresSafeArea()
                    VStack(spacing: LumaTheme.spacingMD) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(LumaTheme.textTertiary)
                        Text(error)
                            .font(.system(size: LumaTheme.bodySize))
                            .foregroundStyle(LumaTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 80)
                    }
                }
            }
        }
        .task { await viewModel.loadItem(id: itemId) }
    }
}
