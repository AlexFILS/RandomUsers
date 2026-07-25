//
//  StatusKind+StatusView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 25/07/2026.
//

import UIComponents

extension StatusKind {
    /// Translates the view models' UI-free `StatusKind` into the `UIComponents` type. Lives on
    /// the view side of the boundary on purpose: it is the only place that needs to know both,
    /// which is what lets view models stay free of SwiftUI.
    var statusViewType: StatusViewType {
        switch self {
        case .info:
            return .info
        case .error:
            return .error
        }
    }
}
