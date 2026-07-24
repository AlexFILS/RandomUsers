//
//  AsyncImageWrapper.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

struct AsyncImageWrapper<FailureView: View>: View {
    private let url: String
    private let size: CGFloat
    private let failureView: FailureView
    
    init(
        url: String,
        size: CGFloat,
        @ViewBuilder failureView: () -> FailureView
    ) {
        self.url = url
        self.size = size
        self.failureView = failureView()
    }
    
    var body: some View {
        AsyncImage(
            url: URL(string: url)
        ) { phase in
            switch phase {
            case .empty:
                Color.gray.opacity(0.2)
            case .success(let image):
                image.resizable()
            case .failure:
                failureView
            @unknown default:
                Color.gray.opacity(0.2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

extension AsyncImageWrapper where FailureView == DefaultAsyncImageFailureView {
    init(
        url: String,
        size: CGFloat
    ) {
        self.init(url: url, size: size) {
            DefaultAsyncImageFailureView()
        }
    }
}

struct DefaultAsyncImageFailureView: View {
    var body: some View {
        Image(systemName: "exclamationmark.triangle")
            .resizable()
            .scaledToFit()
            .padding(8)
            .foregroundStyle(Theme.labelSecondaryColor)
    }
}
