import Foundation
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: UserResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Navigation state
    @Published var showVerifyEmail = false
    @Published var pendingEmail = ""
    
    init() {
        // Check if user is already logged in
        if KeychainService.shared.getAccessToken() != nil {
            Task { await checkAuth() }
        }
    }
    
    // MARK: - Register
    
    func register(email: String, password: String, fullName: String?) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIClient.shared.register(
                email: email, password: password, fullName: fullName
            )
            pendingEmail = email
            showVerifyEmail = true
            print("✅ \(response.message)")
        } catch let error as APIClientError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Verify Email
    
    func verifyEmail(code: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIClient.shared.verifyEmail(
                email: pendingEmail, code: code
            )
            KeychainService.shared.saveTokens(from: response)
            currentUser = response.user
            isAuthenticated = true
            showVerifyEmail = false
        } catch let error as APIClientError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Login
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIClient.shared.login(
                email: email, password: password
            )
            KeychainService.shared.saveTokens(from: response)
            currentUser = response.user
            isAuthenticated = true
        } catch let error as APIClientError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Apple Sign In
    
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "Apple kimlik bilgileri alınamadı."
                isLoading = false
                return
            }
            
            // Get full name (only available on first sign in)
            var fullName: String?
            if let nameComponents = appleIDCredential.fullName {
                let parts = [nameComponents.givenName, nameComponents.familyName]
                    .compactMap { $0 }
                if !parts.isEmpty {
                    fullName = parts.joined(separator: " ")
                }
            }
            
            let email = appleIDCredential.email
            
            do {
                let response = try await APIClient.shared.appleSignIn(
                    identityToken: identityToken,
                    fullName: fullName,
                    email: email
                )
                KeychainService.shared.saveTokens(from: response)
                currentUser = response.user
                isAuthenticated = true
            } catch let error as APIClientError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Apple girişi başarısız: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Resend Code
    
    func resendCode() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIClient.shared.resendCode(email: pendingEmail)
            print("✅ \(response.message)")
        } catch let error as APIClientError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Check Auth
    
    func checkAuth() async {
        do {
            let user = try await APIClient.shared.getMe()
            currentUser = user
            isAuthenticated = true
        } catch {
            // Token expired, try refresh
            do {
                let response = try await APIClient.shared.refreshToken()
                KeychainService.shared.saveTokens(from: response)
                currentUser = response.user
                isAuthenticated = true
            } catch {
                logout()
            }
        }
    }
    
    // MARK: - Logout
    
    func logout() {
        KeychainService.shared.clearAll()
        currentUser = nil
        isAuthenticated = false
    }
}
