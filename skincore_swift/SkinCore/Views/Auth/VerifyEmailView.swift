import SwiftUI

struct VerifyEmailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var code = ""
    @FocusState private var isCodeFocused: Bool
    
    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer().frame(height: 40)
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "D4728C").opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "D4728C"))
                }
                
                // Title
                VStack(spacing: 8) {
                    Text("Verify Email")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    
                    Text("We sent a 6-digit code to\n\(authViewModel.pendingEmail)")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "6B7280"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Code Input
                TextField("", text: $code,
                         prompt: Text("000000").foregroundColor(Color(hex: "C4C4C4")))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "1A1A2E"))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($isCodeFocused)
                    .onChange(of: code) { newValue in
                        if newValue.count > 6 {
                            code = String(newValue.prefix(6))
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "D4728C").opacity(0.3), lineWidth: 2)
                    )
                    .padding(.horizontal, 48)
                
                // Error
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color(hex: "EF4444"))
                }
                
                // Verify Button
                Button {
                    Task { await authViewModel.verifyEmail(code: code) }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Verify")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(code.count == 6 ? Color(hex: "1A1A2E") : Color(hex: "C4C4C4"))
                    .foregroundColor(.white)
                    .cornerRadius(28)
                }
                .disabled(code.count != 6 || authViewModel.isLoading)
                .padding(.horizontal, 24)
                
                // Resend
                Button {
                    Task { await authViewModel.resendCode() }
                } label: {
                    Text("Resend code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "D4728C"))
                }
                
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
        .onAppear {
            isCodeFocused = true
        }
    }
}

#Preview {
    NavigationStack {
        VerifyEmailView()
            .environmentObject({
                let vm = AuthViewModel()
                vm.pendingEmail = "test@test.com"
                return vm
            }())
    }
}
