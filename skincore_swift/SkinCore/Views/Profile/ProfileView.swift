import SwiftUI
import PhotosUI

// MARK: - ProfileView (kendi profili)

// RoutineSelection SocialFeedView'da da tanımlı, burada aynı struct
// struct RoutineSelection zaten internal — erişilemiyorsa local tanım kullan
private struct ProfileRoutineSelection: Identifiable {
    let id: String
}

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @State private var selectedTab: ProfileTab = .routines
    @State private var myRoutines: [RoutineFeedItem] = []
    @State private var favorites: [FavoriteResponse] = []
    @State private var favoriteRoutines: [RoutineFeedItem] = []
    @State private var favoriteType: FavoriteType = .products
    @State private var profileData: UserProfileResponse?
    @State private var isLoading = false
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── Avatar + isim + stats ──
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            ProfileHeaderSection(
                                name: profileData?.fullName ?? authViewModel.currentUser?.fullName ?? lang.s(.profileDefaultName),
                                email: profileData?.username.map { "@\($0)" } ?? authViewModel.currentUser?.email ?? "",
                                bio: profileData?.bio,
                                profileImageUrl: profileData?.profileImageUrl,
                                routineCount: myRoutines.count,
                                followerCount: profileData?.followerCount ?? 0,
                                followingCount: profileData?.followingCount ?? 0,
                                isOwnProfile: true
                            )
                        }
                        .buttonStyle(.plain)
                        .onChange(of: photoPickerItem) { _, item in
                            Task { await uploadPhoto(item) }
                        }
                        .overlay {
                            if isUploadingPhoto {
                                ProgressView()
                                    .tint(Color(hex: "D4728C"))
                                    .padding(.top, 70)
                            }
                        }

                        // ── Tab seçici ──
                        ProfileTabBar(selected: $selectedTab)
                            .padding(.top, 8)

                        Divider()
                            .padding(.horizontal, 20)

                        // ── İçerik ──
                        if isLoading {
                            ProgressView()
                                .tint(Color(hex: "D4728C"))
                                .padding(.top, 40)
                        } else if selectedTab == .routines {
                            RoutineGridSection(routines: myRoutines)
                        } else {
                            FavoritesGridSection(
                                favorites: favorites,
                                favoriteRoutines: favoriteRoutines,
                                favoriteType: $favoriteType
                            )
                        }
                    }
                }
            }
            .navigationTitle(lang.s(.profileTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showEditProfile = true } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(hex: "D4728C"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(Color(hex: "7B5455"))
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    .environmentObject(authViewModel)
                    .environmentObject(lang)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(profile: profileData) {
                    Task { await loadData() }
                }
                .environmentObject(authViewModel)
                .environmentObject(lang)
            }
            .task { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        async let routinesResult = APIClient.shared.getMyRoutines()
        async let favoritesResult = APIClient.shared.getFavorites()
        async let profileResult = APIClient.shared.getMyProfile()
        async let favoriteRoutinesResult = APIClient.shared.getFavoriteRoutines()
        myRoutines = (try? await routinesResult) ?? []
        favorites = (try? await favoritesResult) ?? []
        favoriteRoutines = (try? await favoriteRoutinesResult) ?? []
        profileData = try? await profileResult
        isLoading = false
    }

    private func uploadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isUploadingPhoto = true
        if let data = try? await item.loadTransferable(type: Data.self) {
            if (try? await APIClient.shared.uploadProfileImage(data: data)) != nil {
                profileData = try? await APIClient.shared.getMyProfile()
            }
        }
        isUploadingPhoto = false
        photoPickerItem = nil
    }

    private func resolvedImageUrl(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return path }
        #if targetEnvironment(simulator)
        return "http://localhost:5192\(path)"
        #else
        return "http://192.168.0.15:5192\(path)"
        #endif
    }
}

// MARK: - UserProfileView (başkasının profili)

