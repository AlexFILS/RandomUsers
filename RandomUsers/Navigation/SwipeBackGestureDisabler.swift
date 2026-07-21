//
//  SwipeBackGestureDisabler.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

private struct SwipeBackGestureDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        DisablingViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    private final class DisablingViewController: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

extension View {
    /// Disables the interactive swipe-to-go-back gesture for as long as this view is on screen.
    func disablesSwipeBackGesture() -> some View {
        background(SwipeBackGestureDisabler())
    }
}
