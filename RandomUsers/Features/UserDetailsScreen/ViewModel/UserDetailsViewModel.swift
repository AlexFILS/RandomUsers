//
//  UserDetailsViewModel.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 24/07/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class UserDetailsViewModel {
    struct DetailRow: Identifiable, Hashable {
        let title: String
        let value: String

        var id: String { title }
    }

    struct DetailSection: Identifiable, Hashable {
        let title: String
        let rows: [DetailRow]

        var id: String { title }
    }

    let fullName: String
    let usernameDisplay: String
    let avatarURLString: String
    let sections: [DetailSection]

    init(user: UserModel) {
        fullName = "\(user.name.first) \(user.name.last)"
        usernameDisplay = "@\(user.login.username)"
        avatarURLString = user.picture.medium
        sections = [
            Self.personalSection(for: user),
            Self.contactSection(for: user),
            Self.addressSection(for: user),
            Self.accountSection(for: user)
        ]
    }

    private static func personalSection(for user: UserModel) -> DetailSection {
        DetailSection(
            title: "Personal",
            rows: [
                DetailRow(title: "Gender", value: user.gender.rawValue.capitalized),
                DetailRow(title: "Date of Birth", value: dateOfBirthDisplay(for: user.dateOfBirth)),
                DetailRow(title: "Nationality", value: user.nationality),
                DetailRow(title: user.identification.name, value: user.identification.value ?? "Not available")
            ]
        )
    }

    private static func contactSection(for user: UserModel) -> DetailSection {
        DetailSection(
            title: "Contact",
            rows: [
                DetailRow(title: "Email", value: user.email),
                DetailRow(title: "Phone", value: user.phone),
                DetailRow(title: "Cell", value: user.cell)
            ]
        )
    }

    private static func addressSection(for user: UserModel) -> DetailSection {
        let location = user.location
        return DetailSection(
            title: "Address",
            rows: [
                DetailRow(title: "Street", value: "\(location.street.number) \(location.street.name)"),
                DetailRow(title: "City", value: location.city),
                DetailRow(title: "State", value: location.state),
                DetailRow(title: "Country", value: location.country),
                DetailRow(title: "Postcode", value: location.postcode),
                DetailRow(title: "Timezone", value: timezoneDisplay(for: location.timezone))
            ]
        )
    }

    private static func accountSection(for user: UserModel) -> DetailSection {
        DetailSection(
            title: "Account",
            rows: [
                DetailRow(title: "Username", value: user.login.username),
                DetailRow(title: "Registered", value: user.registered.date.formatted(dateFormatStyle))
            ]
        )
    }

    private static func dateOfBirthDisplay(for dateOfBirth: DateInfo) -> String {
        "\(dateOfBirth.date.formatted(dateFormatStyle)) (age \(dateOfBirth.age))"
    }

    private static func timezoneDisplay(for timezone: TimeZoneInfo) -> String {
        "UTC\(timezone.offset) · \(timezone.description)"
    }

    private static let dateFormatStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)
}
