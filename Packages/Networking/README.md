# Networking

A minimal Swift Concurrency networking layer built on `URLSession`. It exposes a single `Sendable` client, `NetworkingClient`, that turns an `Endpoint` into a decoded, typed response.

## Contents

- `NetworkingClient` — performs the request, validates the HTTP status code, and decodes the response.
- `Endpoint` — describes a request (`path`, `HTTPMethod`).
- `HTTPMethod` — `GET`, `POST`, `PUT`, `PATCH`, `DELETE`.
- `NetworkError` — typed failure cases (`invalidURL`, `requestFailed`, `invalidResponse`, `unacceptableStatusCode`, `decodingFailed`).

## Installation

Add the package as a local Swift Package dependency (e.g. in the app's `Package.swift` or via Xcode's "Add Local Package..." pointing at `Packages/Networking`), then add `Networking` as a target dependency.

## Design: no direct dependency on this package from your view models

`NetworkingClient` deliberately does **not** define or conform to any protocol. To keep the app layer decoupled from this specific package (and free to swap in a different implementation later), the **consuming app** defines its own abstraction and adapts `NetworkingClient` to it. Since `NetworkingClient.request` already matches the shape below, this is a zero-logic conformance.

```swift
// App layer — e.g. Networking/APIClient.swift
protocol APIClient: Sendable {
    func request<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response
}
```

```swift
// App layer — adapter, the only file that imports the Networking package
import Networking

extension NetworkingClient: APIClient {}
```

View models depend only on `APIClient`, never on `Networking` or `NetworkingClient` directly:

```swift
final class UsersViewModel {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadUsers() async throws -> [User] {
        try await apiClient.request(Endpoint(path: "users"))
    }
}
```

Composition happens where the app wires up its dependencies:

```swift
import Networking

let apiClient: APIClient = NetworkingClient(baseURL: "https://api.example.com")
let viewModel = UsersViewModel(apiClient: apiClient)
```

This keeps `Networking` free of app-specific protocols and lets any other package be swapped in behind `APIClient` without touching a single view model.

## Usage

```swift
import Networking

let client = NetworkingClient(baseURL: "https://api.example.com")

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

let users: [User] = try await client.request(Endpoint(path: "users"))

let newUser: User = try await client.request(
    Endpoint(path: "users", method: .post)
)
```

### Error handling

```swift
do {
    let users: [User] = try await client.request(Endpoint(path: "users"))
} catch let error as NetworkError {
    switch error {
    case .invalidURL:
        // baseURL/path did not form a valid URL
    case .requestFailed(let urlError):
        // transport-level failure (e.g. no connectivity)
    case .invalidResponse:
        // response was not an HTTPURLResponse
    case .unacceptableStatusCode(let code):
        // status code outside 200..<300
    case .decodingFailed(let decodingError):
        // response body didn't match the requested Decodable type
    }
}
```

## Testing

For unit tests, inject a mock conforming to `APIClient` into your view models — no dependency on `Networking` or live networking is required.
