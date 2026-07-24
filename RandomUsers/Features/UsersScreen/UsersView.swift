//
//  UsersView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI
import UIComponents

struct UsersView: View {
    @State private var viewModel: UsersViewModel
    private let coordinator: UsersFlowCoordinatorProtocol
    
    init(
        viewModel: UsersViewModel,
        coordinator: UsersFlowCoordinatorProtocol
    ) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }
    
    var body: some View {
        BaseContentView(
            title: viewModel.screenTitle,
            isLoading: viewModel.isLoading,
            interactionsDisabled: viewModel.hasError,
            onSearch: viewModel.startSearching
        ) {
            VStack {
                if viewModel.isSearchBarVisible {
                    searchBar
                }
                if viewModel.hasNoSearchResults {
                    noSearchResultsStatusView
                } else {
                    usersList
                }
            }
            .allowsHitTesting(!viewModel.hasError)
            .background(Theme.backgroundColorPrimary)
            .blur(radius: viewModel.hasError ? 8 : 0)
        }
        .overlay {
            if viewModel.hasError {
                errorStatusView
            }
        }
        .task {
            await viewModel.fetchUsersIfNeeded()
        }
        .task(id: viewModel.searchText) {
            await viewModel.search()
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            SearchBar(
                text: $viewModel.searchText,
                placeholder: String(localized: .searchPlaceholder)
            )
            Button(action: viewModel.cancelSearch) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.labelColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
    }
    
    private var noSearchResultsStatusView: some View {
        StatusView(
            state: .info,
            title: String(localized: .statusInfoTitle),
            message: Constants.ErrorDescription.noMatchingUsers,
            primaryButtonTitle: String(localized: .ok),
            primaryAction: viewModel.clearSearchInput
        )
    }
    
    @ViewBuilder
    private var errorStatusView: some View {
        if viewModel.isInitialFetchFailure {
            // Dismissing would reveal a blank screen, so retrying is the only way forward.
            StatusView(
                state: .error,
                title: String(localized: .statusErrorTitle),
                message: viewModel.errorDescription,
                primaryButtonTitle: String(localized: .retry),
                primaryAction: viewModel.retryTapped
            )
        } else if viewModel.canRetry {
            StatusView(
                state: .error,
                title: String(localized: .statusErrorTitle),
                message: viewModel.errorDescription,
                primaryButtonTitle: String(localized: .ok),
                secondaryButtonTitle: String(localized: .retry),
                primaryAction: viewModel.clearErrors,
                secondaryAction: viewModel.retryTapped
            )
        } else {
            // A search failure has no fetch behind it; "Retry" here would do nothing at all.
            StatusView(
                state: .error,
                title: String(localized: .statusErrorTitle),
                message: viewModel.errorDescription,
                primaryButtonTitle: String(localized: .ok),
                primaryAction: viewModel.clearErrors
            )
        }
    }
    
    private var usersList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(
                    Array(
                        viewModel.displayedUsers.enumerated()
                    ),
                    id: \.element.id
                ) { index, user in
                    Button {
                        coordinator.showUserDetails(for: user)
                    } label: {
                        UserRow(user: user)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    // Deduplication of repeat appearances lives in the view model, so that a
                    // fetch which is cancelled or fails can reset it and let this row ask again.
                    .onAppear {
                        viewModel.prefetchNextPageIfNeeded(at: index)
                    }
                    Divider()
                        .padding(.leading, 16)
                }
                if viewModel.isFetchingNextPage {
                    nextPageIndicator
                } else if viewModel.hasPendingPageRetry {
                    nextPageRetryButton
                }
            }
        }
    }
    
    /// Dismissing a paging error parks pagination rather than silently re-firing the fetch
    /// (see `UsersViewModel.clearErrors()`). The row whose appearance would normally resume it
    /// has already appeared and won't again, so this footer is the way back.
    private var nextPageRetryButton: some View {
        Button(action: viewModel.retryPendingPage) {
            Label(
                String(localized: .tapToLoadMore),
                systemImage: "arrow.clockwise"
            )
            .font(.subheadline)
            .foregroundStyle(Theme.accentColor)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    /// Paging happens *below* the content the user is already reading - it must not blur or
    /// disable the list the way `BaseContentView`'s blocking loading state does.
    private var nextPageIndicator: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(Theme.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        UsersView(
            viewModel: .develop(),
            coordinator: PreviewUsersFlowCoordinator()
        )
    }
}

#Preview("Error") {
    NavigationStack {
        UsersView(
            viewModel: .developWithError(),
            coordinator: PreviewUsersFlowCoordinator()
        )
    }
}

private final class PreviewUsersFlowCoordinator: UsersFlowCoordinatorProtocol {
    func showUserDetails(for user: UserModel) {}
}
#endif
