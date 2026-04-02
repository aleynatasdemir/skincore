import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
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
                    Text(lang.s(.appBrand))
                        .font(.system(size: 48, weight: .light, design: .serif))
                        .foregroundColor(Color(hex: "D4728C"))
                        .padding(.bottom, 32)
                    
                    // Title
                    Text(lang.s(.loginWelcome))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                        .padding(.bottom, 12)

                    // Subtitle
                    Text(lang.s(.loginSubtitle))
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
                                Text(lang.s(.loginContinueEmail))
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
                                Text(lang.s(.alreadyHaveAccount))
                                    .foregroundColor(Color(hex: "6B7280"))
                                Text(lang.s(.loginButton))
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
                                Text(lang.s(.newToSkincore))
                                    .foregroundColor(Color(hex: "6B7280"))
                                Text(lang.s(.signUp))
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
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: "EF4444"))
                                .frame(width: 24, alignment: .center)
                            
                            Text(error)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "DC2626"))
                                .lineLimit(nil)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(hex: "FEE2E2"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: "FECACA"), lineWidth: 1)
                        )
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    
                    // Terms
                    VStack(spacing: 2) {
                        Text(lang.s(.termsPrefix)) +
                        Text(lang.s(.termsOf)).underline() +
                        Text("\n") +
                        Text(lang.s(.termService)).underline() +
                        Text(lang.s(.termsAnd)) +
                        Text(lang.s(.termsPrivacy)).underline()
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
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var showForgotPassword = false
    
    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                
                // Header
                Text(lang.s(.appBrand))
                    .font(.system(size: 36, weight: .light, design: .serif))
                    .foregroundColor(Color(hex: "D4728C"))
                
                Text(lang.s(.loginButton))
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
                                 prompt: Text(lang.s(.email)).foregroundColor(Color(hex: "6B7280")))
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
                                   prompt: Text(lang.s(.password)).foregroundColor(Color(hex: "6B7280")))
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
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "EF4444"))
                            .frame(width: 24, alignment: .center)
                        
                        Text(error)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "DC2626"))
                            .lineLimit(nil)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(hex: "FEE2E2"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "FECACA"), lineWidth: 1)
                    )
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, -4)
                }
                
                // Forgot Password
                HStack {
                    Spacer()
                    Button {
                        showForgotPassword = true
                    } label: {
                        Text(lang.s(.forgotPassword) + "?")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, -8)

                // Login Button
                Button {
                    Task { await authViewModel.login(email: email, password: password) }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(lang.s(.loginButton))
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
        .navigationDestination(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .onChange(of: authViewModel.resetPasswordCompleted) { _, completed in
            if completed { showForgotPassword = false }
        }
        .task {
            authViewModel.clearError()
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
        .environmentObject(LanguageManager.shared)
}
