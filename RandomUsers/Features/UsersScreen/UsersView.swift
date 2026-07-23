//
//  UsersView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI
import UIComponents

struct UsersView: View {
    @Environment(Coordinator.self) private var coordinator
    @State private var viewModel: UsersViewModel
    
    init(viewModel: UsersViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? .production())
    }
    
    var body: some View {
        BaseContentView(
            title: viewModel.screenTitle,
            isLoading: viewModel.isLoading,
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
            .background(Theme.backgroundColorPrimary)
            .blur(radius: viewModel.hasError ? 8 : 0)
            .allowsHitTesting(!viewModel.hasError)
            
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
                placeholder: "Search for user..."
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
            message: AppError.noMathcingUsers.description,
            primaryButtonTitle: "OK",
            primaryAction: viewModel.clearSearchInput
        )
    }
    
    @ViewBuilder
    private var errorStatusView: some View {
        if viewModel.isInitialFetchFailure {
            StatusView(
                state: .error,
                message: viewModel.errorDescription,
                primaryButtonTitle: "Retry",
                primaryAction: viewModel.retryTapped
            )
        } else {
            StatusView(
                state: .error,
                message: viewModel.errorDescription,
                primaryButtonTitle: "OK",
                secondaryButtonTitle: "Retry",
                primaryAction: viewModel.clearErrors,
                secondaryAction: viewModel.retryTapped
            )
        }
    }
    
    private var usersList: some View {
        List {
            ForEach(
                Array(
                    viewModel.displayedUsers.enumerated()
                ),
                id: \.element.id
            ) { index, user in
                Button {
                    coordinator.push(
                        .userDetails(
                            user
                        )
                    )
                } label: {
                    UserRow(user: user)
                }
                .buttonStyle(.plain)
                .onAppear {
                    viewModel.prefetchNextPageIfNeeded(at: index)
                }
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        UsersView(
            viewModel: UsersViewModel(
                service: UsersServiceStub(),
                searchService: UserSearchService()
            )
        )
    }
    .environment(Coordinator())
}
