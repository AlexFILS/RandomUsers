//
//  SearchableModelProtocol.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

/// What a model exposes to be searched
protocol SearchableModelProtocol: Sendable {
    var searchableTerms: [String] { get }
}
