//
//  UsersResponseDecodingTests.swift
//  RandomUsersTests
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Testing
import Foundation
@testable import RandomUsers

struct UsersResponseDecodingTests {
    
    @Test func decodesFullUsersResponse() throws {
        let decoded = try JSONDecoder().decode(UsersResponse.self, from: Self.json)
        
        #expect(decoded == Self.expectedResponse)
    }
    
    @Test func exposesLoginUUIDAsUserID() throws {
        let decoded = try JSONDecoder().decode(UsersResponse.self, from: Self.json)
        
        #expect(decoded.results.map(\.id) == decoded.results.map(\.login.uuid))
    }
    
    private static func date(_ iso8601: String) -> Date {
        try! Date(iso8601, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
    
    private static let expectedResponse = UsersResponse(
        results: [
            UserModel(
                gender: .female,
                name: Name(title: "Miss", first: "Laura", last: "Woods"),
                location: Location(
                    street: Street(number: 2479, name: "Henry Street"),
                    city: "Blessington",
                    state: "Wexford",
                    country: "Ireland",
                    postcode: "78276",
                    coordinates: Coordinates(latitude: "2.0565", longitude: "95.2422"),
                    timezone: TimeZoneInfo(offset: "+1:00", description: "Brussels, Copenhagen, Madrid, Paris")
                ),
                email: "laura.woods@example.com",
                login: Login(
                    uuid: "9f07341f-c7e6-45b7-bab0-af6de5a4582d",
                    username: "angryostrich988",
                    password: "racers",
                    salt: "B5ywSDUM",
                    md5: "2eefb6307df2a5fb1f91c6b968dc905b",
                    sha1: "33cbf1e97a31e14c87fb18c481d1f6d958c76cbd",
                    sha256: "83e0c89668c8b6131df0c70fc4bb9abb8831e0ff97a0a29cdfa3949dd5afd491"
                ),
                dateOfBirth: DateInfo(date: date("1967-07-23T09:18:33.666Z"), age: 58),
                registered: DateInfo(date: date("2018-10-18T04:05:51.990Z"), age: 7),
                phone: "031-623-5189",
                cell: "081-807-8083",
                identification: UserIdentification(name: "PPS", value: "1101776T"),
                picture: Picture(
                    large: "https://randomuser.me/api/portraits/women/88.jpg",
                    medium: "https://randomuser.me/api/portraits/med/women/88.jpg",
                    thumbnail: "https://randomuser.me/api/portraits/thumb/women/88.jpg"
                ),
                nationality: "IE"
            ),
            UserModel(
                gender: .male,
                name: Name(title: "Mr", first: "Marten", last: "Faber"),
                location: Location(
                    street: Street(number: 6167, name: "Grüner Weg"),
                    city: "Falkenberg/Elster",
                    state: "Thüringen",
                    country: "Germany",
                    postcode: "99553",
                    coordinates: Coordinates(latitude: "89.4367", longitude: "135.6354"),
                    timezone: TimeZoneInfo(offset: "+5:45", description: "Kathmandu")
                ),
                email: "marten.faber@example.com",
                login: Login(
                    uuid: "1cd1e622-12bb-4b35-a2c9-63ff7bda6c73",
                    username: "yellowfish737",
                    password: "krusty",
                    salt: "CQZQxXDl",
                    md5: "c875e08220708016989470d12ba1175f",
                    sha1: "48f118f603294a09a5cd30b93bca9b08d5abcae5",
                    sha256: "2daf436e8b7cd276eaedfd06ced8a8e1938fae2015fb775ac20490d9a92ec3a1"
                ),
                dateOfBirth: DateInfo(date: date("1960-08-01T11:13:57.264Z"), age: 65),
                registered: DateInfo(date: date("2002-04-03T08:57:47.321Z"), age: 24),
                phone: "0100-8354415",
                cell: "0172-4195644",
                identification: UserIdentification(name: "SVNR", value: "18 010860 F 495"),
                picture: Picture(
                    large: "https://randomuser.me/api/portraits/men/1.jpg",
                    medium: "https://randomuser.me/api/portraits/med/men/1.jpg",
                    thumbnail: "https://randomuser.me/api/portraits/thumb/men/1.jpg"
                ),
                nationality: "DE"
            ),
            UserModel(
                gender: .female,
                name: Name(title: "Miss", first: "Christy", last: "Diaz"),
                location: Location(
                    street: Street(number: 5171, name: "Karen Dr"),
                    city: "Hobart",
                    state: "South Australia",
                    country: "Australia",
                    postcode: "2104",
                    coordinates: Coordinates(latitude: "3.9825", longitude: "176.6213"),
                    timezone: TimeZoneInfo(offset: "+6:00", description: "Almaty, Dhaka, Colombo")
                ),
                email: "christy.diaz@example.com",
                login: Login(
                    uuid: "4b400301-d696-4618-862e-8a673f80e334",
                    username: "happywolf771",
                    password: "softball",
                    salt: "npdL2iHP",
                    md5: "2d6ec889c9d7a59d6e5b3405a8b36be7",
                    sha1: "d526c003ba877f5b6489c032afb6864b72eb19a8",
                    sha256: "bd24acc8ac0eb918bc4b1cc006bf893b0c5eb28aec7a41982c439eb631010f5e"
                ),
                dateOfBirth: DateInfo(date: date("1982-11-05T12:29:00.723Z"), age: 43),
                registered: DateInfo(date: date("2021-11-29T02:24:48.253Z"), age: 4),
                phone: "07-8830-6561",
                cell: "0488-834-749",
                identification: UserIdentification(name: "TFN", value: "314751863"),
                picture: Picture(
                    large: "https://randomuser.me/api/portraits/women/53.jpg",
                    medium: "https://randomuser.me/api/portraits/med/women/53.jpg",
                    thumbnail: "https://randomuser.me/api/portraits/thumb/women/53.jpg"
                ),
                nationality: "AU"
            )
        ],
        info: ResponseInfo(seed: "abc", results: 3, page: 1, version: "1.4")
    )
    
    private static let json = Data(#"""
    {"results":[{"gender":"female","name":{"title":"Miss","first":"Laura","last":"Woods"},"location":{"street":{"number":2479,"name":"Henry Street"},"city":"Blessington","state":"Wexford","country":"Ireland","postcode":78276,"coordinates":{"latitude":"2.0565","longitude":"95.2422"},"timezone":{"offset":"+1:00","description":"Brussels, Copenhagen, Madrid, Paris"}},"email":"laura.woods@example.com","login":{"uuid":"9f07341f-c7e6-45b7-bab0-af6de5a4582d","username":"angryostrich988","password":"racers","salt":"B5ywSDUM","md5":"2eefb6307df2a5fb1f91c6b968dc905b","sha1":"33cbf1e97a31e14c87fb18c481d1f6d958c76cbd","sha256":"83e0c89668c8b6131df0c70fc4bb9abb8831e0ff97a0a29cdfa3949dd5afd491"},"dob":{"date":"1967-07-23T09:18:33.666Z","age":58},"registered":{"date":"2018-10-18T04:05:51.990Z","age":7},"phone":"031-623-5189","cell":"081-807-8083","id":{"name":"PPS","value":"1101776T"},"picture":{"large":"https://randomuser.me/api/portraits/women/88.jpg","medium":"https://randomuser.me/api/portraits/med/women/88.jpg","thumbnail":"https://randomuser.me/api/portraits/thumb/women/88.jpg"},"nat":"IE"},{"gender":"male","name":{"title":"Mr","first":"Marten","last":"Faber"},"location":{"street":{"number":6167,"name":"Grüner Weg"},"city":"Falkenberg/Elster","state":"Thüringen","country":"Germany","postcode":99553,"coordinates":{"latitude":"89.4367","longitude":"135.6354"},"timezone":{"offset":"+5:45","description":"Kathmandu"}},"email":"marten.faber@example.com","login":{"uuid":"1cd1e622-12bb-4b35-a2c9-63ff7bda6c73","username":"yellowfish737","password":"krusty","salt":"CQZQxXDl","md5":"c875e08220708016989470d12ba1175f","sha1":"48f118f603294a09a5cd30b93bca9b08d5abcae5","sha256":"2daf436e8b7cd276eaedfd06ced8a8e1938fae2015fb775ac20490d9a92ec3a1"},"dob":{"date":"1960-08-01T11:13:57.264Z","age":65},"registered":{"date":"2002-04-03T08:57:47.321Z","age":24},"phone":"0100-8354415","cell":"0172-4195644","id":{"name":"SVNR","value":"18 010860 F 495"},"picture":{"large":"https://randomuser.me/api/portraits/men/1.jpg","medium":"https://randomuser.me/api/portraits/med/men/1.jpg","thumbnail":"https://randomuser.me/api/portraits/thumb/men/1.jpg"},"nat":"DE"},{"gender":"female","name":{"title":"Miss","first":"Christy","last":"Diaz"},"location":{"street":{"number":5171,"name":"Karen Dr"},"city":"Hobart","state":"South Australia","country":"Australia","postcode":2104,"coordinates":{"latitude":"3.9825","longitude":"176.6213"},"timezone":{"offset":"+6:00","description":"Almaty, Dhaka, Colombo"}},"email":"christy.diaz@example.com","login":{"uuid":"4b400301-d696-4618-862e-8a673f80e334","username":"happywolf771","password":"softball","salt":"npdL2iHP","md5":"2d6ec889c9d7a59d6e5b3405a8b36be7","sha1":"d526c003ba877f5b6489c032afb6864b72eb19a8","sha256":"bd24acc8ac0eb918bc4b1cc006bf893b0c5eb28aec7a41982c439eb631010f5e"},"dob":{"date":"1982-11-05T12:29:00.723Z","age":43},"registered":{"date":"2021-11-29T02:24:48.253Z","age":4},"phone":"07-8830-6561","cell":"0488-834-749","id":{"name":"TFN","value":"314751863"},"picture":{"large":"https://randomuser.me/api/portraits/women/53.jpg","medium":"https://randomuser.me/api/portraits/med/women/53.jpg","thumbnail":"https://randomuser.me/api/portraits/thumb/women/53.jpg"},"nat":"AU"}],"info":{"seed":"abc","results":3,"page":1,"version":"1.4"}}
    """#.utf8)
}
