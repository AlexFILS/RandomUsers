//
//  StatusView.swift
//  UIComponents
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

public struct StatusView: View {
    private let state: StatusViewType
    private let message: String
    private let primaryButtonTitle: String
    private let secondaryButtonTitle: String?
    private let foregroundColor: Color
    private let primaryAction: () -> Void
    private var secondaryAction: (() -> Void)?

    public init(
        state: StatusViewType,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        foregroundColor: Color = .black,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.state = state
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.foregroundColor = foregroundColor
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: state.icon)
                .font(.system(size: 60))
                .foregroundStyle(foregroundColor)
            Text(state.title)
                .font(.title)
                .bold()
                .foregroundStyle(foregroundColor)
            Text(message)
                .font(.body)
                .foregroundStyle(foregroundColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            HStack {
                StatusViewActionButton(
                    primaryButtonTitle,
                    foregorundColor: foregroundColor,
                    action: primaryAction
                )
                
                if let secondaryAction,
                   let secondaryButtonTitle {
                    StatusViewActionButton(
                        secondaryButtonTitle,
                        foregorundColor: foregroundColor,
                        action: secondaryAction
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
        .padding(.vertical, 16)
        .background(state.backgroundColor.gradient)
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
