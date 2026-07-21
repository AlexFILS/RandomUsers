//
//  UserDetailsView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

struct UserDetailsView: View {
    @Environment(Coordinator.self) private var coordinator
    let user: User

    var body: some View {
        BaseContentView(title: "\(user.name.first) \(user.name.last)") {
            details
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: coordinator.pop) {
                    Image(systemName: "chevron.backward")
                        .foregroundStyle(Theme.labelColor)
                }
            }
        }
        .disablesSwipeBackGesture()
    }

    private var details: some View {
        ScrollView {
            VStack(spacing: 16) {
                AsyncImageWrapper(url: user.picture.large, size: 120)

                VStack(spacing: 8) {
                    infoRow(title: "Email", value: user.email)
                    infoRow(title: "Phone", value: user.phone)
                    infoRow(title: "Cell", value: user.cell)
                    infoRow(title: "Nationality", value: user.nationality)
                    infoRow(
                        title: "Address",
                        value: "\(user.location.street.number) \(user.location.street.name), \(user.location.city)"
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Theme.labelColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        UserDetailsView(user: .preview)
    }
    .environment(Coordinator())
}

private extension User {
    static var preview: User {
        let url = Bundle.main.url(forResource: "UsersResponse", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(UsersResponse.self, from: data).results[0]
    }
}
