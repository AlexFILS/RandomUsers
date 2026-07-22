//
//  SearchableCollectionProtocol.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

protocol SearchableCollectionProtocol {
    func search<T: SearchableModelProtocol>(query: String, in elements: [T]) async throws -> [T]
}
