//
//  AppDependencies.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 24/07/2026.
//

import Networking

/// The app's composition root payload: every shared, protocol-typed service a coordinator
/// needs in order to build view models. Built once at launch and threaded down through
/// coordinators, so the app never holds more than one `NetworkingClient`/session.
struct AppDependencies {
    let service: ServiceProtocol
    let searchService: SearchableCollectionProtocol
}

extension AppDependencies {
    static func production() -> AppDependencies {
        AppDependencies(
            service: NetworkingClient(baseURL: Constants.Networking.baseURL),
            searchService: SearchService()
        )
    }
    
#if DEBUG
    static func develop() -> AppDependencies {
        AppDependencies(
            service: UsersServiceStub(),
            searchService: SearchService()
        )
    }
#endif
}
