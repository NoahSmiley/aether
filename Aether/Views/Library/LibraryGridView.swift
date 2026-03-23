import SwiftUI
import NukeUI

struct LibraryGridView: View {
    let parentId: String?
    let includeTypes: [String]?
    let title: String

    @State private var viewModel: LibraryViewModel

    private let columns = [
        GridItem(.adaptive(minimum: LumaTheme.posterWidth + 20), spacing: 30)
    ]

    init(parentId: String?, includeTypes: [String]?, title: String) {
        self.parentId = parentId
        self.includeTypes = includeTypes
        self.title = title
        self._viewModel = State(initialValue: LibraryViewModel(
            parentId: parentId ?? "",
            includeTypes: includeTypes
        ))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LumaTheme.spacingLG) {
                // Sort/filter controls
                sortControls

                // Grid
                if viewModel.isLoading && viewModel.items.isEmpty {
                    loadingView
                } else if let error = viewModel.error, viewModel.items.isEmpty {
                    errorView(error)
                } else {
                    LazyVGrid(columns: columns, spacing: 40) {
                        ForEach(viewModel.items) { item in
                            NavigationLink(value: item.id) {
                                PosterCard(item: item)
                            }
                            .buttonStyle(.card)
                            .task {
                                await viewModel.loadMoreIfNeeded(currentItem: item)
                            }
                        }
                    }
                    .padding(.horizontal, 50)

                    if viewModel.isLoadingMore {
                        HStack(spacing: LumaTheme.spacingMD) {
                            ProgressView()
                                .tint(LumaTheme.textTertiary)
                            Text("Loading more...")
                                .font(.system(size: LumaTheme.captionSize))
                                .foregroundStyle(LumaTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LumaTheme.spacingXL)
                        .transition(.opacity)
                    }
                }
            }
            .padding(.bottom, LumaTheme.spacingXXL)
        }
        .background(LumaTheme.deepBlack)
        .navigationTitle(title)
        .navigationDestination(for: String.self) { itemId in
            DetailView(itemId: itemId)
        }
        .task {
            if viewModel.items.isEmpty {
                await viewModel.loadItems()
            }
        }
    }

    // MARK: - Loading / Error States

    private var loadingView: some View {
        VStack(spacing: LumaTheme.spacingMD) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.system(size: LumaTheme.captionSize))
                .foregroundStyle(LumaTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: LumaTheme.spacingMD) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(LumaTheme.textTertiary)
            Text(error)
                .foregroundStyle(.red)
                .font(.system(size: LumaTheme.bodySize))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    // MARK: - Sort Controls

    private var sortControls: some View {
        HStack(spacing: LumaTheme.spacingSM) {
            Spacer()

            Menu {
                Button("Name") { Task { await viewModel.changeSort("SortName") } }
                Button("Date Added") { Task { await viewModel.changeSort("DateCreated") } }
                Button("Release Date") { Task { await viewModel.changeSort("PremiereDate") } }
                Button("Rating") { Task { await viewModel.changeSort("CommunityRating") } }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 18))
                    Text(sortLabel)
                        .font(.system(size: LumaTheme.captionSize, weight: .medium))
                }
                .foregroundStyle(LumaTheme.textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                Task { await viewModel.toggleSortOrder() }
            } label: {
                Image(systemName: viewModel.sortOrder == "Ascending" ? "arrow.up" : "arrow.down")
                    .font(.system(size: 20))
                    .foregroundStyle(LumaTheme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 50)
        .padding(.top, LumaTheme.spacingMD)
    }

    private var sortLabel: String {
        switch viewModel.sortBy {
        case "SortName": return "Name"
        case "DateCreated": return "Date Added"
        case "PremiereDate": return "Release Date"
        case "CommunityRating": return "Rating"
        default: return "Name"
        }
    }
}
