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
    @State private var skinType: String? = nil
    @State private var showQuiz = false

    private let skinTypes = ["Normal", "Kuru", "Yağlı", "Karma", "Hassas", "Akneye Meyilli", "Olgun"]

    @State private var isUsernameAvailable: Bool? = nil
    @State private var isCheckingUsername = false
    @State private var checkTask: Task<Void, Never>?

    @State private var isSaving = false
    @State private var errorMessage: String? = nil

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
        _skinType = State(initialValue: profile?.skinType)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        errorBanner
                        fullNameField
                        usernameField
                        bioField
                        skinTypeSection
                        Spacer(minLength: 40)
                    }
                    .padding(24)
                }
            }
            .navigationTitle(lang.s(.editProfileTitle))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showQuiz) {
                SkinTypeQuizView(onQuizComplete: { result in
                    skinType = result
                    showQuiz = false
                })
                .environmentObject(authViewModel)
                .environmentObject(lang)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text(lang.s(.editProfileCancel))
                            .foregroundColor(Color(hex: "7B5455"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await saveProfile() } }) {
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

    // MARK: - Sub-views

    @ViewBuilder
    private var errorBanner: some View {
        if let error = errorMessage {
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "EF4444"))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "FEE2E2"))
                .cornerRadius(8)
        }
    }

    private var fullNameField: some View {
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
    }

    private var usernameField: some View {
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
                        if cleaned != newVal { username = cleaned }
                        if cleaned == initialProfile?.username {
                            isUsernameAvailable = true
                            isCheckingUsername = false
                        } else {
                            scheduleCheck(cleaned)
                        }
                    }
                usernameStatusIcon
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(usernameBorderColor, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var usernameStatusIcon: some View {
        if isCheckingUsername {
            ProgressView().scaleEffect(0.8).tint(Color(hex: "D4728C"))
        } else if username != initialProfile?.username && username.count >= 3 {
            if let available = isUsernameAvailable {
                Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(available ? .green : .red)
            }
        }
    }

    private var bioField: some View {
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
        }
    }

    private var skinTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            skinTypeSectionHeader
            skinTypeGrid
        }
    }

    private var skinTypeSectionHeader: some View {
        HStack {
            Text(lang.s(.skinTypeLabel))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "7B5455"))
            Spacer()
            Button { showQuiz = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 11))
                    Text(lang.s(.quizDiscoverButton))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color(hex: "D4728C"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "D4728C").opacity(0.08))
                .clipShape(Capsule())
            }
        }
    }

    private var skinTypeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(skinTypes, id: \.self) { type in
                skinTypeButton(type)
            }
        }
    }

    private func skinTypeButton(_ type: String) -> some View {
        let isSelected = skinType == type
        return Button {
            skinType = isSelected ? nil : type
        } label: {
            HStack(spacing: 8) {
                Image(systemName: skinTypeIcon(type))
                    .font(.system(size: 14))
                Text(lang.s(skinTypeKey(type)))
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: "D4728C") : Color.white)
            .foregroundColor(isSelected ? .white : Color(hex: "7B5455"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "D4728C") : Color(hex: "F3D5DC"), lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

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
                skinType: skinType,
                username: username,
                bio: bio
            )
            let updatedUser = try await APIClient.shared.getMe()
            await MainActor.run { authViewModel.currentUser = updatedUser }
            onSaveComplete()
            dismiss()
        } catch let error as APIClientError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Profil güncellenemedi."
        }
        isSaving = false
    }

    private func skinTypeIcon(_ type: String) -> String {
        switch type {
        case "Yağlı": return "drop.fill"
        case "Kuru": return "sun.max.fill"
        case "Karma": return "circle.lefthalf.filled"
        case "Hassas": return "leaf.fill"
        case "Akneye Meyilli": return "exclamationmark.circle.fill"
        case "Olgun": return "sparkles"
        default: return "face.smiling"
        }
    }

    private func skinTypeKey(_ type: String) -> L10nKey {
        switch type {
        case "Yağlı": return .skinTypeOily
        case "Kuru": return .skinTypeDry
        case "Karma": return .skinTypeCombination
        case "Hassas": return .skinTypeSensitive
        case "Akneye Meyilli": return .skinTypeAcneProne
        case "Olgun": return .skinTypeMature
        default: return .skinTypeNormal
        }
    }
}
