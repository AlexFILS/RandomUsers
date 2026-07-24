//
//  UserRow.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import SwiftUI

struct UserRow: View {
    let user: UserModel

    /// Scales the avatar alongside the text so the row stays balanced at larger Dynamic Type
    /// sizes instead of leaving a fixed-size thumbnail next to overflowing labels.
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 44
    @ScaledMetric(relativeTo: .caption) private var starSize: CGFloat = 17

    init(user: UserModel) {
        self.user = user
    }

    var body: some View {
        HStack(alignment: .top) {
            AsyncImageWrapper(
                url: user.picture.thumbnail,
                size: avatarSize
            ) {
                Text(initials)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Theme.labelColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.primaryColor.opacity(0.3))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(fullName)
                    .foregroundStyle(Theme.labelColor)
                    .lineLimit(1)
                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(Theme.labelSecondaryColor)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .center, spacing: 6) {
                Text(user.registered.date, format: .dateTime.hour().minute())
                    .font(.footnote)
                    .foregroundStyle(Theme.labelSecondaryColor)
                Image(systemName: "star")
                    .resizable()
                    .scaledToFit()
                    .frame(width: starSize, height: starSize)
                    .foregroundStyle(Theme.labelSecondaryColor)
                    .accessibilityHidden(true)
            }
        }
    }

    private var fullName: String {
        "\(user.name.first) \(user.name.last)"
    }

    private var initials: String {
        "\(user.name.first.prefix(1))\(user.name.last.prefix(1))".uppercased()
    }
}