struct UserProfileView: View {
    let userName: String
    @EnvironmentObject var lang: LanguageManager
    @State private var publicProfile: PublicUserProfileResponse?
    @State private var routines: [RoutineFeedItem] = []
    @State private var favorites: [FavoriteResponse] = []
    @State private var favoriteRoutines: [RoutineFeedItem] = []
    @State private var favoriteType: FavoriteType = .products
    @State private var selectedTab: ProfileTab = .routines
    @State private var isLoading = false
    @State private var isFollowLoading = false
    @State private var selectedRoutine: ProfileRoutineSelection?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ProfileHeaderSection(
                        name: publicProfile?.fullName ?? userName,
                        email: publicProfile?.username.map { "@\($0)" },
                        bio: publicProfile?.bio,
                        profileImageUrl: publicProfile?.profileImageUrl,
                        routineCount: routines.count,
                        followerCount: publicProfile?.followerCount ?? 0,
                        followingCount: publicProfile?.followingCount ?? 0,
                        isOwnProfile: false
                    )

                    // Follow / Unfollow button
                    if let profile = publicProfile {
                        Button {
                            Task { await toggleFollow(profile: profile) }
                        } label: {
                            HStack(spacing: 6) {
                                if isFollowLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(profile.isFollowing ? Color(hex: "D4728C") : Color.white)
                                } else {
                                    Text(profile.isFollowing ? lang.s(.profileUnfollow) : lang.s(.profileFollow))
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .frame(width: 140, height: 36)
                            .background(profile.isFollowing ? Color.white : Color(hex: "D4728C"))
                            .foregroundColor(profile.isFollowing ? Color(hex: "D4728C") : Color.white)
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color(hex: "D4728C"), lineWidth: 1.5)
                            )
                        }
                        .disabled(isFollowLoading)
                        .padding(.bottom, 8)
                    }

                    ProfileTabBar(selected: $selectedTab)
                        .padding(.top, 8)

                    Divider().padding(.horizontal, 20)

                    if isLoading {
                        ProgressView()
                            .tint(Color(hex: "D4728C"))
                            .padding(.top, 40)
                    } else if selectedTab == .routines {
                        RoutineGridSection(routines: routines, onTap: { id in
                            selectedRoutine = ProfileRoutineSelection(id: id)
                        })
                    } else {
                        FavoritesGridSection(
                            favorites: favorites,
                            favoriteRoutines: favoriteRoutines,
                            favoriteType: $favoriteType
                        )
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(hex: "7B5455"))
                }
            }
        }
        .navigationTitle("@\(userName)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedRoutine) { selection in
            NavigationStack {
                RoutineDetailView(routineId: selection.id)
            }
            .presentationDetents([.large])
        }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        async let profileResult = APIClient.shared.getPublicProfile(username: userName)
        async let feedResult = APIClient.shared.getRoutineFeed(limit: 50)
        async let favResult = APIClient.shared.getPublicFavorites(username: userName)
        async let favRoutinesResult = APIClient.shared.getFavoriteRoutines(limit: 50)
        publicProfile = try? await profileResult
        let all = (try? await feedResult) ?? []
        routines = all.filter { $0.userName == userName }
        favorites = (try? await favResult) ?? []
        // Tüm favorilenen rutinler
        favoriteRoutines = (try? await favRoutinesResult) ?? []
        isLoading = false
    }

    private func toggleFollow(profile: PublicUserProfileResponse) async {
        isFollowLoading = true
        do {
            if profile.isFollowing {
                _ = try await APIClient.shared.unfollowUser(userId: profile.id)
            } else {
                _ = try await APIClient.shared.followUser(userId: profile.id)
            }
            publicProfile = try? await APIClient.shared.getPublicProfile(username: userName)
        } catch {}
        isFollowLoading = false
    }
}

// MARK: - Shared Header

private struct ProfileHeaderSection: View {
    let name: String
    let email: String?
    let bio: String?
    let profileImageUrl: String?
    let routineCount: Int
    let followerCount: Int
    let followingCount: Int
    let isOwnProfile: Bool
    @EnvironmentObject var lang: LanguageManager

    private var initials: String {
        let parts = name.split(separator: " ").compactMap { $0.first.map(String.init) }
        return parts.prefix(2).joined().uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: name, imageUrl: profileImageUrl, size: 100)
                
