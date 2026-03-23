import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
class IngredientAnalysisViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedCategoryTitle: String? = nil
    @Published var ingredients: [MatchedIngredient] = []
    @Published var isLoading: Bool = false
    @Published var currentPage: Int = 1
    @Published var hasMore: Bool = true
    
    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategoryTitle != nil
    }

    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 30

    init() {
        $searchText
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self else { return }
                // Eğer arama metni girildiyse kategori seçimini sıfırla
                if !text.isEmpty {
                    self.selectedCategoryTitle = nil
                }
                Task { await self.resetAndFetch() }
            }
            .store(in: &cancellables)

        // İlk yükleme
        Task { await fetchIngredients() }
    }

    func selectCategory(_ category: String) {
        // Eğer zaten seçiliyse kaldırma opsiyonu (toggle)
        if selectedCategoryTitle == category {
            selectedCategoryTitle = nil
        } else {
            selectedCategoryTitle = category
            searchText = "" // Aramayı temizle
        }
        Task { await resetAndFetch() }
    }

    func clearSearch() {
        searchText = ""
        selectedCategoryTitle = nil
        Task { await resetAndFetch() }
    }

    func resetAndFetch() async {
        currentPage = 1
        hasMore = true
        ingredients = []
        await fetchIngredients()
    }

    func fetchIngredients() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        do {
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let search: String? = trimmed.count >= 2 ? trimmed : nil
            
            var minSafety: Int? = nil
            var maxSafety: Int? = nil
            var comedogenic: Bool? = nil

            if let category = selectedCategoryTitle {
                switch category {
                case "Collagen & Beneficial":
                    minSafety = 0; maxSafety = 0
                case "Safe":
                    minSafety = 1; maxSafety = 1
                case "Risky":
                    minSafety = 4; maxSafety = 4
                case "Comedogenicity":
                    comedogenic = true
                default: break
                }
            }

            // Normal arama veya kategori filtreleme
            let results = try await APIClient.shared.getIngredients(
                search: search,
                page: currentPage,
                pageSize: pageSize,
                minSafety: minSafety,
                maxSafety: maxSafety,
                comedogenic: comedogenic
            )
            
            if currentPage == 1 {
                ingredients = results
            } else {
                ingredients.append(contentsOf: results)
            }
            hasMore = results.count >= pageSize
            currentPage += 1
        } catch {
            print("Ingredients fetch error: \(error)")
        }
        isLoading = false
    }

    func loadMoreIfNeeded(currentItem: MatchedIngredient) {
        guard let lastItem = ingredients.last else { return }
        if lastItem.id == currentItem.id {
            Task { await fetchIngredients() }
        }
    }
}

// MARK: - IngredientAnalysisView

struct IngredientAnalysisView: View {
    @StateObject private var viewModel = IngredientAnalysisViewModel()
    @FocusState private var isSearchFocused: Bool

