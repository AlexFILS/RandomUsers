//
//  UsersView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Networking
import SwiftUI
import UIComponents

struct UsersView: View {
    @Environment(Coordinator.self) private var coordinator
    @State private var viewModel: UsersViewModel
    
    init(viewModel: UsersViewModel? = nil) {
        _viewModel = State(
            initialValue: viewModel ?? UsersViewModel(
                service: NetworkingClient(
                    baseURL: Constants.Networking.baseURL
                )
            )
        )
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
        }
        .task {
            await viewModel.fetchUsersIfNeeded()
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
    
    private var usersList: some View {
        List {
            ForEach(
                Array(
                    viewModel.displayedUsers.enumerated()
                ),
                id: \.element.id
            ) { index, user in
                Button {
                    viewModel.cancelSearchTask()
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
            if viewModel.isFetchingNextPage {
                nextPageLoadingIndicator
            }
        }
        .listStyle(.plain)
    }

    private var nextPageLoadingIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(Theme.accentColor)
            Spacer()
        }
        .listRowSeparator(.hidden)
    }
}



#Preview {
    NavigationStack {
        UsersView(
            viewModel: UsersViewModel(
                service: UsersServiceStub()
            )
        )
    }
    .environment(Coordinator())
}
