//
//  PaginationConfigurationProtocol.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 25/07/2026.
//

protocol PaginationConfigurationProtocol: Sendable {
    var maxPage: Int { get }
    var prefetchOffsetFromEnd: Int { get }
}
