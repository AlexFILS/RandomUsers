//
//  UserRow.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import SwiftUI

struct UserRow: View {
    let user: UserModel
    
    init(user: UserModel) {
        self.user = user
    }
    
    var body: some View {
        HStack(alignment: .top) {
            AsyncImageWrapper(
                url: user.picture.thumbnail,
                size: 44
            ) {
                Text(initials)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.labelColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.primaryColor.opacity(0.3))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("\(user.name.first) \(user.name.last)")
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
                    .font(Font.system(size: 13))
                    .foregroundStyle(Theme.labelSecondaryColor)
                Image(systemName: "star")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(Theme.labelSecondaryColor)
            }
        }
    }

    private var initials: String {
        "\(user.name.first.prefix(1))\(user.name.last.prefix(1))".uppercased()
    }
}
