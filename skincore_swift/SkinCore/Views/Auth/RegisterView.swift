import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 8 && passwordsMatch
    }
    
    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)
                    
                    // Header
                    Text(lang.s(.appBrand))
                        .font(.system(size: 36, weight: .light, design: .serif))
                        .foregroundColor(Color(hex: "D4728C"))
                    
                    Text(lang.s(.createAccount))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))

                    Text(lang.s(.startJourney))
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "6B7280"))

                    // Form
                    VStack(spacing: 14) {
                        AuthInputField(icon: "person.fill", placeholder: lang.s(.fullName), text: $fullName)

                        AuthInputField(icon: "envelope.fill", placeholder: lang.s(.email), text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        AuthSecureInputField(icon: "lock.fill", placeholder: lang.s(.passwordMinChars), text: $password)

                        AuthSecureInputField(icon: "lock.rotation", placeholder: lang.s(.confirmPassword), text: $confirmPassword)

                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text(lang.s(.passwordsNoMatch))
                                .font(.caption)
                                .foregroundColor(Color(hex: "EF4444"))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Error
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color(hex: "EF4444"))
                            .padding(.horizontal)
                    }
                    
                    // Register Button
                    Button {
                        Task {
                            await authViewModel.register(
                                email: email,
                                password: password,
                                fullName: fullName.isEmpty ? nil : fullName
                            )
                        }
                    } label: {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(lang.s(.signUp))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isFormValid ? Color(hex: "1A1A2E") : Color(hex: "C4C4C4"))
                        .foregroundColor(.white)
                        .cornerRadius(28)
                    }
                    .disabled(!isFormValid || authViewModel.isLoading)
                    .padding(.horizontal, 24)
                    
                    // Back to Login
                    Button {
                        dismiss()
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
                    
                    Spacer()
                }
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

// MARK: - Reusable Components

struct AuthInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "6B7280"))
                .frame(width: 24)
            TextField("", text: $text,
                     prompt: Text(placeholder).foregroundColor(Color(hex: "6B7280")))
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
}

struct AuthSecureInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "6B7280"))
                .frame(width: 24)
            SecureField("", text: $text,
                       prompt: Text(placeholder).foregroundColor(Color(hex: "6B7280")))
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
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel())
            .environmentObject(LanguageManager.shared)
    }
}
