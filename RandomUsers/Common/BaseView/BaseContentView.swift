//
//  BaseContentView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

struct BaseContentView<Content: View>: View {
    private let title: String
    private let isLoading: Bool
    private let backgroundColor: Color
    @ViewBuilder private let content: Content
    
    init(
        title: String = "",
        isLoading: Bool = false,
        backgroundColor: Color = Theme.primaryColor,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.title = title
        self.backgroundColor = backgroundColor
        self.content = content()
    }
    
    var body: some View {
        content
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    ProgressView {
                        Text("Loading...") // TODO: Extract to localizable
                            .foregroundStyle(Theme.accentColor)
                    }
                    .progressViewStyle(.circular)
                    .tint(Theme.accentColor)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .background(backgroundColor)
    }
}
