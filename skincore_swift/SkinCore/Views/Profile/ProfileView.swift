import SwiftUI

// MARK: - ProfileView (kendi profili)

// RoutineSelection SocialFeedView'da da tanımlı, burada aynı struct
// struct RoutineSelection zaten internal — erişilemiyorsa local tanım kullan
private struct ProfileRoutineSelection: Identifiable {
    let id: String
}

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab: ProfileTab = .routines
    @State private var myRoutines: [RoutineFeedItem] = []
    @State private var favorites: [FavoriteResponse] = []
    @State private var isLoading = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── Avatar + isim + stats ──
                        ProfileHeaderSection(
                            name: authViewModel.currentUser?.fullName ?? "Kullanıcı",
                            email: authViewModel.currentUser?.email ?? "",
                            routineCount: myRoutines.count,
                            isOwnProfile: true
                        )

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
                            FavoritesGridSection(favorites: favorites)
                        }
                    }
                }
            }
            .navigationTitle("MY SKINCORE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            }
            .task { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        async let routinesResult = APIClient.shared.getMyRoutines()
        async let favoritesResult = APIClient.shared.getFavorites()
        myRoutines = (try? await routinesResult) ?? []
        favorites = (try? await favoritesResult) ?? []
        isLoading = false
    }
}

// MARK: - UserProfileView (başkasının profili)

struct UserProfileView: View {
    let userName: String
    @State private var routines: [RoutineFeedItem] = []
    @State private var isLoading = false
    @State private var selectedRoutine: ProfileRoutineSelection?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ProfileHeaderSection(
                        name: userName,
                        email: nil,
                        routineCount: routines.count,
                        isOwnProfile: false
                    )

                    if isLoading {
                        ProgressView()
                            .tint(Color(hex: "D4728C"))
                            .padding(.top, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Rutinler")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: "7B5455"))
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                            RoutineGridSection(routines: routines, onTap: { id in
                                selectedRoutine = ProfileRoutineSelection(id: id)
                            })
                        }
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
        .task { await loadRoutines() }
    }

    private func loadRoutines() async {
        isLoading = true
        routines = (try? await APIClient.shared.getRoutineFeed(limit: 50)) ?? []
        routines = routines.filter { $0.userName == userName }
        isLoading = false
    }
}

// MARK: - Shared Header

private struct ProfileHeaderSection: View {
    let name: String
    let email: String?
    let routineCount: Int
    let isOwnProfile: Bool

    private var initials: String {
        let parts = name.split(separator: " ").compactMap { $0.first.map(String.init) }
        return parts.prefix(2).joined().uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: "FED9E2"))
                    .frame(width: 100, height: 100)
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(hex: "7B5455"))
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

            // Stats
            HStack(spacing: 40) {
                StatItem(value: "\(routineCount)", label: "Rutinler")
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

private struct ProfileTabBar: View {
    @Binding var selected: ProfileTab

    var body: some View {
        HStack(spacing: 0) {
            TabButton(title: "Rutinlerim", isSelected: selected == .routines) {
                selected = .routines
            }
            TabButton(title: "Favoriler", isSelected: selected == .favorites) {
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

private struct RoutineGridSection: View {
    let routines: [RoutineFeedItem]
    var onTap: ((String) -> Void)? = nil
    @State private var selectedRoutine: ProfileRoutineSelection?

    private let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

    var body: some View {
        if routines.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                Text("Henüz rutin yok")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
            .padding(.top, 50)
        } else {
            LazyVGrid(columns: columns, spacing: 3) {
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
            .padding(.top, 3)
            .sheet(item: $selectedRoutine) { selection in
                NavigationStack {
                    RoutineDetailView(routineId: selection.id)
                }
                .presentationDetents([.large])
            }
        }
    }
}

private struct RoutineGridCell: View {
    let routine: RoutineFeedItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = routine.coverImageUrl, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Color(hex: "F3E8E8")
                    }
                }
            } else {
                Color(hex: "F3E8E8")
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "D4728C").opacity(0.4))
            }

            // Alt gradient + başlık
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center, endPoint: .bottom
            )
            Text(routine.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(8)
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }
}

// MARK: - Favorites Grid

private struct FavoritesGridSection: View {
    let favorites: [FavoriteResponse]

    private let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

    var body: some View {
        if favorites.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "heart")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                Text("Henüz favori yok")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
            .padding(.top, 50)
        } else {
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(favorites) { fav in
                    NavigationLink(destination: ProductDetailView(productId: fav.productId)) {
                        ZStack(alignment: .bottomLeading) {
                            if let url = fav.productImageURL, let imageUrl = URL(string: url) {
                                AsyncImage(url: imageUrl) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    default:
                                        Color(hex: "F3E8E8")
                                    }
                                }
                            } else {
                                Color(hex: "F3E8E8")
                            }
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.45)],
                                startPoint: .center, endPoint: .bottom
                            )
                            Text(fav.productName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .padding(8)
                        }
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 3)
        }
    }
}

// MARK: - Settings Sheet

private struct SettingsSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        SettingsRow(icon: "person.fill", title: "Hesap Ayarları")
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "bell.fill", title: "Bildirimler")
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "shield.lefthalf.fill", title: "Gizlilik")
                        Divider().padding(.leading, 56)
                        Button {
                            authViewModel.logout()
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(Color(hex: "EF4444"))
                                    .frame(width: 24)
                                Text("Çıkış Yap")
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
                    .padding(.top, 24)
                    Spacer()
                }
            }
            .navigationTitle("Ayarlar")
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