                if isOwnProfile {
                    ZStack {
                        Circle().fill(Color(hex: "D4728C")).frame(width: 30, height: 30)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                    }
                    .offset(x: 4, y: 4)
                }
            }
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
            .padding(.top, 24)
            .padding(.bottom, 12)

            // İsim
            Text(name)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color(hex: "1A1A2E"))

            // Email veya username
            if let email {
                Text(email)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "9CA3AF"))
                    .padding(.top, 2)
            }

            // Bio
            if let bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6B7280"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }

            // Stats
            HStack(spacing: 32) {
                StatItem(value: "\(routineCount)", label: lang.s(.profileRoutines))
                if isOwnProfile {
                    NavigationLink(destination: ConnectionsView(mode: .followers)) {
                        StatItem(value: "\(followerCount)", label: lang.s(.profileFollowers))
                    }
                    .buttonStyle(.plain)
                    NavigationLink(destination: ConnectionsView(mode: .following)) {
                        StatItem(value: "\(followingCount)", label: lang.s(.profileFollowing))
                    }
                    .buttonStyle(.plain)
                } else {
                    StatItem(value: "\(followerCount)", label: lang.s(.profileFollowers))
                    StatItem(value: "\(followingCount)", label: lang.s(.profileFollowing))
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "1A1A2E"))
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Color(hex: "9CA3AF"))
        }
    }
}

// MARK: - Tab Bar

enum ProfileTab { case routines, favorites }

enum FavoriteType {
    case products
    case routines
}

