//
//  HTTPMethod.swift
//  Networking
//
//  Created by Alexandru Mihai on 21/07/2026.
//


public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}