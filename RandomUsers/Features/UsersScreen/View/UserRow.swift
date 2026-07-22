//
//  UserRow.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import SwiftUI

struct UserRow: View {
    let user: User
    
    init(user: User) {
        self.user = user
    }
    
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