private struct ProfileTabBar: View {
    @Binding var selected: ProfileTab
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        HStack(spacing: 0) {
            TabButton(title: lang.s(.profileMyRoutines), isSelected: selected == .routines) {
                selected = .routines
            }
            TabButton(title: lang.s(.profileFavorites), isSelected: selected == .favorites) {
                selected = .favorites
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color(hex: "7B5455") : Color(hex: "9CA3AF"))
                    .padding(.horizontal, 4)
                Rectangle()
                    .fill(isSelected ? Color(hex: "D4728C") : Color.clear)
                    .frame(height: 2.5)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Routine Grid

private let mockRoutineImages = [
    "applying_serum_mock",
    "cosmetic_bottles_mock",
    "daily_skincare_mock",
    "skincare_flatlay_mock"
]

private struct RoutineGridSection: View {
    let routines: [RoutineFeedItem]
    var onTap: ((String) -> Void)? = nil
    @State private var selectedRoutine: ProfileRoutineSelection?
    @EnvironmentObject var lang: LanguageManager

    private let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]

    var body: some View {
        if routines.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                Text(lang.s(.profileNoRoutines))
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
            .padding(.top, 50)
        } else {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(routines) { routine in
                    Button {
                        if let onTap { onTap(routine.id) }
                        else { selectedRoutine = ProfileRoutineSelection(id: routine.id) }
                    } label: {
                        RoutineGridCell(routine: routine)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .sheet(item: $selectedRoutine) { selection in
                NavigationStack { RoutineDetailView(routineId: selection.id) }
                .presentationDetents([.large])
            }
        }
    }
}

private struct RoutineGridCell: View {
    let routine: RoutineFeedItem

    private var mockImage: String {
        mockRoutineImages[abs(routine.id.hashValue) % mockRoutineImages.count]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Görsel
                Group {
                    if let url = routine.coverImageUrl, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Image(mockImage).resizable().scaledToFill()
                            }
                        }
                    } else {
                        Image(mockImage).resizable().scaledToFill()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()

            }
            .frame(width: geo.size.width, height: geo.size.width)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Favorites Grid

private struct FavoritesGridSection: View {
    let favorites: [FavoriteResponse]
    let favoriteRoutines: [RoutineFeedItem]
    @Binding var favoriteType: FavoriteType
    @EnvironmentObject var lang: LanguageManager
    @State private var selectedRoutine: ProfileRoutineSelection?

    private let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // İki buton - tam genişlik
            HStack(spacing: 10) {
                Button(action: { favoriteType = .products }) {
                    Text(lang.s(.favoriteProductsTitle))
                        .font(.system(size: 13, weight: favoriteType == .products ? .semibold : .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(favoriteType == .products ? Color(hex: "D4728C") : Color(hex: "F3D5DC"))
                        .foregroundColor(favoriteType == .products ? Color.white : Color(hex: "9A4C5E"))
                        .cornerRadius(10)
                        .lineLimit(1)
                }
                
                Button(action: { favoriteType = .routines }) {
                    Text(lang.s(.favoriteRoutinesTitle))
                        .font(.system(size: 13, weight: favoriteType == .routines ? .semibold : .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(favoriteType == .routines ? Color(hex: "D4728C") : Color(hex: "F3D5DC"))
                        .foregroundColor(favoriteType == .routines ? Color.white : Color(hex: "9A4C5E"))
                        .cornerRadius(10)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 0)
            
            // İçerik
            if favoriteType == .products {
                if favorites.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                        Text(lang.s(.profileNoFavorites))
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                } else {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(favorites) { fav in
                            NavigationLink(destination: ProductDetailView(productId: fav.productId)) {
                                FavoriteGridCell(fav: fav)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            } else {
                if favoriteRoutines.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                        Text(lang.s(.profileNoRoutines))
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                } else {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(favoriteRoutines) { routine in
                            Button {
                                selectedRoutine = ProfileRoutineSelection(id: routine.id)
                            } label: {
                                RoutineGridCell(routine: routine)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .sheet(item: $selectedRoutine) { selection in
                        NavigationStack { RoutineDetailView(routineId: selection.id) }
                            .presentationDetents([.large])
                    }
                }
            }
        }
    }
}

private struct FavoriteGridCell: View {
    let fav: FavoriteResponse

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let url = fav.productImageURL, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Color(hex: "F3E8E8")
                            }
                        }
                    } else {
                        Color(hex: "F3E8E8")
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()

            }
            .frame(width: geo.size.width, height: geo.size.width)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Settings Sheet

private struct SettingsSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss
    @State private var showChangePassword = false
    @State private var notificationsEnabled: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                VStack(spacing: 0) {
                    // Other settings
                    VStack(spacing: 0) {
                        Button { showChangePassword = true } label: {
                            SettingsRow(icon: "lock.fill", title: lang.s(.changePasswordTitle))
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 56)
                        HStack(spacing: 16) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(Color(hex: "7B5455"))
                                .frame(width: 24)
                            Text(lang.s(.profileNotifications))
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Toggle("", isOn: $notificationsEnabled)
                                .labelsHidden()
                                .tint(Color(hex: "E07D7D"))
                                .onChange(of: notificationsEnabled) { newValue in
                                    Task {
                                        await authViewModel.updateNotifications(enabled: newValue)
                                    }
                                }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "shield.lefthalf.fill", title: lang.s(.profilePrivacy))
                        Divider().padding(.leading, 56)
                        Button {
                            authViewModel.logout()
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(Color(hex: "EF4444"))
                                    .frame(width: 24)
                                Text(lang.s(.profileLogout))
                                    .foregroundColor(Color(hex: "EF4444"))
                                    .font(.system(size: 15))
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    Spacer()
                }
            }
            .navigationTitle(lang.s(.profileSettings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(hex: "7B5455"))
                    }
                }
            }
            .onAppear {
                notificationsEnabled = authViewModel.currentUser?.notificationsEnabled ?? true
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
                    .environmentObject(authViewModel)
                    .environmentObject(lang)
            }
        }
    }
}

private struct EditBioSheet: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss
    @State private var bioText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text(lang.s(.profileBio))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    TextEditor(text: $bioText)
                        .frame(height: 120)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "F3D5DC"), lineWidth: 1)
                                .padding(.horizontal, 16)
                        )
                        .scrollContentBackground(.hidden)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "EF4444"))
                            .padding(.horizontal, 20)
                    }

                    Spacer()
                }
            }
            .navigationTitle(lang.s(.profileEditBioTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Text(lang.s(.cancel)).foregroundColor(Color(hex: "9CA3AF"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await saveBio() }
                    } label: {
                        if isLoading {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text(lang.s(.save))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "D4728C"))
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task { await loadCurrentBio() }
    }

    private func loadCurrentBio() async {
        if let profile = try? await APIClient.shared.getMyProfile() {
            bioText = profile.bio ?? ""
        }
    }

    private func saveBio() async {
        isLoading = true
        do {
            _ = try await APIClient.shared.updateBio(bio: bioText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bioText.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "D4728C"))
                .frame(width: 24)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "1A1A2E"))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "CBD5E1"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }
}

