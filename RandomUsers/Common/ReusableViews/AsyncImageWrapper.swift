//
//  AsyncImageWrapper.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

struct AsyncImageWrapper: View {
    private let url: String
    private let size: CGFloat

    init(
        url: String,
        size: CGFloat
    ) {
        self.url = url
        self.size = size
    }

    var body: some View {
        AsyncImage(
            url: URL(
                string: url
            )
        ) { image in
            image.resizable()
        } placeholder: {
            Color.gray.opacity(0.2)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
