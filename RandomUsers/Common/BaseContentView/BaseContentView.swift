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
    private let onSearch: (() -> Void)?
    @ViewBuilder private let content: Content

    init(
        title: String = "",
        isLoading: Bool = false,
        backgroundColor: Color = Theme.primaryColor,
        onSearch: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.title = title
        self.backgroundColor = backgroundColor
        self.onSearch = onSearch
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.labelColor)
                }
                if let onSearch {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onSearch) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Theme.labelColor)
                        }
                    }
                }
            }
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .background(backgroundColor)
    }
}
