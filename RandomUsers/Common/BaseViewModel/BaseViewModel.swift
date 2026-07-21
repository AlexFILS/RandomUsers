//
//  BaseViewModel.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Observation

@MainActor
@Observable
class BaseViewModel {
    private(set) var isLoading: Bool = false
    private(set) var hasError = false
    @ObservationIgnored private(set) var error: DescribableErrorProtocol? = nil
    
    var errorDescription: String {
        error?.description ?? Constants.ErrorDescription.defaultError.rawValue
    }
    
    func clearErrors() {
        hasError = false
        error = nil
    }
    
    func perform(_ operation: () async throws -> Void) async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
        }
        do {
            try await operation()
        } catch {
            if error is CancellationError {
                print("BaseViewModel perform() cancelled.")
            }
            if let describableError = error as? DescribableErrorProtocol {
                self.error = describableError
            }
            hasError = true
        }
    }
}
