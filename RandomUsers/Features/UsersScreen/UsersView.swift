//
//  ContentView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

struct UsersView: View {
    var body: some View {
        BaseContentView(title: "Users") {
            usersList
        }
    }
    
    private var usersList: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}
