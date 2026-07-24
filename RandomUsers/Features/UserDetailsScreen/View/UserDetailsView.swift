//
//  UserDetailsView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

struct UserDetailsView: View {
    @State private var viewModel: UserDetailsViewModel
    private let coordinator: UserDetailsFlowCoordinatorProtocol

    init(viewModel: UserDetailsViewModel, coordinator: UserDetailsFlowCoordinatorProtocol) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        BaseContentView(title: viewModel.fullName) {
            details
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: coordinator.pop) {
                    Image(systemName: "chevron.backward")
                        .foregroundStyle(Theme.labelColor)
                }
            }
        }
        .disablesSwipeBackGesture()
    }

    private var details: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                sectionsList
            }
            .padding(.vertical, 24)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            AsyncImageWrapper(url: viewModel.avatarURLString, size: 120)
            Text(viewModel.usernameDisplay)
                .font(.subheadline)
                .foregroundStyle(Theme.labelSecondaryColor)
        }
    }

    private var sectionsList: some View {
        VStack(spacing: 20) {
            ForEach(viewModel.sections) { section in
                DetailSectionView(section: section)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        UserDetailsView(
            viewModel: UserDetailsViewModel(user: .preview),
            coordinator: PreviewUserDetailsFlowCoordinator()
        )
    }
}

private final class PreviewUserDetailsFlowCoordinator: UserDetailsFlowCoordinatorProtocol {
    func pop() {}
}

private extension UserModel {
    static var preview: UserModel {
        let url = Bundle.main.url(forResource: "UsersResponse", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(UsersResponse.self, from: data).results[0]
    }
}
