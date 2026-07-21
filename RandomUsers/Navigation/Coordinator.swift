//
//  Coordinator.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

@MainActor
@Observable
final class Coordinator {
    var path = NavigationPath()
    
    func push(_ route: Route) {
        path.append(route)
    }
    
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}
