import SwiftUI

@Observable
final class AuthViewModel {
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil

    init() {
        isAuthenticated = SupabaseClient.shared.isAuthenticated
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await SupabaseClient.shared.signIn(email: email, password: password)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        SupabaseClient.shared.signOut()
        isAuthenticated = false
    }
}
