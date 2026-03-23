import SwiftUI
import Combine

// MARK: - HomeViewModel

@MainActor
class HomeViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published var searchResults: [Product] = []
    @Published var isSearching: Bool = false

    @Published var popularProducts: [PopularProductResponse] = []
    @Published var isLoadingPopular: Bool = false

    @Published var searchHistory: [SearchHistoryResponse] = []
    @Published var isLoadingHistory: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {

        $searchText
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                Task { await self.search(query: query) }
            }
            .store(in: &cancellables)

        Task {
            await fetchPopular()
            await fetchHistory()
        }
    }

    // MARK: SEARCH

    func search(query: String) async {

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        do {

            let results = try await APIClient.shared.searchProductsByName(
                query: trimmed,
                maxResults: 10
            )

            searchResults = results

            let first = results.first

            Task {
                await addToHistory(
                    query: trimmed,
                    productId: first?.id,
                    productName: first?.name,
                    category: first?.brand
                )
            }

        } catch {
            searchResults = []
        }

        isSearching = false
    }

    // MARK: POPULAR

    func fetchPopular() async {

        isLoadingPopular = true

        do {
            popularProducts = try await APIClient.shared.getPopularProducts(limit: 10)
        } catch {
            print("Popular fetch error:", error)
        }

        isLoadingPopular = false
    }

    // MARK: HISTORY

    func fetchHistory() async {

        isLoadingHistory = true

        do {
            searchHistory = try await APIClient.shared.getSearchHistory(limit: 20)
        } catch {
            print("History fetch error:", error)
        }

        isLoadingHistory = false
    }

    func addToHistory(
        query: String,
        productId: String?,
        productName: String?,
        category: String?
    ) async {

        let req = AddSearchHistoryRequest(
            query: query,
            productId: productId,
            productName: productName,
            category: category
        )

        do {

            _ = try await APIClient.shared.addSearchHistory(req)

            let newItem = SearchHistoryResponse(
                id: UUID().uuidString,
                query: query,
                productId: productId,
                productName: productName,
                category: category,
                imageUrl: nil,
                searchedAt: nil,
                imageUrls: nil
            )

            // UI güncellemesi MainActor üzerinde olmalı
            await MainActor.run {
                searchHistory.insert(newItem, at: 0)

                if searchHistory.count > 20 {
                    searchHistory = Array(searchHistory.prefix(20))
                }
            }

        } catch {
            print("Add history error:", error)
        }
    }

    func deleteHistoryItem(id: String) async {

        do {
            _ = try await APIClient.shared.deleteSearchHistoryItem(itemId: id)
            searchHistory.removeAll { $0.id == id }
        } catch {
            print("Delete history error:", error)
        }
    }

    func clearHistory() async {

        do {
            _ = try await APIClient.shared.clearSearchHistory()
            searchHistory = []
        } catch {
            print("Clear history error:", error)
        }
    }
}

// MARK: - Popular Product Card

private struct PopularProductCard: View {
    let item: PopularProductResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "F3F4F6"))
                    .frame(height: 140)

                AsyncImage(url: URL(string: item.resolvedImageUrl ?? "")) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    default:
                        Image(systemName: "drop.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "D4728C").opacity(0.4))
                    }
                }
            }
            .clipped()

            Text(item.productName ?? "Ürün")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "1A1A2E"))
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "F59E0B"))
                Text("Popüler")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "F59E0B"))
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let item: SearchHistoryResponse
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "F3F4F6"))
                    .frame(width: 48, height: 48)
                AsyncImage(url: URL(string: item.resolvedImageUrl ?? "")) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    default:
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.query)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                    .lineLimit(1)
                if let name = item.productName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .lineLimit(1)
                }
                if let cat = item.category, !cat.isEmpty {
                    Text(cat)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "D4728C"))
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "CBD5E1"))
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Search Results Panel

private struct SearchResultsPanel: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if viewModel.isSearching {
                    ProgressView().scaleEffect(0.8).tint(Color(hex: "D4728C"))
                    Text("Aranıyor…")
                        .font(.caption.bold())
                        .foregroundColor(Color(hex: "9CA3AF"))
                } else {
                    Text(viewModel.searchResults.isEmpty
                         ? "Sonuç bulunamadı"
                         : "\(viewModel.searchResults.count) ürün bulundu")
                        .font(.caption.bold())
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
                Spacer()
            }
            .padding(.horizontal)

            if !viewModel.isSearching {
                if viewModel.searchResults.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                        Text("'\(viewModel.searchText)' için ürün bulunamadı")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.searchResults) { product in
                            NavigationLink(destination: ProductDetailView(productId: product.id)) {
                                HomeProductRow(product: product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.2), value: viewModel.searchResults.count)
    }
}

