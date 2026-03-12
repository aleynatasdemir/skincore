import SwiftUI

@MainActor
class SocialFeedViewModel: ObservableObject {
    @Published var routines: [RoutineFeedItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""

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
}

struct SocialFeedView: View {
    @StateObject private var viewModel = SocialFeedViewModel()
    @State private var showCreate = false
    @State private var selectedRoutine: RoutineSelection?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()

                VStack(spacing: 12) {
                    SearchBar(text: $viewModel.searchText)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if viewModel.isLoading && viewModel.routines.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(Color(hex: "D4728C"))
                            Text("Yükleniyor...")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "9CA3AF"))
                        }
                        .padding(.top, 40)
                    } else if viewModel.filteredRoutines.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "D4728C").opacity(0.25))
                            Text(viewModel.searchText.isEmpty ? "Henüz paylaşılmış rutin yok" : "Sonuç bulunamadı")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A2E"))
                            Text(viewModel.searchText.isEmpty ? "İlk rutini sen paylaş" : "Farklı bir arama dene")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "9CA3AF"))
                        }
                        .padding(.top, 40)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
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
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("Skincore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "F3D5DC"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "D4728C"))
                        }
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
                    }
                }
            }
            .task {
                await viewModel.fetchFeed()
            }
        }
    }
}

private struct RoutineSelection: Identifiable {
    let id: String
}

private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(hex: "D4728C"))
            TextField("Rutin ya da kullanıcı ara", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "1A1A2E"))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(hex: "F7E9EC"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "F3D5DC"), lineWidth: 1)
        )
    }
}

private struct RoutineCard: View {
    let routine: RoutineFeedItem
    let onLike: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarView(name: routine.userName)
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.userName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text(timeAgo(routine.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
                Spacer()
                if let skinType = routine.skinType, !skinType.isEmpty {
                    Text(skinType)
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

            if let coverImageUrl = routine.coverImageUrl, !coverImageUrl.isEmpty {
                 // Kapak resmi varsa resmi göster
                 ZStack {
                     RoundedRectangle(cornerRadius: 16)
                         .fill(Color(hex: "F3F4F6"))
                         .frame(height: 190)

                     AsyncImage(url: URL(string: coverImageUrl)) { phase in
                         switch phase {
                         case .success(let image):
                             image
                                 .resizable()
                                 .aspectRatio(contentMode: .fill)
                                 .frame(height: 190)
                                 .clipShape(RoundedRectangle(cornerRadius: 16))
                         default:
                             Image(systemName: "photo")
                                 .font(.system(size: 32))
                                 .foregroundColor(Color(hex: "CBD5E1"))
                         }
                     }
                 }
            }

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
                                RoutineProductThumbnail(product: product)
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

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(Color(hex: "9CA3AF"))
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

                AsyncImage(url: URL(string: product.imageUrl ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "CBD5E1"))
                    }
                }
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
