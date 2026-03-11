import SwiftUI

@main
struct SkinCoreApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    HomeView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authViewModel)
        }
    }
}
