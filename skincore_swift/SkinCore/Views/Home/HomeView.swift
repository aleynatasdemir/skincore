import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0f0f1a").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Merhaba,")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                            Text(authViewModel.currentUser?.fullName ?? "Kullanıcı")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Profile / Logout
                        Menu {
                            Button(role: .destructive) {
                                authViewModel.logout()
                            } label: {
                                Label("Çıkış Yap", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Color(hex: "8b5cf6"))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Welcome Card
                    VStack(spacing: 16) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "6366f1"), Color(hex: "8b5cf6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("SkinCore'a Hoş Geldin!")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Ürün tarama, içerik analizi ve daha fazlası için hazır.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    
                    // User Info Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text(authViewModel.currentUser?.email ?? "")
                                .foregroundColor(.white.opacity(0.8))
                        } icon: {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(Color(hex: "8b5cf6"))
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        Label {
                            Text(authViewModel.currentUser?.authProvider == "apple" ? "Apple ile giriş" : "E-posta ile giriş")
                                .foregroundColor(.white.opacity(0.8))
                        } icon: {
                            Image(systemName: authViewModel.currentUser?.authProvider == "apple" ? "apple.logo" : "key.fill")
                                .foregroundColor(Color(hex: "8b5cf6"))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject({
            let vm = AuthViewModel()
            vm.currentUser = UserResponse(
                id: "1", email: "test@test.com",
                fullName: "Test User", authProvider: "email",
                isEmailVerified: true, createdAt: "2026-01-01"
            )
            vm.isAuthenticated = true
            return vm
        }())
}
