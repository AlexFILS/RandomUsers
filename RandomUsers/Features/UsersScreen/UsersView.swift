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
                placeholder: String(localized: "Search for user...")
            )
            Button(action: viewModel.cancelSearch) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.labelColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel search")
        }
        .padding(.horizontal, 8)
    }
    
    private var noSearchResultsStatusView: some View {
        StatusView(
            state: .info,
            message: Constants.ErrorDescription.noMatchingUsers,
            primaryButtonTitle: String(localized: "OK"),
            primaryAction: viewModel.clearSearchInput
        )
    }
    
    @ViewBuilder
    private var errorStatusView: some View {
        if viewModel.isInitialFetchFailure {
            StatusView(
                state: .error,
                message: viewModel.errorDescription,
                primaryButtonTitle: String(localized: "Retry"),
                primaryAction: viewModel.retryTapped
            )
        } else {
            StatusView(
                state: .error,
                message: viewModel.errorDescription,
                primaryButtonTitle: String(localized: "OK"),
                secondaryButtonTitle: String(localized: "Retry"),
                primaryAction: viewModel.clearErrors,
                secondaryAction: viewModel.retryTapped
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
                }
            }
        }
    }
    
    /// Paging happens *below* the content the user is already reading - it must not blur or
    /// disable the list the way `BaseContentView`'s blocking loading state does.
    private var nextPageIndicator: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(Theme.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .accessibilityLabel("Loading more users")
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
