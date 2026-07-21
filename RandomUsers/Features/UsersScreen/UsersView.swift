//
//  UsersView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

struct UsersView: View {
    @Environment(Coordinator.self) private var coordinator
    let viewModel: UsersViewModel

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
                coordinator.push(.userDetails(id: user.id))
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
            AsyncImage(url: URL(string: user.picture.thumbnail)) { image in
                image.resizable()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

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
        UsersView(viewModel: UsersViewModel(service: UsersServiceStub()))
    }
    .environment(Coordinator())
}