    private let categories: [IngredientCategoryItem] = [
        IngredientCategoryItem(
            title: "Collagen & Beneficial",
            description: "Ingredients like collagen that are highly beneficial.",
            icon: "sparkles",
            color: Color(hex: "8B5CF6"), // Purple
            backgroundColor: Color(hex: "F3E8FF")
        ),
        IngredientCategoryItem(
            title: "Safe",
            description: "Ingredients with no known risks (Score: 1).",
            icon: "checkmark.seal.fill",
            color: Color(hex: "10B981"), // Green
            backgroundColor: Color(hex: "ECFDF5")
        ),
        IngredientCategoryItem(
            title: "Risky",
            description: "Ingredients to avoid or use with caution (Score: 4).",
            icon: "exclamationmark.triangle.fill",
            color: Color(hex: "EF4444"), // Red
            backgroundColor: Color(hex: "FEF2F2")
        ),
        IngredientCategoryItem(
            title: "Comedogenicity",
            description: "Ingredients likely to clog pores.",
            icon: "square.grid.2x2.fill", 
            color: Color(hex: "EC4899"), // Pink
            backgroundColor: Color(hex: "FDF2F8")
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()

                VStack(spacing: 0) {
                    
                    if !viewModel.isSearching {
                        // Landing Header
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                // Başlık Alanı
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Discover what's inside,\nprotect your skin.")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(Color(hex: "1A1A2E"))
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    // Search Bar (Landing)
                                    HStack(spacing: 12) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 18))
                                            .foregroundColor(Color(hex: "6B7280"))
                                        TextField("Search ingredients (e.g. Retinol)", text: $viewModel.searchText)
                                            .focused($isSearchFocused)
                                            .foregroundColor(Color(hex: "1A1A2E"))
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.6))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                    )
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                                // Kategoriler Başlığı
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Ingredient Categories")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color(hex: "1A1A2E"))
                                    Text("Understand the safety profile of your products")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "6B7280"))
                                }
                                .padding(.horizontal, 20)

                                // Kategori Listesi
                                VStack(spacing: 16) {
                                    ForEach(categories) { category in
                                        Button {
                                            viewModel.selectCategory(category.title)
                                        } label: {
                                            CategoryRowView(category: category)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 40)
                            }
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        // Arama Sonuçları Görünümü
                        VStack(spacing: 0) {
                            // Sticky Search Bar
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color(hex: "9CA3AF"))
                                TextField(viewModel.selectedCategoryTitle ?? "Search ingredients...", text: $viewModel.searchText)
                                    .focused($isSearchFocused)
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                    .autocorrectionDisabled()
                                
                                if !viewModel.searchText.isEmpty || viewModel.selectedCategoryTitle != nil {
                                    Button {
                                        viewModel.clearSearch()
                                        isSearchFocused = false
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color(hex: "9CA3AF"))
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "E5E7EB"), lineWidth: 1))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            // Seçili Kategori Başlığı (Opsiyonel)
                            if let category = viewModel.selectedCategoryTitle {
                                HStack {
                                    Text("Filtering by: ")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                    Text(category)
                                        .foregroundColor(Color(hex: "1A1A2E"))
                                        .font(.system(size: 14, weight: .bold))
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                            }
                            
                            // Sonuç Listesi
                            if viewModel.isLoading && viewModel.ingredients.isEmpty {
                                Spacer()
                                ProgressView()
                                Spacer()
                            } else if viewModel.ingredients.isEmpty {
                                Spacer()
                                Text("No ingredients found")
                                    .foregroundColor(.gray)
                                Spacer()
                            } else {
                                List {
                                    ForEach(viewModel.ingredients) { ingredient in
                                        IngredientCard(ingredient: ingredient)
                                            .listRowInsets(EdgeInsets())
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(Color.clear)
                                            .onAppear {
                                                viewModel.loadMoreIfNeeded(currentItem: ingredient)
                                            }
                                    }
                                }
                                .listStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if viewModel.isSearching {
                        Text("Results")
                            .font(.headline)
                            .foregroundColor(Color(hex: "1A1A2E"))
                    } else {
                        Text("Ingredient Analysis")
                            .font(.headline)
                            .foregroundColor(Color(hex: "1A1A2E"))
                    }
                }
            }
        }
    }
}

// MARK: - Subviews & Models

struct IngredientCategoryItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let backgroundColor: Color
}

struct CategoryRowView: View {
    let category: IngredientCategoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(category.backgroundColor)
                    .frame(width: 48, height: 48)
                Image(systemName: category.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                Text(category.description)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "6B7280"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "D1D5DB"))
                .padding(.top, 16)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Ingredient Card

private struct IngredientCard: View {
    let ingredient: MatchedIngredient
    @State private var isExpanded: Bool = false

    private var badgeInfo: (text: String, color: Color) {
        switch ingredient.resolvedSafetyLevel {
        case 1:  return ("SAFE", Color(hex: "10B981"))
        case 2:  return ("MODERATE", Color(hex: "F59E0B"))
        case 3:  return ("AVOID", Color(hex: "EF4444"))
        default: return ("UNKNOWN", Color(hex: "9CA3AF"))
        }
    }

    private var functionText: String? {
        guard let funcs = ingredient.functions, let first = funcs.first, let name = first.name else {
            return nil
        }
        return "FUNCTION: \(name.uppercased())"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Üst satır: İsim + Badge
            HStack(alignment: .top) {
                Text(ingredient.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))

                Spacer()

                Text(badgeInfo.text)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(badgeInfo.color)
                    .cornerRadius(8)
            }

            // Function satırı
            if let fn = functionText {
                Text(fn)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "10B981"))
                    .tracking(0.5)
            }

            // Açıklama
            if let desc = ingredient.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "4B5563"))
                    .lineSpacing(3)
                    .lineLimit(isExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        }
    }
}

#Preview {
    IngredientAnalysisView()
}
