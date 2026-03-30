import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordsMatch = true
    @State private var showSuccessAlert = false

    private var canSubmit: Bool {
        code.count == 6 && !newPassword.isEmpty && !confirmPassword.isEmpty && !authViewModel.isLoading
    }

    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                Text("skincore.")
                    .font(.system(size: 36, weight: .light, design: .serif))
                    .foregroundColor(Color(hex: "D4728C"))

                Text("Reset Password")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))

                Text("Enter the 6-digit code sent to\n\(authViewModel.pendingEmail)")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "6B7280"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)

                VStack(spacing: 14) {
                    // Code field
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(Color(hex: "9CA3AF"))
                            .frame(width: 24)
                        TextField("", text: $code,
                                 prompt: Text("Reset Code").foregroundColor(Color(hex: "6B7280")))
                            .keyboardType(.numberPad)
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .accentColor(Color(hex: "1A1A2E"))
                            .onChange(of: code) { _, newValue in
                                if newValue.count > 6 { code = String(newValue.prefix(6)) }
                            }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                    )

                    // New password
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color(hex: "9CA3AF"))
                            .frame(width: 24)
                        SecureField("", text: $newPassword,
                                   prompt: Text("New Password").foregroundColor(Color(hex: "6B7280")))
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

                    // Confirm password
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color(hex: "9CA3AF"))
                            .frame(width: 24)
                        SecureField("", text: $confirmPassword,
                                   prompt: Text("Confirm Password").foregroundColor(Color(hex: "6B7280")))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .accentColor(Color(hex: "1A1A2E"))
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                passwordsMatch ? Color(hex: "E5E7EB") : Color(hex: "EF4444"),
                                lineWidth: 1
                            )
                    )
                }
                .padding(.horizontal, 24)

                // Validation errors
                VStack(spacing: 4) {
                    if !passwordsMatch {
                        Text("Passwords do not match.")
                            .font(.caption)
                            .foregroundColor(Color(hex: "EF4444"))
                    }
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color(hex: "EF4444"))
                    }
                }
                .padding(.horizontal)

                // Reset Button
                Button {
                    guard newPassword == confirmPassword else {
                        passwordsMatch = false
                        return
                    }
                    passwordsMatch = true
                    Task {
                        await authViewModel.resetPassword(code: code, newPassword: newPassword)
                        if authViewModel.errorMessage == nil {
                            showSuccessAlert = true
                        }
                    }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Reset Password")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "1A1A2E"))
                    .foregroundColor(.white)
                    .cornerRadius(28)
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
            }
        }
        .alert("Password Reset Successful", isPresented: $showSuccessAlert) {
            Button("Log In") {
                // resetPasswordCompleted = true triggers EmailLoginView to pop the stack
                authViewModel.resetPasswordCompleted = true
            }
        } message: {
            Text("Your password has been reset. Please log in with your new password.")
        }
    }
}
