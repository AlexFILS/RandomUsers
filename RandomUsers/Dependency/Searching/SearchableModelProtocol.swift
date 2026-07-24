//
//  SearchableModelProtocol.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

protocol SearchableModelProtocol: Sendable {
    var name: Name { get }
    var email: String { get }
}
