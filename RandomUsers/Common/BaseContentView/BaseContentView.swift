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
    private let interactionsDisabled: Bool
    private let backgroundColor: Color
    private let onSearch: (() -> Void)?
    @ViewBuilder private let content: Content
    
    init(
        title: String = "",
        isLoading: Bool = false,
        interactionsDisabled: Bool = false,
        backgroundColor: Color = Theme.primaryColor,
        onSearch: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.interactionsDisabled = interactionsDisabled
        self.title = title
        self.backgroundColor = backgroundColor
        self.onSearch = onSearch
        self.content = content()
    }
    
    var body: some View {
        content
            .blur(radius: isLoading ? 8 : 0)
            .allowsHitTesting(!isLoading)
            .overlay {
                if isLoading {
                    ProgressView {
                        Text("Loading...")
                            .foregroundStyle(Theme.accentColor)
                    }
                    .progressViewStyle(.circular)
                    .tint(Theme.accentColor)
                    .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .animation(.default, value: isLoading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.labelColor)
                        .accessibilityAddTraits(.isHeader)
                }
                if let onSearch {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onSearch) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Theme.labelColor)
                        }
                        .disabled(interactionsDisabled)
                        .accessibilityLabel("Search")
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .background(backgroundColor)
    }
}
