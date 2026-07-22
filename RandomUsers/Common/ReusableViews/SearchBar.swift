//
//  SearchBar.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import SwiftUI
import UIKit

/// Small vridge between  UIKit and SwiftUI
/// In UIKit's SearchBar we get some elements 'for free', like the 'x' button inside the search bar.
///
/// The native cancel button is disabled: iOS 26 renders it with an automatic Liquid Glass
/// background that can't be overridden from here, so hiding the search bar is handled by a
/// plain SwiftUI button in `UsersView` instead.
struct SearchBar: UIViewRepresentable {
    @Binding private var text: String
    private let placeholder: String

    init(
        text: Binding<String>,
        placeholder: String
    ) {
        _text = text
        self.placeholder = placeholder
    }

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.showsCancelButton = false
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        guard !context.coordinator.hasBecomeFirstResponder else { return }
        context.coordinator.hasBecomeFirstResponder = true
        DispatchQueue.main.async {
            uiView.becomeFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UISearchBarDelegate {
        private let text: Binding<String>
        var hasBecomeFirstResponder = false

        init(text: Binding<String>) {
            self.text = text
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text.wrappedValue = searchText
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }
}