// MARK: - Home Product Row

private struct HomeProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: product.firstImageUrl ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }
            .frame(width: 60, height: 60)
            .background(Color(hex: "F3F4F6"))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name ?? "İsimsiz Ürün")
                    .font(.subheadline.bold())
                    .foregroundColor(Color(hex: "1A1A2E"))
                    .lineLimit(2)

                if let brand = product.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(Color(hex: "9CA3AF"))
                }

                if let count = product.productIngredients?.count, count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 9))
                        Text("\(count) içerik")
                    }
                    .font(.caption2)
                    .foregroundColor(Color(hex: "D4728C"))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Color(hex: "CBD5E1"))
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}


// MARK: - HomeView

struct HomeView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()

    @FocusState private var isSearchFocused: Bool
    @State private var isShowingProfile = false

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 24) {

                    // SEARCH BAR

                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: viewModel.isSearching ? "arrow.trianglehead.2.clockwise" : "magnifyingglass")
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .symbolEffect(.rotate, isActive: viewModel.isSearching)

                            TextField(
                                "",
                                text: $viewModel.searchText,
                                prompt: Text("Search ingredients or products...")
                                    .foregroundColor(Color(hex: "9CA3AF"))
                            )
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .foregroundColor(Color(hex: "1A1A2E"))

                            if !viewModel.searchText.isEmpty {
                                Button {
                                    viewModel.searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color(hex: "9CA3AF"))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                        )

                        // CAMERA BUTTON
                        Button {
                            // Camera action
                        } label: {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: "D4728C"))
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
                    .zIndex(20)

                    // ── Scan Your Shelf Card (Hero) ──
                    ZStack(alignment: .leading) {
                        // Custom 3D Illustrative Background Image
                        Image("scan_shelf_background")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(LinearGradient(
                                        colors: [Color.black.opacity(0.6), Color.clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("NEW FEATURE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(hex: "D4728C"))
                                .cornerRadius(6)

                            Text("Scan Your Shelf")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)

                            Text("Instantly analyze all ingredients and\ncheck safety ratings.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.9))
                                .lineSpacing(2)

                            NavigationLink(destination: ScanView()) {
                                HStack(spacing: 6) {
                                    Image(systemName: "viewfinder")
                                        .font(.system(size: 14))
                                    Text("Scan Now")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .foregroundColor(Color(hex: "1A1A2E"))
                                .cornerRadius(20)
                            }
                            .padding(.top, 4)
                        }
                        .padding(24)
                    }
                    .padding(.horizontal)


                    // SEARCH RESULTS OR CONTENT
                    if !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        SearchResultsPanel(viewModel: viewModel)
                    } else {
                        // MOST SEARCHED

                        VStack(alignment: .leading, spacing: 14) {

                            HStack {

                                Text("Most Searched")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A2E"))

                                Spacer()

                                if viewModel.isLoadingPopular {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(Color(hex: "D4728C"))
                                }
                            }
                            .padding(.horizontal)

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ],
                                spacing: 14
                            ) {

                                ForEach(viewModel.popularProducts) { item in

                                    NavigationLink(
                                        destination: ProductDetailView(productId: item.productId)
                                    ) {
                                        PopularProductCard(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }


                        // HISTORY

                        if !viewModel.searchHistory.isEmpty {

                            VStack(alignment: .leading, spacing: 14) {

                                HStack {

                                    Text("Recent Searches")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color(hex: "1A1A2E"))

                                    Spacer()

                                    Button {

                                        Task { await viewModel.clearHistory() }

                                    } label: {

                                        Text("Clear")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.horizontal)

                                LazyVStack(spacing: 8) {

                                    ForEach(viewModel.searchHistory) { item in

                                        HistoryRow(item: item) {

                                            Task {
                                                await viewModel.deleteHistoryItem(id: item.id)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(hex: "FFF0F0"))


            // NAVBAR

            .toolbar {

                ToolbarItem(placement: .navigationBarLeading) {

                    HStack(spacing: 8) {

                        Image("app_logo_header")
                            .resizable()
                            .frame(width: 40, height: 40)

                        Text("SkinCore")
                            .font(.system(size: 20, weight: .bold))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {

                    Button {

                        isShowingProfile.toggle()

                    } label: {

                        Image(systemName: "person.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                    .sheet(isPresented: $isShowingProfile) {

                        ProfileView()
                            .environmentObject(authViewModel)
                    }
                }
            }
        }
    }
}