import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogin = false
    @State private var showRegister = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Light pink background
                Color(hex: "FFF0F0")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Logo
                    Text("skincore.")
                        .font(.system(size: 48, weight: .light, design: .serif))
                        .foregroundColor(Color(hex: "D4728C"))
                        .padding(.bottom, 32)
                    
                    // Title
                    Text("Welcome to Skincore")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                        .padding(.bottom, 12)
                    
                    // Subtitle
                    Text("Science-backed skincare starts here.\nAnalyze ingredients for your best skin ever.")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "6B7280"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Buttons
                    VStack(spacing: 14) {
                        // Continue with Apple
                        SignInWithAppleButton(
                            .continue,
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                Task { await authViewModel.handleAppleSignIn(result: result) }
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 56)
                        .cornerRadius(28)
                        
                        // Continue with Email
                        Button {
                            showRegister = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16))
                                Text("Continue with Email")
                                    .font(.system(size: 17, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .background(Color.white)
                            .cornerRadius(28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1.5)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Links
                    VStack(spacing: 10) {
                        // Already have an account? Log In
                        Button {
                            showLogin = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("Already have an account?")
                                    .foregroundColor(Color(hex: "6B7280"))
                                Text("Log In")
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(hex: "1A1A2E"))
                            }
                            .font(.system(size: 14))
                        }
                        
                        // New to Skincore? Sign Up
                        Button {
                            showRegister = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("New to Skincore?")
                                    .foregroundColor(Color(hex: "6B7280"))
                                Text("Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(hex: "1A1A2E"))
                            }
                            .font(.system(size: 14))
                        }
                    }
                    .padding(.top, 24)
                    
                    Spacer().frame(height: 40)
                    
                    // Error Message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color(hex: "EF4444"))
                            .padding(.bottom, 8)
                    }
                    
                    // Terms
                    VStack(spacing: 2) {
                        Text("By continuing, you agree to Skincore's ") +
                        Text("Terms of").underline() +
                        Text("\n") +
                        Text("Service").underline() +
                        Text(" and ") +
                        Text("Privacy Policy").underline()
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "9CA3AF"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)
                }
            }
            .navigationDestination(isPresented: $showLogin) {
                EmailLoginView()
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

// MARK: - Email Login View (separate from welcome)

struct EmailLoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                
                // Header
                Text("skincore.")
                    .font(.system(size: 36, weight: .light, design: .serif))
                    .foregroundColor(Color(hex: "D4728C"))
                
                Text("Log In")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                    .padding(.bottom, 8)
                
                // Form
                VStack(spacing: 14) {
                    // Email
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(Color(hex: "9CA3AF"))
                            .frame(width: 24)
                        TextField("", text: $email,
                                 prompt: Text("Email").foregroundColor(Color(hex: "6B7280")))
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .accentColor(Color(hex: "1A1A2E"))
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                    )
                    
                    // Password
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color(hex: "9CA3AF"))
                            .frame(width: 24)
                        SecureField("", text: $password,
                                   prompt: Text("Password").foregroundColor(Color(hex: "6B7280")))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .accentColor(Color(hex: "1A1A2E"))
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                
                // Error
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color(hex: "EF4444"))
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
                            Text("Log In")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "1A1A2E"))
                    .foregroundColor(.white)
                    .cornerRadius(28)
                }
                .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
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
