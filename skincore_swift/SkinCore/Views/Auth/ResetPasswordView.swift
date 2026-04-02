import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
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

                Text(lang.s(.appBrand))
                    .font(.system(size: 36, weight: .light, design: .serif))
                    .foregroundColor(Color(hex: "D4728C"))

                Text(lang.s(.resetPassword))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))

                Text("\(lang.s(.resetCodeSentPrefix))\n\(authViewModel.pendingEmail)")
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
                                 prompt: Text(lang.s(.resetCode)).foregroundColor(Color(hex: "6B7280")))
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
                                   prompt: Text(lang.s(.newPassword)).foregroundColor(Color(hex: "6B7280")))
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
                                   prompt: Text(lang.s(.confirmPassword)).foregroundColor(Color(hex: "6B7280")))
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
                if !passwordsMatch || authViewModel.errorMessage != nil {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "EF4444"))
                            .frame(width: 24, alignment: .center)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if !passwordsMatch {
                                Text(lang.s(.passwordsNoMatch))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "DC2626"))
                            }
                            if let error = authViewModel.errorMessage {
                                Text(error)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "DC2626"))
                            }
                        }
                        
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
                }

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
                            Text(lang.s(.resetPasswordButton))
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
        .alert(lang.s(.passwordResetAlertTitle), isPresented: $showSuccessAlert) {
            Button(lang.s(.loginButton)) {
                authViewModel.resetPasswordCompleted = true
            }
        } message: {
            Text("\(lang.s(.passwordResetSuccess)) \(lang.s(.loginAgain))")
        }
        .task {
            authViewModel.clearError()
        }
    }
}
import SwiftUI

struct UsernameSetupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var lang: LanguageManager

    @State private var username = ""
    @State private var isAvailable: Bool? = nil
    @State private var isChecking = false
    @State private var checkTask: Task<Void, Never>?

    private var isValid: Bool {
        username.count >= 3 && isAvailable == true
    }

    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "FED9E2"))
                            .frame(width: 80, height: 80)
                        Image(systemName: "at")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(hex: "D4728C"))
                    }

                    Text(lang.s(.usernameTitle))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))

                    Text(lang.s(.usernameSubtitle))
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer().frame(height: 40)

                // Input
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text("@")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "D4728C"))

                        TextField(lang.s(.usernamePlaceholder), text: $username)
                            .font(.system(size: 17))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .onChange(of: username) { _, newVal in
                                let cleaned = newVal
                                    .lowercased()
                                    .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                if cleaned != newVal {
                                    username = cleaned
                                }
                                scheduleCheck(cleaned)
                            }

                        if isChecking {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(Color(hex: "D4728C"))
                        } else if username.count >= 3, let available = isAvailable {
                            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(available ? Color(hex: "22C55E") : Color(hex: "EF4444"))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(borderColor, lineWidth: 1.5)
                    )
                    .padding(.horizontal, 24)

                    // Status text
                    Group {
                        if username.count > 0 && username.count < 3 {
                            Text(lang.s(.usernameMinChars))
                                .foregroundColor(Color(hex: "9CA3AF"))
                        } else if username.count >= 3, let available = isAvailable, !isChecking {
                            Text(available ? "@\(username)\(lang.s(.usernameAvailable))" : lang.s(.usernameTaken))
                                .foregroundColor(available ? Color(hex: "22C55E") : Color(hex: "EF4444"))
                        }
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 28)
                    .frame(height: 18)
                }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "EF4444"))
                        .padding(.horizontal, 28)
                        .padding(.top, 8)
                }

                Spacer().frame(height: 32)

                // Button
                Button {
                    Task { await authViewModel.setupUsername(username) }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isValid ? Color(hex: "D4728C") : Color(hex: "F3D5DC"))
                            .frame(height: 52)

                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(lang.s(.continueButton))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(isValid ? .white : Color(hex: "D4728C").opacity(0.5))
                        }
                    }
                }
                .disabled(!isValid || authViewModel.isLoading)
                .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                Button {
                    authViewModel.logout()
                } label: {
                    Text(lang.s(.switchAccount))
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }

                Spacer()
            }
        }
    }

    private var borderColor: Color {
        if username.count >= 3, let available = isAvailable, !isChecking {
            return available ? Color(hex: "22C55E") : Color(hex: "EF4444")
        }
        return Color(hex: "F3D5DC")
    }

    private func scheduleCheck(_ value: String) {
        isAvailable = nil
        checkTask?.cancel()
        guard value.count >= 3 else {
            isChecking = false
            return
        }
        isChecking = true
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            let result = try? await APIClient.shared.checkUsernameAvailable(value)
            guard !Task.isCancelled else { return }
            isAvailable = result
            isChecking = false
        }
    }
}
