//
//  PagnationFetcherProtocol.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

protocol PaginationFetcherProtocol {
    associatedtype Item: Sendable

    func fetchPage(_ page: Int) async throws -> [Item]
}
