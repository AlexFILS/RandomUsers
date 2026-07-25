//
//  UserDetailsViewModelTests.swift
//  RandomUsersTests
//
//  Created by Alexandru Mihai on 24/07/2026.
//

import Testing
import Foundation
@testable import RandomUsers

@MainActor
struct UserDetailsViewModelTests {
    
    private static func makeUser(
        identificationValue: String? = "1101776T"
    ) -> UserModel {
        UserModel(
            gender: .female,
            name: Name(title: "Miss", first: "Jane", last: "Doe"),
            location: Location(
                street: Street(number: 12, name: "Main St"),
                city: "Springfield",
                state: "Illinois",
                country: "USA",
                postcode: "62704",
                coordinates: Coordinates(latitude: "1.0", longitude: "1.0"),
                timezone: TimeZoneInfo(offset: "+1:00", description: "Paris")
            ),
            email: "jane.doe@example.com",
            login: Login(uuid: "u1", username: "janedoe1", password: "x", salt: "x", md5: "x", sha1: "x", sha256: "x"),
            dateOfBirth: DateInfo(date: Date(timeIntervalSince1970: 0), age: 42),
            registered: DateInfo(date: Date(timeIntervalSince1970: 0), age: 5),
            phone: "555-0100",
            cell: "555-0101",
            identification: UserIdentification(name: "PPS", value: identificationValue),
            picture: Picture(large: "large.jpg", medium: "medium.jpg", thumbnail: "thumb.jpg"),
            nationality: "US"
        )
    }
    
    @Test
    func fullNameCombinesFirstAndLastName() {
        let viewModel = UserDetailsViewModel(user: Self.makeUser(), onBack: {})
        
        #expect(viewModel.fullName == "Jane Doe")
    }
    
    @Test
    func usernameDisplayIsPrefixedWithAtSign() {
        let viewModel = UserDetailsViewModel(user: Self.makeUser(), onBack: {})
        
        #expect(viewModel.usernameDisplay == "@janedoe1")
    }
    
    @Test
    func avatarUsesMediumPictureRatherThanThumbnailOrLarge() {
        let viewModel = UserDetailsViewModel(user: Self.makeUser(), onBack: {})
        
        #expect(viewModel.avatarURLString == "medium.jpg")
    }
    
    @Test
    func sectionsGroupAllUserDetails() {
        let viewModel = UserDetailsViewModel(user: Self.makeUser(), onBack: {})
        
        #expect(viewModel.sections.map(\.title) == ["Personal", "Contact", "Address", "Account"])
    }
    
    @Test
    func identificationRowUsesItsOwnNameAsTitle() {
        let viewModel = UserDetailsViewModel(user: Self.makeUser(), onBack: {})
        
        let personalSection = viewModel.sections.first { $0.title == "Personal" }
        let identificationRow = personalSection?.rows.first { $0.title == "PPS" }
        
        #expect(identificationRow?.value == "1101776T")
    }
    
    @Test
    func identificationRowFallsBackToNotAvailableWhenValueIsMissing() {
        let viewModel = UserDetailsViewModel(user: Self.makeUser(identificationValue: nil), onBack: {})
        
        let personalSection = viewModel.sections.first { $0.title == "Personal" }
        let identificationRow = personalSection?.rows.first { $0.title == "PPS" }
        
        #expect(identificationRow?.value == "Not available")
    }
    
    @Test
    func addressSectionContainsFullLocationDetails() {
        let viewModel = UserDetailsViewModel(user: Self.makeUser(), onBack: {})
        
        let addressSection = viewModel.sections.first { $0.title == "Address" }
        
        #expect(addressSection?.rows.first { $0.title == "Street" }?.value == "12 Main St")
        #expect(addressSection?.rows.first { $0.title == "City" }?.value == "Springfield")
        #expect(addressSection?.rows.first { $0.title == "Postcode" }?.value == "62704")
    }

    @Test
    func goingBackReportsTheIntentExactlyOnce() {
        final class BackSpy {
            private(set) var count = 0

            func record() {
                count += 1
            }
        }

        let spy = BackSpy()
        let viewModel = UserDetailsViewModel(user: Self.makeUser(), onBack: spy.record)

        viewModel.goBack()

        // The toolbar button used to call the coordinator directly, so this was untestable.
        #expect(spy.count == 1)
    }
}
