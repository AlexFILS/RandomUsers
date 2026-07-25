//
//  StatusPresentation.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 25/07/2026.
//

enum StatusKind: Equatable {
    case info
    case error
}

struct StatusPresentation<Action: Equatable>: Equatable {
    struct Button: Equatable {
        let title: String
        let action: Action
    }

    let kind: StatusKind
    let title: String
    let message: String
    let primaryButton: Button
    let secondaryButton: Button?

    init(
        kind: StatusKind,
        title: String,
        message: String,
        primaryButton: Button,
        secondaryButton: Button? = nil
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
    }
}
