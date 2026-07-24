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
    
    @ObservationIgnored private(set) lazy var sections: [DetailSection] = [
        Self.personalSection(for: user),
        Self.contactSection(for: user),
        Self.addressSection(for: user),
        Self.accountSection(for: user)
    ]
    
    @ObservationIgnored private let user: UserModel
    
    init(user: UserModel) {
        self.user = user
        fullName = "\(user.name.first) \(user.name.last)"
        usernameDisplay = "@\(user.login.username)"
        avatarURLString = user.picture.medium
    }
    
    private static func personalSection(for user: UserModel) -> DetailSection {
        DetailSection(
            title: String(localized: .personalSectionTitle),
            rows: [
                DetailRow(title: String(localized: .gender), value: user.gender.displayName),
                DetailRow(title: String(localized: .dateOfBirth), value: dateOfBirthDisplay(for: user.dateOfBirth)),
                DetailRow(title: String(localized: .nationality), value: user.nationality),
                DetailRow(
                    title: user.identification.name,
                    value: user.identification.value ?? String(localized: .notAvailable)
                )
            ]
        )
    }
    
    private static func contactSection(for user: UserModel) -> DetailSection {
        DetailSection(
            title: String(localized: .contactSectionTitle),
            rows: [
                DetailRow(title: String(localized: .email), value: user.email),
                DetailRow(title: String(localized: .phone), value: user.phone),
                DetailRow(title: String(localized: .cell), value: user.cell)
            ]
        )
    }
    
    private static func addressSection(for user: UserModel) -> DetailSection {
        let location = user.location
        return DetailSection(
            title: String(localized: .addressSectionTitle),
            rows: [
                DetailRow(
                    title: String(localized: .street),
                    value: "\(location.street.number) \(location.street.name)"
                ),
                DetailRow(title: String(localized: .city), value: location.city),
                DetailRow(title: String(localized: .state), value: location.state),
                DetailRow(title: String(localized: .country), value: location.country),
                DetailRow(title: String(localized: .postcode), value: location.postcode),
                DetailRow(title: String(localized: .timezone), value: timezoneDisplay(for: location.timezone))
            ]
        )
    }
    
    private static func accountSection(for user: UserModel) -> DetailSection {
        DetailSection(
            title: String(localized: .accountSectionTitle),
            rows: [
                DetailRow(title: String(localized: .username), value: user.login.username),
                DetailRow(
                    title: String(localized: .registered),
                    value: user.registered.date.formatted(dateFormatStyle)
                )
            ]
        )
    }
    
    private static func dateOfBirthDisplay(for dateOfBirth: DateInfo) -> String {
        String(localized: .dateOfBirthWithAge(dateOfBirth.date.formatted(dateFormatStyle), dateOfBirth.age))
    }
    
    private static func timezoneDisplay(for timezone: TimeZoneInfo) -> String {
        "UTC\(timezone.offset) · \(timezone.description)"
    }
    
    private static let dateFormatStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)
}
