import SwiftUI
import Combine
import Kingfisher

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
    private(set) var productTapCount: Int = 0

    func handleProductTap(isPremium: Bool) {
        guard !isPremium else { return }
        productTapCount += 1
        if productTapCount % 3 == 0 {
            InterstitialAdManager.shared.showAd()
        }
    }

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

    // MARK: - Search

    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        do {
            let results = try await APIClient.shared.searchProductsByName(query: trimmed, maxResults: 10)
            searchResults = results
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    // MARK: - Popular

    func fetchPopular() async {
        isLoadingPopular = true
        do {
            popularProducts = try await APIClient.shared.getPopularProducts(limit: 10)
        } catch {
            print("Popular fetch error: \(error)")
        }
        isLoadingPopular = false
    }

    // MARK: - Search History

    func fetchHistory() async {
        isLoadingHistory = true
        do {
            searchHistory = try await APIClient.shared.getSearchHistory(limit: 5)
        } catch {
            print("History fetch error: \(error)")
        }
        isLoadingHistory = false
    }

    func addToHistory(query: String, productId: String?, productName: String?, category: String?, imageUrl: String?) async {
        let req = AddSearchHistoryRequest(query: query, productId: productId, productName: productName, category: category)
        do {
            _ = try await APIClient.shared.addSearchHistory(req)
            // Sadece local listeye ekle, fetchHistory() çağırma — aramayı yavaşlatır
            let newItem = SearchHistoryResponse(
                id: UUID().uuidString,
                query: query,
                productId: productId,
                productName: productName,
                category: category,
                imageUrl: imageUrl,
                searchedAt: nil,
                imageUrls: nil
            )
            searchHistory.insert(newItem, at: 0)
            // Max 20 tut
            if searchHistory.count > 20 { searchHistory = Array(searchHistory.prefix(20)) }
        } catch {
            print("Add history error: \(error)")
        }
    }

    func deleteHistoryItem(id: String) async {
        do {
            _ = try await APIClient.shared.deleteSearchHistoryItem(itemId: id)
            searchHistory.removeAll { $0.id == id }
        } catch {
            print("Delete history error: \(error)")
        }
    }

    func clearHistory() async {
        do {
            _ = try await APIClient.shared.clearSearchHistory()
            searchHistory = []
        } catch {
            print("Clear history error: \(error)")
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var subscriptionService: SubscriptionService
    @StateObject private var viewModel = HomeViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var selectedPopularProductId: String?
    @State private var showQuiz = false
    @State private var showSocial = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Header ──
                    HStack {
                        Text(lang.s(.appBrand))
                            .font(.system(size: 26, weight: .light, design: .serif))
                            .foregroundColor(Color(hex: "D4728C"))
                        Spacer()
                    }
                    .padding(.horizontal)

                    // ── Search Bar ──
                    HStack {
                        Image(systemName: viewModel.isSearching ? "arrow.trianglehead.2.clockwise" : "magnifyingglass")
                            .foregroundColor(Color(hex: "9CA3AF"))
                            .symbolEffect(.rotate, isActive: viewModel.isSearching)
                        TextField("", text: $viewModel.searchText,
                                 prompt: Text(lang.s(.homeSearchPlaceholder))
                                    .foregroundColor(Color(hex: "9CA3AF")))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .autocorrectionDisabled()
                            .focused($isSearchFocused)
                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                                isSearchFocused = false
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
                    .padding(.horizontal)

                    // ── Arama Sonuçları ──
                    if !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        SearchResultsPanel(viewModel: viewModel)
                    } else {

                        // ── Scan Your Shelf Card (Hero) ──
                        ZStack(alignment: .leading) {
                            Image("scan_shelf_background")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(LinearGradient(
                                            colors: [Color.black.opacity(0.6), Color.clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                )
                                .allowsHitTesting(false)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(lang.s(.homeScanBadge))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "D4728C"))
                                    .cornerRadius(6)

                                Text(lang.s(.homeScanTitle))
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)

                                Text(lang.s(.homeScanDesc))
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(2)

                                NavigationLink(destination: ScanView()) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "viewfinder")
                                            .font(.system(size: 14))
                                        Text(lang.s(.homeScanNow))
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

                        // ── Most Searched ──
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(lang.s(.homeMostSearched))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                Spacer()
                                if viewModel.isLoadingPopular {
                                    ProgressView().scaleEffect(0.7).tint(Color(hex: "D4728C"))
                                }
                            }
                            .padding(.horizontal)

                            if viewModel.popularProducts.isEmpty && !viewModel.isLoadingPopular {
                                Text(lang.s(.homeNoData))
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "9CA3AF"))
                                    .padding(.horizontal)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(viewModel.popularProducts) { item in
                                            Button {
                                                viewModel.handleProductTap(isPremium: subscriptionService.isPremium)
                                                Task {
                                                    await viewModel.addToHistory(
                                                        query: item.productName ?? "",
                                                        productId: item.productId,
                                                        productName: item.productName,
                                                        category: nil,
                                                        imageUrl: item.resolvedImageUrl
                                                    )
                                                }
                                                selectedPopularProductId = item.productId
                                            } label: {
                                                PopularProductCard(item: item)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .navigationDestination(isPresented: Binding(
                            get: { selectedPopularProductId != nil },
                            set: { if !$0 { selectedPopularProductId = nil } }
                        )) {
                            if let productId = selectedPopularProductId {
                                ProductDetailView(productId: productId)
                            }
                        }

                        // ── Quick Action Cards ──
                        Text(lang.s(.homeDiscoverTitle))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            Button { showQuiz = true } label: {
                                QuickActionCard(
                                    backgroundImage: "quiz_card_background",
                                    title: lang.s(.quizDiscoverButton),
                                    subtitle: lang.s(.homeQuizCardSubtitle)
                                )
                            }
                            .buttonStyle(.plain)
                            .sheet(isPresented: $showQuiz) {
                                SkinTypeQuizView()
                                    .environmentObject(authViewModel)
                                    .environmentObject(lang)
                            }

                            NavigationLink(destination: RoutineCreateView(onCreated: {})) {
                                QuickActionCard(
                                    backgroundImage: "routine_card_background",
                                    title: lang.s(.homeRoutineCardTitle),
                                    subtitle: lang.s(.homeRoutineCardSubtitle)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)

                        // ── Search History ──
                        if !viewModel.searchHistory.isEmpty || viewModel.isLoadingHistory {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text(lang.s(.homeRecentSearches))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color(hex: "1A1A2E"))
                                    Spacer()
                                    if viewModel.isLoadingHistory {
                                        ProgressView().scaleEffect(0.7).tint(Color(hex: "D4728C"))
                                    } else if !viewModel.searchHistory.isEmpty {
                                        Button {
                                            Task { await viewModel.clearHistory() }
                                        } label: {
                                            Text(lang.s(.homeClearAll))
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(Color(hex: "EF4444"))
                                        }
                                    }
                                }
                                .padding(.horizontal)

                                LazyVStack(spacing: 8) {
                                    ForEach(viewModel.searchHistory) { item in
                                        Button(action: {
                                            if let pid = item.productId, !pid.isEmpty {
                                                viewModel.handleProductTap(isPremium: subscriptionService.isPremium)
                                                selectedPopularProductId = pid
                                            }
                                        }) {
                                            HistoryRow(item: item) {
                                                Task { await viewModel.deleteHistoryItem(id: item.id) }
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                    } // end else (search empty)

                    Spacer().frame(height: 80)
                }
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color(hex: "FFF0F0"))
            .onChange(of: viewModel.searchText) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isSearchFocused = false
                }
            }
            .navigationBarHidden(true)
        }
        .onTapGesture { hideKeyboard() }
    }
}

