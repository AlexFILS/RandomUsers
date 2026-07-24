//
//  UsersPaginationConfiguration.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import Foundation
import Networking

struct UsersPaginationConfiguration: Sendable {
    let resultsPerPage: Int
    let maxPage: Int
    let seed: String
    let prefetchOffsetFromEnd: Int

    // `prefetchOffsetFromEnd: 2` triggers the next fetch when the 3rd-last row appears
    // (see `Paginator.init`'s doc comment for the rank convention).
    static let `default` = UsersPaginationConfiguration(
        resultsPerPage: 20,
        maxPage: 2,
        seed: "abc",
        prefetchOffsetFromEnd: 2
    )

    func endpoint(forPage page: Int) -> Endpoint {
        // `randomuser.me` pages are 1-indexed; page 0 and page 1 return the same
        // results. Our `currentPage` is 0-indexed, so shift by one here.
        Endpoint(
            path: Constants.Networking.usersEndpoint,
            queryItems: [
                URLQueryItem(name: "page", value: String(page + 1)),
                URLQueryItem(name: "results", value: String(resultsPerPage)),
                URLQueryItem(name: "seed", value: seed)
            ]
        )
    }
}
