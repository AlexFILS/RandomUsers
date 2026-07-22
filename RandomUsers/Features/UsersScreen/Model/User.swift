//
//  User.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

struct User: Decodable, Hashable, Identifiable {
    let gender: Gender
    let name: Name
    let location: Location
    let email: String
    let login: Login
    let dateOfBirth: DateInfo
    let registered: DateInfo
    let phone: String
    let cell: String
    let identification: UserIdentification
    let picture: Picture
    let nationality: String

    var id: String { login.uuid }

    private enum CodingKeys: String, CodingKey {
        case gender, name, location, email, login
        case dateOfBirth = "dob"
        case registered, phone, cell
        case identification = "id"
        case picture
        case nationality = "nat"
    }
}

extension User: SearchableModelProtocol {
}