// MARK: - Quick Action Card

private struct QuickActionCard: View {
    let backgroundImage: String
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(backgroundImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [Color.black.opacity(0.6), Color.clear],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }
}

// MARK: - Popular Product Card

private struct PopularProductCard: View {
    let item: PopularProductResponse
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedImageView(url: URL(string: item.resolvedImageUrl ?? ""), placeholderIcon: "drop.fill")
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(item.productName ?? lang.s(.productDefault))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "1A1A2E"))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 110)
        .padding(10)
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
            // Ürün görseli veya ikon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "F3F4F6"))
                    .frame(width: 48, height: 48)
                CachedImageView(url: URL(string: item.resolvedImageUrl ?? ""), placeholderIcon: "magnifyingglass", placeholderIconSize: 18)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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

            // Silme butonu
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

// MARK: - Product Card (legacy, kept for reference)

struct ProductCard: View {
    let name: String
    let brand: String
    let rating: Double
    let badge: String
    let badgeColor: Color
    let iconName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "F3F4F6"))
                    .frame(height: 140)

                Image(systemName: iconName)
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "D4728C").opacity(0.4))

                VStack {
                    HStack {
                        Spacer()
                        Button { } label: {
                            Image(systemName: "heart")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "D4728C"))
                                .padding(8)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.05), radius: 2)
                        }
                    }
                    Spacer()
                }
                .padding(8)
            }

            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "1A1A2E"))
                .lineLimit(1)

            Text(brand)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "9CA3AF"))

            HStack {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "F59E0B"))
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
                Spacer()
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(badgeColor)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

// MARK: - Search Results Panel

private struct SearchResultsPanel: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var selectedProductId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if viewModel.isSearching {
                    ProgressView().scaleEffect(0.8).tint(Color(hex: "D4728C"))
                    Text(lang.s(.homeSearching))
                        .font(.caption.bold())
                        .foregroundColor(Color(hex: "9CA3AF"))
                } else {
                    Text(viewModel.searchResults.isEmpty
                         ? lang.s(.homeNoResults)
                         : "\(viewModel.searchResults.count) \(lang.s(.searchProductsFound))")
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
                        Text("'\(viewModel.searchText)' \(lang.s(.noProductsForQuery))")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    VStack(spacing: 10) {
                        ForEach(viewModel.searchResults) { product in
                            Button {
                                viewModel.handleProductTap(isPremium: subscriptionService.isPremium)
                                Task {
                                    await viewModel.addToHistory(
                                        query: viewModel.searchText,
                                        productId: product.id,
                                        productName: product.name,
                                        category: product.brand,
                                        imageUrl: product.firstImageUrl
                                    )
                                }
                                selectedProductId = product.id
                            } label: {
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
        .navigationDestination(isPresented: Binding(
            get: { selectedProductId != nil },
            set: { if !$0 { selectedProductId = nil } }
        )) {
            if let productId = selectedProductId {
                ProductDetailView(productId: productId)
            }
        }
    }
}

// MARK: - Home Product Row

private struct HomeProductRow: View {
    let product: Product
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        HStack(spacing: 12) {
            CachedImageView(url: URL(string: product.firstImageUrl ?? ""), placeholderIconSize: 22)
            .frame(width: 60, height: 60)
            .background(Color(hex: "F3F4F6"))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name ?? lang.s(.productUnnamed))
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
                        Text("\(count) \(lang.s(.productIngredientCount))")
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
        .environmentObject(LanguageManager.shared)
}
