import SwiftUI
import Kingfisher

private let mockRoutineImages = [
    "applying_serum_mock",
    "cosmetic_bottles_mock",
    "daily_skincare_mock",
    "skincare_flatlay_mock"
]

@MainActor
class SocialFeedViewModel: ObservableObject {
    @Published var routines: [RoutineFeedItem] = []
    @Published var matchedUsers: [PublicUserProfileResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText: String = "" {
        didSet { scheduleUserSearch() }
    }

    private var searchTask: Task<Void, Never>?

    func fetchFeed() async {
        isLoading = true
        errorMessage = nil
        do {
            routines = try await APIClient.shared.getRoutineFeed(limit: 30)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await fetchFeed()
    }

    func toggleLike(routineId: String) async {
        do {
            let response = try await APIClient.shared.toggleRoutineLike(routineId: routineId)
            if let index = routines.firstIndex(where: { $0.id == routineId }) {
                routines[index].likeCount = response.likeCount
                routines[index].hasLiked = response.isLiked
            }
        } catch {
            print("Like toggle error: \(error)")
        }
    }

    func updateRoutine(_ detail: RoutineDetail) {
        if let index = routines.firstIndex(where: { $0.id == detail.id }) {
            routines[index].likeCount = detail.likeCount
            routines[index].commentCount = detail.commentCount
            routines[index].hasLiked = detail.hasLiked
        }
    }

    func removeRoutine(id: String) {
        withAnimation {
            routines.removeAll { $0.id == id }
        }
    }

    var filteredRoutines: [RoutineFeedItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return routines }
        return routines.filter {
            $0.title.lowercased().contains(query)
            || $0.userName.lowercased().contains(query)
            || ($0.description?.lowercased().contains(query) ?? false)
            || ($0.tags?.joined(separator: " ").lowercased().contains(query) ?? false)
        }
    }

    private func scheduleUserSearch() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            matchedUsers = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            let results = (try? await APIClient.shared.searchUsers(query: query)) ?? []
            guard !Task.isCancelled else { return }
            matchedUsers = results
        }
    }
}

struct SocialFeedView: View {
    @StateObject private var viewModel = SocialFeedViewModel()
    @EnvironmentObject var lang: LanguageManager
    @State private var showCreate = false
    @State private var selectedRoutine: RoutineSelection?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()

                VStack(spacing: 12) {
                    SearchBar(text: $viewModel.searchText, placeholder: lang.s(.socialSearchPlaceholder))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if viewModel.isLoading && viewModel.routines.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(Color(hex: "D4728C"))
                            Text(lang.s(.socialLoading))
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "9CA3AF"))
                        }
                        .padding(.top, 40)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {

                                // ── Kullanıcı sonuçları ──
                                if !viewModel.matchedUsers.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(lang.s(.socialPeople))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Color(hex: "D4728C"))
                                            .tracking(1.2)
                                            .padding(.horizontal, 16)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 12) {
                                                ForEach(viewModel.matchedUsers) { user in
                                                    NavigationLink(destination: UserProfileView(userName: user.username ?? "")) {
                                                        UserSearchCard(user: user)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                    .padding(.top, 4)

                                    if !viewModel.filteredRoutines.isEmpty {
                                        HStack {
                                            Text(lang.s(.socialRoutines))
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(Color(hex: "D4728C"))
                                                .tracking(1.2)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, 4)
                                    }
                                }

                                // ── Rutin sonuçları ──
                                if viewModel.filteredRoutines.isEmpty && !viewModel.searchText.isEmpty && viewModel.matchedUsers.isEmpty {
                                    VStack(spacing: 14) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 40))
                                            .foregroundColor(Color(hex: "D4728C").opacity(0.25))
                                        Text(lang.s(.socialNoResults))
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(Color(hex: "1A1A2E"))
                                        Text(lang.s(.socialDiffSearch))
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "9CA3AF"))
                                    }
                                    .padding(.top, 40)
                                } else if viewModel.filteredRoutines.isEmpty && viewModel.searchText.isEmpty {
                                    VStack(spacing: 14) {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(Color(hex: "D4728C").opacity(0.25))
                                        Text(lang.s(.socialNoRoutines))
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(Color(hex: "1A1A2E"))
                                        Text(lang.s(.socialBeFirst))
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "9CA3AF"))
                                    }
                                    .padding(.top, 40)
                                } else {
                                    ForEach(viewModel.filteredRoutines) { routine in
                                        RoutineCard(
                                            routine: routine,
                                            onLike: {
                                                Task { await viewModel.toggleLike(routineId: routine.id) }
                                            },
                                            onOpen: {
                                                selectedRoutine = RoutineSelection(id: routine.id)
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100)
                        }
                        .scrollDismissesKeyboard(.immediately)
                    }
                }
            }
            .navigationTitle(lang.s(.socialTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "D4728C"))
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                RoutineCreateView {
                    Task { await viewModel.refresh() }
                }
            }
            .sheet(item: $selectedRoutine) { selection in
                NavigationStack {
                    RoutineDetailView(routineId: selection.id) { updated in
                        viewModel.updateRoutine(updated)
                    } onDelete: { id in
                        viewModel.removeRoutine(id: id)
                    }
                }
            }
            .task {
                await viewModel.fetchFeed()
            }
        }
        .onTapGesture { hideKeyboard() }
    }
}

