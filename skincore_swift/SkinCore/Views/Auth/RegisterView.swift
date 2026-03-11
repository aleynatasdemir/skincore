import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
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
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)
                    
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "8b5cf6"))
                        
                        Text("Hesap Oluştur")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Cilt bakım yolculuğuna başla")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Form
                    VStack(spacing: 14) {
                        // Full Name
                        AuthTextField(icon: "person.fill", placeholder: "Ad Soyad", text: $fullName)
                        
                        // Email
                        AuthTextField(icon: "envelope.fill", placeholder: "E-posta", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        // Password
                        AuthSecureField(icon: "lock.fill", placeholder: "Şifre (min 8 karakter)", text: $password)
                        
                        // Confirm Password
                        AuthSecureField(icon: "lock.rotation", placeholder: "Şifre Tekrar", text: $confirmPassword)
                        
                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Şifreler eşleşmiyor")
                                .font(.caption)
                                .foregroundColor(Color(hex: "ef4444"))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color(hex: "ef4444"))
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
                                Text("Kayıt Ol")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: isFormValid
                                    ? [Color(hex: "6366f1"), Color(hex: "8b5cf6")]
                                    : [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(!isFormValid || authViewModel.isLoading)
                    .padding(.horizontal)
                    
                    // Back to Login
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Zaten hesabın var mı?")
                                .foregroundColor(.white.opacity(0.5))
                            Text("Giriş Yap")
                                .foregroundColor(Color(hex: "8b5cf6"))
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
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
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Reusable Components

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)
            TextField("", text: $text,
                     prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
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
}

struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)
            SecureField("", text: $text,
                       prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
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
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}
