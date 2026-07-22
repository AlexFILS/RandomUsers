//
//  SearchBar.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import SwiftUI

struct SearchBar: UIViewRepresentable {
    @Binding private var text: String
    private let placeholder: String
    private let onCancel: () -> Void

    init(
        text: Binding<String>,
        placeholder: String,
        onCancel: @escaping () -> Void
    ) {
        _text = text
        self.placeholder = placeholder
        self.onCancel = onCancel
    }

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.showsCancelButton = true
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
        Coordinator(text: $text, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UISearchBarDelegate {
        private let text: Binding<String>
        private let onCancel: () -> Void
        var hasBecomeFirstResponder = false

        init(text: Binding<String>, onCancel: @escaping () -> Void) {
            self.text = text
            self.onCancel = onCancel
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text.wrappedValue = searchText
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
            onCancel()
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }
}
