//
//  UsersView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI
import UIComponents

struct UsersView: View {
    /// `@Bindable`, not `@State`: this view model is owned by `UsersFlowCoordinator` and outlives
    /// any one appearance of this view. Copying it into `@State` would claim an ownership this
    @Bindable private var viewModel: UsersViewModel

    init(viewModel: UsersViewModel) {
        _viewModel = Bindable(wrappedValue: viewModel)
    }

    private var overlayStatus: UsersViewModel.Status? {
        guard case .status(let status) = viewModel.overlay else { return nil }
        return status
    }

    var body: some View {
        BaseContentView(
            title: viewModel.screenTitle,
            isLoading: viewModel.overlay == .loading,
            interactionsDisabled: viewModel.overlay != nil,
            onSearch: viewModel.startSearching
        ) {
            VStack {
                if viewModel.isSearchBarVisible {
                    searchBar
                }
                switch viewModel.content {
                case .users(let users):
                    usersList(users)
                case .empty(let status):
                    statusView(status)
                }
            }
            .allowsHitTesting(overlayStatus == nil)
            .background(Theme.backgroundColorPrimary)
            .blur(radius: overlayStatus == nil ? 0 : 8)
        }
        .overlay {
            if let overlayStatus {
                statusView(overlayStatus)
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
    
    private func statusView(_ status: UsersViewModel.Status) -> some View {
        StatusView(
            state: status.kind.statusViewType,
            title: status.title,
            message: status.message,
            primaryButtonTitle: status.primaryButton.title,
            secondaryButtonTitle: status.secondaryButton?.title,
            primaryAction: { viewModel.perform(status.primaryButton.action) },
            secondaryAction: status.secondaryButton.map { button in
                { viewModel.perform(button.action) }
            }
        )
    }

    private func usersList(_ users: [UserModel]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(
                    Array(users.enumerated()),
                    id: \.element.id
                ) { index, user in
                    Button {
                        viewModel.select(user)
                    } label: {
                        UserRow(user: user)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onAppear {
                        viewModel.prefetchNextPageIfNeeded(at: index)
                    }
                    Divider()
                        .padding(.leading, 16)
                }
                switch viewModel.footer {
                case .loadingNextPage:
                    nextPageIndicator
                case .retryNextPage:
                    nextPageRetryButton
                case nil:
                    EmptyView()
                }
            }
        }
    }
    
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
        UsersView(viewModel: .develop())
    }
}

#Preview("Error") {
    NavigationStack {
        UsersView(viewModel: .developWithError())
    }
}
#endif
