import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 40)
                        
                        // Logo & Title
                        VStack(spacing: 12) {
                            Image(systemName: "leaf.circle.fill")
                                .font(.system(size: 72))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "6366f1"), Color(hex: "8b5cf6")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("SkinCore")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Cilt bakım asistanın")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        // Login Form
                        VStack(spacing: 16) {
                            // Email
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 24)
                                TextField("", text: $email,
                                         prompt: Text("E-posta").foregroundColor(.white.opacity(0.4)))
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            
                            // Password
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 24)
                                SecureField("", text: $password,
                                           prompt: Text("Şifre").foregroundColor(.white.opacity(0.4)))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        
                        // Error Message
                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Color(hex: "ef4444"))
                                .padding(.horizontal)
                        }
                        
                        // Login Button
                        Button {
                            Task { await authViewModel.login(email: email, password: password) }
                        } label: {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Giriş Yap")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "6366f1"), Color(hex: "8b5cf6")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                        .padding(.horizontal)
                        
                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                            Text("veya").foregroundColor(.white.opacity(0.4)).font(.caption)
                            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                        }
                        .padding(.horizontal, 32)
                        
                        // Apple Sign In
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                Task { await authViewModel.handleAppleSignIn(result: result) }
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .cornerRadius(14)
                        .padding(.horizontal)
                        
                        // Register Link
                        Button {
                            showRegister = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Hesabın yok mu?")
                                    .foregroundColor(.white.opacity(0.5))
                                Text("Kayıt Ol")
                                    .foregroundColor(Color(hex: "8b5cf6"))
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
            .navigationDestination(isPresented: $authViewModel.showVerifyEmail) {
                VerifyEmailView()
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
