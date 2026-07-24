//
//  DetailSectionView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 24/07/2026.
//

import SwiftUI

struct DetailSectionView: View {
    let section: UserDetailsViewModel.DetailSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.headline)
                .foregroundStyle(Theme.labelColor)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 8) {
                ForEach(section.rows) { row in
                    DetailRowView(row: row)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    DetailSectionView(
        section: UserDetailsViewModel.DetailSection(
            title: "Contact",
            rows: [
                UserDetailsViewModel.DetailRow(title: "Email", value: "jane.doe@example.com"),
                UserDetailsViewModel.DetailRow(title: "Phone", value: "555-0100")
            ]
        )
    )
    .padding()
}
#endif
