import SwiftUI

struct VerifyEmailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var code = ""
    @FocusState private var isCodeFocused: Bool
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer().frame(height: 40)
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "6366f1").opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "8b5cf6"))
                }
                
                // Title
                VStack(spacing: 8) {
                    Text("E-posta Doğrulama")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(authViewModel.pendingEmail) adresine\n6 haneli doğrulama kodu gönderildi")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Code Input
                TextField("", text: $code,
                         prompt: Text("000000").foregroundColor(.white.opacity(0.2)))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($isCodeFocused)
                    .onChange(of: code) { newValue in
                        // Limit to 6 digits
                        if newValue.count > 6 {
                            code = String(newValue.prefix(6))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "6366f1").opacity(0.3), lineWidth: 2)
                    )
                    .padding(.horizontal, 48)
                
                // Error
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color(hex: "ef4444"))
                }
                
                // Verify Button
                Button {
                    Task { await authViewModel.verifyEmail(code: code) }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Doğrula")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: code.count == 6
                                ? [Color(hex: "6366f1"), Color(hex: "8b5cf6")]
                                : [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(code.count != 6 || authViewModel.isLoading)
                .padding(.horizontal)
                
                // Resend
                Button {
                    Task { await authViewModel.resendCode() }
                } label: {
                    Text("Kodu tekrar gönder")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "8b5cf6"))
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
                        .foregroundColor(.white)
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
