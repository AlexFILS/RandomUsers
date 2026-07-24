//
//  ModelDecodingEdgeCaseTests.swift
//  RandomUsersTests
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Testing
import Foundation
@testable import RandomUsers

struct ModelDecodingEdgeCaseTests {
    
    // MARK: - Location.postcode
    
    @Test func decodesPostcodeWhenProvidedAsNumber() throws {
        let json = Data(#"""
        {"street":{"number":1,"name":"Main St"},"city":"Dublin","state":"Dublin","country":"Ireland","postcode":94103,"coordinates":{"latitude":"1.0","longitude":"1.0"},"timezone":{"offset":"+1:00","description":"Dublin"}}
        """#.utf8)
        
        let location = try JSONDecoder().decode(Location.self, from: json)
        
        #expect(location.postcode == "94103")
    }
    
    @Test func decodesPostcodeWhenProvidedAsString() throws {
        let json = Data(#"""
        {"street":{"number":1,"name":"Main St"},"city":"London","state":"London","country":"UK","postcode":"SW1A 1AA","coordinates":{"latitude":"1.0","longitude":"1.0"},"timezone":{"offset":"+0:00","description":"London"}}
        """#.utf8)
        
        let location = try JSONDecoder().decode(Location.self, from: json)
        
        #expect(location.postcode == "SW1A 1AA")
    }
    
    // MARK: - UserIdentification.value
    
    @Test func decodesNullIdentificationValueAsNil() throws {
        let json = Data(#"{"name":"BSN","value":null}"#.utf8)
        
        let identification = try JSONDecoder().decode(UserIdentification.self, from: json)
        
        #expect(identification.value == nil)
    }
}
