//
//  StatusViewType.swift
//  UIComponents
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import struct SwiftUI.Color

public enum StatusViewType {
    case info
    case error
    case success
    
    var backgroundColor: Color {
        switch self {
        case .info:
            return .orange.opacity(0.8)
        case .error:
            return .red
        case .success:
            return .green.opacity(0.8)
        }
    }
    
    var icon: String {
        switch self {
        case .info:
            return "info.circle"
        case .error:
            return "exclamationmark.triangle"
        case .success:
            return "checkmark.circle"
        }
    }
}
