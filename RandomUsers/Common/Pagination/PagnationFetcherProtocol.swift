//
//  PagnationFetcherProtocol.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

protocol PagnationFetcherProtocol {
    associatedtype Item

    func fetchPage(_ page: Int) async throws -> [Item]
}
