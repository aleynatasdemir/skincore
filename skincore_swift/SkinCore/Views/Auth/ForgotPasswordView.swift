import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var showResetPassword = false

    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                Text(lang.s(.appBrand))
                    .font(.system(size: 36, weight: .light, design: .serif))
                    .foregroundColor(Color(hex: "D4728C"))

                Text(lang.s(.forgotPassword))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))

                Text(lang.s(.forgotPasswordSubtitle))
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "6B7280"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)

                // Email field
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
                }

                // Send Code Button
                Button {
                    Task {
                        await authViewModel.forgotPassword(email: email)
                        if authViewModel.errorMessage == nil {
                            showResetPassword = true
                        }
                    }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(lang.s(.sendResetCode))
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "1A1A2E"))
                    .foregroundColor(.white)
                    .cornerRadius(28)
                }
                .disabled(email.isEmpty || authViewModel.isLoading)
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
        .navigationDestination(isPresented: $showResetPassword) {
            ResetPasswordView()
        }
        .task {
            authViewModel.clearError()
        }
    }
}
