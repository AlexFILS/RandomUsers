//
//  UsersView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Networking
import SwiftUI

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
            title: "Users",
            isLoading: viewModel.isLoading
        ) {
            usersList
        }
        .task {
            await viewModel.fetchUsersIfNeeded()
        }
    }
    
    private var usersList: some View {
        List(viewModel.users) { user in
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
        }
        .listStyle(.plain)
    }
}

private struct UserRow: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImageWrapper(
                url: user.picture.thumbnail,
                size: 44
            )
            VStack(alignment: .leading) {
                Text("\(user.name.first) \(user.name.last)")
                    .font(.headline)
                    .foregroundStyle(Theme.labelColor)
                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
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
