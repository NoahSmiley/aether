import SwiftUI

struct DetailView: View {
    let itemId: String
    @State private var viewModel = MediaDetailViewModel()

    var body: some View {
        ZStack {
            LumaTheme.deepBlack.ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: LumaTheme.spacingMD) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .font(.system(size: LumaTheme.captionSize))
                        .foregroundStyle(LumaTheme.textTertiary)
                }
            } else if let item = viewModel.item {
                switch item.type {
                case .series:
                    ShowDetailView(item: item, viewModel: viewModel)
                default:
                    MovieDetailView(item: item, viewModel: viewModel)
                }
            } else {
                VStack(spacing: LumaTheme.spacingMD) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(LumaTheme.textTertiary)
                    Text(viewModel.error ?? "Unable to load")
                        .font(.system(size: LumaTheme.bodySize))
                        .foregroundStyle(LumaTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 80)
                    #if DEBUG
                    Text("Item ID: \(itemId)")
                        .font(.system(size: 16))
                        .foregroundStyle(LumaTheme.textTertiary)
                    #endif
                }
            }
        }
        .task {
            #if DEBUG
            print("[DetailView] Loading item: \(itemId)")
            #endif
            await viewModel.loadItem(id: itemId)
            #if DEBUG
            print("[DetailView] Result - item: \(viewModel.item?.name ?? "nil"), error: \(viewModel.error ?? "nil")")
            #endif
        }
    }
}
