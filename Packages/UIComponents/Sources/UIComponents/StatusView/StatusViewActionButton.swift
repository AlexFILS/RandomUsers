//
//  StatusViewActionButton.swift.swift
//  UIComponents
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

struct StatusViewActionButton: View {
    private let title: String
    private let foregroundColor: Color
    private let action: () -> Void

    init(
        _ title: String,
        foregorundColor: Color = .black,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.foregroundColor = foregorundColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.white.opacity(0.2))
                .clipShape(.rect(cornerRadius: 10))
        }
    }
}
