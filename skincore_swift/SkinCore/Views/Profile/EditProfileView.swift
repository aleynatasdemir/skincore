import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    
    let initialProfile: UserProfileResponse?
    var onSaveComplete: () -> Void
    
    @State private var fullName = ""
    @State private var username = ""
    @State private var bio = ""
    
    // Username checking state
    @State private var isUsernameAvailable: Bool? = nil
    @State private var isCheckingUsername = false
    @State private var checkTask: Task<Void, Never>?
    
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    
    // If username hasn't changed from original, it's valid.
    // If it changed, it must be >= 3 chars and available.
    private var isUsernameValid: Bool {
        if username == initialProfile?.username { return true }
        return username.count >= 3 && isUsernameAvailable == true
    }
    
    private var canSave: Bool {
        !isSaving && isUsernameValid
    }
    
    init(profile: UserProfileResponse?, onSaveComplete: @escaping () -> Void) {
        self.initialProfile = profile
        self.onSaveComplete = onSaveComplete
        _fullName = State(initialValue: profile?.fullName ?? "")
        _username = State(initialValue: profile?.username ?? "")
        _bio = State(initialValue: profile?.bio ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Error Alert
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "EF4444"))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: "FEE2E2"))
                                .cornerRadius(8)
                        }
                        
                        // Full Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.s(.fullNameLabel))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "7B5455"))
                            
                            TextField("", text: $fullName)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .foregroundColor(Color(hex: "1A1A2E"))
                        }
                        
                        // Username
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.s(.usernameTitle))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "7B5455"))
                            
                            HStack(spacing: 12) {
                                Text("@")
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "D4728C"))
                                
                                TextField("", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                    .onChange(of: username) { _, newVal in
                                        let cleaned = newVal.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                        if cleaned != newVal {
                                            username = cleaned
                                        }
                                        if cleaned == initialProfile?.username {
                                            isUsernameAvailable = true
                                            isCheckingUsername = false
                                        } else {
                                            scheduleCheck(cleaned)
                                        }
                                    }
                                
                                if isCheckingUsername {
                                    ProgressView().scaleEffect(0.8).tint(Color(hex: "D4728C"))
                                } else if username != initialProfile?.username && username.count >= 3 {
                                    if let available = isUsernameAvailable {
                                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(available ? .green : .red)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(usernameBorderColor, lineWidth: 1)
                            )
                        }
                        
                        // Bio
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.s(.bioLabel))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "7B5455"))
                            
                            TextEditor(text: $bio)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(12)
                                .foregroundColor(Color(hex: "1A1A2E"))
                                // Overlay equivalent to TextEditor placeholder is tricky, leaving it empty or just relying on label.
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(24)
                }
            }
            .navigationTitle(lang.s(.editProfileTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text(lang.s(.editProfileCancel))
                            .foregroundColor(Color(hex: "7B5455"))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await saveProfile() }
                    }) {
                        if isSaving {
                            ProgressView().tint(Color(hex: "1A1A2E"))
                        } else {
                            Text(lang.s(.editProfileSave))
                                .fontWeight(.bold)
                                .foregroundColor(canSave ? Color(hex: "1A1A2E") : Color.gray)
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private var usernameBorderColor: Color {
        if username == initialProfile?.username { return Color.clear }
        if username.count >= 3, let available = isUsernameAvailable, !isCheckingUsername {
            return available ? .green : .red
        }
        return Color.clear
    }
    
    private func scheduleCheck(_ value: String) {
        isUsernameAvailable = nil
        checkTask?.cancel()
        guard value.count >= 3 else {
            isCheckingUsername = false
            return
        }
        isCheckingUsername = true
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            let result = try? await APIClient.shared.checkUsernameAvailable(value)
            guard !Task.isCancelled else { return }
            isUsernameAvailable = result
            isCheckingUsername = false
        }
    }
    
    private func saveProfile() async {
        isSaving = true
        errorMessage = nil
        
        do {
            _ = try await APIClient.shared.updateProfile(
                displayName: fullName,
                skinType: initialProfile?.skinType,
                username: username,
                bio: bio
            )
            onSaveComplete()
            dismiss()
        } catch let error as APIClientError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Profil güncellenemedi."
        }
        
        isSaving = false
    }
}