// MARK: - Connections View

enum ConnectionsMode {
    case followers, following
    func fetch() async throws -> [PublicUserProfileResponse] {
        self == .followers
            ? try await APIClient.shared.getFollowers()
            : try await APIClient.shared.getFollowing()
    }
}

struct ConnectionsView: View {
    let mode: ConnectionsMode
    @EnvironmentObject var lang: LanguageManager
    @State private var users: [PublicUserProfileResponse] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var followingStates: [String: Bool] = [:]
    @Environment(\.dismiss) var dismiss

    var filtered: [PublicUserProfileResponse] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return users }
        return users.filter {
            ($0.username?.lowercased().contains(q) ?? false) ||
            ($0.fullName?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(hex: "D4728C"))
                    TextField(lang.s(.profileSearch), text: $searchText)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "1A1A2E"))
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color(hex: "F7E9EC"))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "F3D5DC"), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if isLoading {
                    Spacer()
                    ProgressView().tint(Color(hex: "D4728C"))
                    Spacer()
                } else if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "person.2")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "D4728C").opacity(0.25))
                        Text(searchText.isEmpty ? lang.s(.profileNobody) : lang.s(.socialNoResults))
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(filtered) { user in
                                ConnectionUserRow(
                                    user: user,
                                    isFollowing: followingStates[user.id] ?? user.isFollowing,
                                    onToggleFollow: { await toggleFollow(user: user) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
        }
        .onTapGesture { hideKeyboard() }
        .navigationTitle(mode == .followers ? lang.s(.profileFollowersTitle) : lang.s(.profileFollowingTitle))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(hex: "7B5455"))
                }
            }
        }
        .task { await loadUsers() }
    }

    private func loadUsers() async {
        isLoading = true
        users = (try? await mode.fetch()) ?? []
        isLoading = false
    }

    private func toggleFollow(user: PublicUserProfileResponse) async {
        let current = followingStates[user.id] ?? user.isFollowing
        followingStates[user.id] = !current
        do {
            if current {
                _ = try await APIClient.shared.unfollowUser(userId: user.id)
            } else {
                _ = try await APIClient.shared.followUser(userId: user.id)
            }
        } catch {
            followingStates[user.id] = current // revert on error
        }
    }
}

private struct ConnectionUserRow: View {
    let user: PublicUserProfileResponse
    let isFollowing: Bool
    let onToggleFollow: () async -> Void
    @EnvironmentObject var lang: LanguageManager

    private var initials: String {
        let name = user.fullName ?? user.username ?? "?"
        let parts = name.split(separator: " ").compactMap { $0.first.map(String.init) }
        return parts.prefix(2).joined().uppercased().isEmpty
            ? String(name.prefix(1)).uppercased()
            : parts.prefix(2).joined().uppercased()
    }

    var body: some View {
        NavigationLink(destination: UserProfileView(userName: user.username ?? "")) {
            HStack(spacing: 14) {
                // Avatar
                AvatarView(name: user.username ?? user.fullName ?? "?", imageUrl: user.profileImageUrl, size: 52)

                // İsim + bio
                VStack(alignment: .leading, spacing: 3) {
                    Text("@\(user.username ?? user.fullName ?? "")")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "9CA3AF"))
                            .lineLimit(1)
                    } else if let skinType = user.skinType, !skinType.isEmpty {
                        Text(skinType)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                }

                Spacer()

                // Follow/Unfollow button
                Button {
                    Task { await onToggleFollow() }
                } label: {
                    Text(isFollowing ? lang.s(.profileUnfollow) : lang.s(.profileFollow))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isFollowing ? Color(hex: "7B5455") : Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(isFollowing ? Color.white : Color(hex: "D4728C"))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: "D4728C").opacity(isFollowing ? 0.4 : 0), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color(hex: "D4728C").opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}
