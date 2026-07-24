//
//  StatusView.swift
//  UIComponents
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

public struct StatusView: View {
    private let state: StatusViewType
    private let title: String
    private let message: String
    private let primaryButtonTitle: String
    private let secondaryButtonTitle: String?
    private let foregroundColor: Color
    private let primaryAction: () -> Void
    private var secondaryAction: (() -> Void)?
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 60

    /// All copy is supplied by the caller - the package owns no strings of its own, so a host
    /// app localizes every word of this view from its own String Catalog.
    public init(
        state: StatusViewType,
        title: String,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        foregroundColor: Color = .black,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.state = state
        self.title = title
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
                .font(.system(size: iconSize))
                .foregroundStyle(foregroundColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.title)
                .bold()
                .foregroundStyle(foregroundColor)
                .accessibilityAddTraits(.isHeader)
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
