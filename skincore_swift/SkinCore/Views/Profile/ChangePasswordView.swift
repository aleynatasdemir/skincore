import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isLoading = false
    
    @State private var showCurrentPassword = false
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(hex: "FFF0F0").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        // Current Password
                        HStack {
                            if showCurrentPassword {
                                TextField(lang.s(.changePasswordCurrent), text: $currentPassword)
                            } else {
                                SecureField(lang.s(.changePasswordCurrent), text: $currentPassword)
                            }
                            
                            Button(action: { showCurrentPassword.toggle() }) {
                                Image(systemName: showCurrentPassword ? "eye.fill" : "eye.slash.fill")
                                    .foregroundColor(Color(hex: "7B5455"))
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)

                        // New Password
                        HStack {
                            if showNewPassword {
                                TextField(lang.s(.changePasswordNew), text: $newPassword)
                            } else {
                                SecureField(lang.s(.changePasswordNew), text: $newPassword)
                            }
                            
                            Button(action: { showNewPassword.toggle() }) {
                                Image(systemName: showNewPassword ? "eye.fill" : "eye.slash.fill")
                                    .foregroundColor(Color(hex: "7B5455"))
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)

                        // Confirm New Password
                        HStack {
                            if showConfirmPassword {
                                TextField(lang.s(.changePasswordConfirm), text: $confirmNewPassword)
                            } else {
                                SecureField(lang.s(.changePasswordConfirm), text: $confirmNewPassword)
                            }
                            
                            Button(action: { showConfirmPassword.toggle() }) {
                                Image(systemName: showConfirmPassword ? "eye.fill" : "eye.slash.fill")
                                    .foregroundColor(Color(hex: "7B5455"))
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if !successMessage.isEmpty {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        Task {
                            await tryChangePassword()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "D4728C"))
                                .cornerRadius(12)
                        } else {
                            Text(lang.s(.changePasswordSubmit))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "D4728C"))
                                .cornerRadius(12)
                        }
                    }
                    .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty || confirmNewPassword.isEmpty)
                    .opacity((isLoading || currentPassword.isEmpty || newPassword.isEmpty || confirmNewPassword.isEmpty) ? 0.6 : 1.0)
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle(lang.s(.changePasswordTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(hex: "7B5455"))
                    }
                }
            }
        }
    }

    private func tryChangePassword() async {
        guard newPassword == confirmNewPassword else {
            errorMessage = lang.s(.passwordsNoMatch)
            return
        }
        
        guard newPassword.count >= 8 else {
            errorMessage = lang.s(.passwordMinChars)
            return
        }
        
        errorMessage = ""
        successMessage = ""
        isLoading = true
        
        do {
            _ = try await APIClient.shared.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            successMessage = lang.s(.changePasswordSuccess)
            
            // Optional: Dismiss smoothly after success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch let err as APIClientError {
            switch err {
            case .serverError(let msg):
                errorMessage = msg
            default:
                errorMessage = lang.s(.error)
            }
        } catch {
            errorMessage = lang.s(.error)
        }
        
        isLoading = false
    }
}
