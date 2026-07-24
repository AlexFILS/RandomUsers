//
//  DetailRowView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 24/07/2026.
//

import SwiftUI

struct DetailRowView: View {
    let row: UserDetailsViewModel.DetailRow

    var body: some View {
        HStack {
            Text(row.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(row.value)
                .font(.subheadline)
                .foregroundStyle(Theme.labelColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    DetailRowView(row: UserDetailsViewModel.DetailRow(title: "Email", value: "jane.doe@example.com"))
        .padding()
}