private struct RoutineSelection: Identifiable {
    let id: String
}

private struct UserSearchCard: View {
    let user: PublicUserProfileResponse

    private var displayName: String { user.username ?? user.fullName ?? "?" }

    private var initials: String {
        let name = user.fullName ?? user.username ?? "?"
        let parts = name.split(separator: " ").compactMap { $0.first.map(String.init) }
        let result = parts.prefix(2).joined().uppercased()
        return result.isEmpty ? String(name.prefix(1)).uppercased() : result
    }

    var body: some View {
        VStack(spacing: 8) {
            AvatarView(name: displayName, imageUrl: user.profileImageUrl, size: 56)
            
            Text("@\(displayName)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "1A1A2E"))
                .lineLimit(1)
                .frame(width: 72)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color(hex: "D4728C").opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

private struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(hex: "D4728C"))
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "1A1A2E"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(hex: "F7E9EC"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "F3D5DC"), lineWidth: 1)
        )
        .zIndex(10)
    }
}

private struct RoutineCard: View {
    let routine: RoutineFeedItem
    let onLike: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink(destination: UserProfileView(userName: routine.userUsername ?? routine.userName)) {
                    HStack(spacing: 10) {
                        AvatarView(name: routine.userName, imageUrl: routine.userProfileImageUrl)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(routine.userName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A2E"))
                            Text(timeAgo(routine.createdAt))
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "9CA3AF"))
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                if let skinType = routine.skinType, !skinType.isEmpty {
                    Text(skinType.formattedSkinType)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "F3D5DC"))
                        .foregroundColor(Color(hex: "9A4C5E"))
                        .cornerRadius(8)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(routine.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))

                if let description = routine.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "6B7280"))
                }
            }

            // Kapak resmi — varsa gerçek, yoksa mock
            let mockImg = mockRoutineImages[abs(routine.id.hashValue) % mockRoutineImages.count]
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "F3F4F6"))
                    .frame(height: 190)

                if let coverImageUrl = routine.coverImageUrl, !coverImageUrl.isEmpty {
                    CachedImageView(url: URL(string: coverImageUrl))
                        .frame(width: UIScreen.main.bounds.width - 60, height: 190)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Image(mockImg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width - 60, height: 190)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .frame(width: UIScreen.main.bounds.width - 60, height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Products list - Always show if products exist, but style differently if no cover image
            if let products = routine.products, !products.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(routine.coverImageUrl == nil || routine.coverImageUrl!.isEmpty ? "CORE PRODUCTS" : "PRODUCTS USED")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "D4728C"))
                        .tracking(1)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(products) { product in
                                NavigationLink(destination: ProductDetailView(productId: product.productId)) {
                                    RoutineProductThumbnail(product: product)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if let tags = routine.tags, !tags.isEmpty {
                WrapTags(tags: tags)
            } else if let focus = routine.focus, !focus.isEmpty {
                WrapTags(tags: [focus])
            }

            HStack(spacing: 18) {
                Button(action: onLike) {
                    HStack(spacing: 6) {
                        Image(systemName: routine.hasLiked ? "heart.fill" : "heart")
                            .foregroundColor(routine.hasLiked ? Color(hex: "D4728C") : Color(hex: "9CA3AF"))
                        Text("\(routine.likeCount)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(Color(hex: "9CA3AF"))
                    Text("\(routine.commentCount)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "6B7280"))
                }

            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color(hex: "D4728C").opacity(0.08), radius: 10, x: 0, y: 4)
        .onTapGesture { onOpen() }
    }
}

private struct RoutineProductThumbnail: View {
    let product: RoutineProduct

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "F3D5DC").opacity(0.5), lineWidth: 1)
                    )

                CachedImageView(url: URL(string: product.imageUrl ?? ""), contentMode: .fit, placeholderIcon: "heart.text.square")
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(product.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "1A1A2E"))
                .lineLimit(1)
                .frame(width: 80)
        }
    }
}


#Preview {
    SocialFeedView()
        .environmentObject(AuthViewModel())
}
