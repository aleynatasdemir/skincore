import SwiftUI
import Combine

// MARK: - Category Model

struct IngredientCategoryItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let backgroundColor: Color
    /// safety_level aralığı (nil = filtre yok)
    let minSafetyLevel: Int?
    let maxSafetyLevel: Int?
    let isComedogenic: Bool

    static func == (lhs: IngredientCategoryItem, rhs: IngredientCategoryItem) -> Bool {
        lhs.title == rhs.title
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }
}

// MARK: - ViewModel

@MainActor
class IngredientAnalysisViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedCategory: IngredientCategoryItem? = nil
    @Published var ingredients: [MatchedIngredient] = []
    @Published var isLoading: Bool = false
    @Published var currentPage: Int = 1
    @Published var hasMore: Bool = true

    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 1000

    init() {
        $searchText
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self else { return }
                if !text.isEmpty { self.selectedCategory = nil }
                Task { await self.resetAndFetch() }
            }
            .store(in: &cancellables)
    }

    func selectCategory(_ category: IngredientCategoryItem) async {
        selectedCategory = category
        searchText = ""
        await resetAndFetch()
    }

    func clearCategory() {
        selectedCategory = nil
        ingredients = []
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

            let results = try await APIClient.shared.getIngredients(
                search: search,
                page: currentPage,
                pageSize: pageSize,
                minSafety: selectedCategory?.minSafetyLevel,
                maxSafety: selectedCategory?.maxSafetyLevel,
                comedogenic: selectedCategory?.isComedogenic == true ? true : nil
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

// MARK: - IngredientAnalysisView (Ekran 1 – Kategori Listesi)

struct IngredientAnalysisView: View {
    @StateObject private var viewModel = IngredientAnalysisViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var navigatingTo: IngredientCategoryItem? = nil

    private let categories: [IngredientCategoryItem] = [
        IngredientCategoryItem(
            title: "Completely Safe",
            description: "Ingredients with no known risks or irritants even for sensitive skin.",
            icon: "shield.fill",
            color: Color(hex: "22C55E"),
            backgroundColor: Color(hex: "DCFCE7"),
            minSafetyLevel: 0,
            maxSafetyLevel: 0,
            isComedogenic: false
        ),
        IngredientCategoryItem(
            title: "Safe",
            description: "Widely used ingredients considered safe for most skin types.",
            icon: "checkmark.seal.fill",
            color: Color(hex: "3B82F6"),
            backgroundColor: Color(hex: "DBEAFE"),
            minSafetyLevel: 1,
            maxSafetyLevel: 1,
            isComedogenic: false
        ),
        IngredientCategoryItem(
            title: "Acceptable",
            description: "Generally safe but may cause mild reaction in rare cases.",
            icon: "info.circle.fill",
            color: Color(hex: "EAB308"),
            backgroundColor: Color(hex: "FEF9C3"),
            minSafetyLevel: 2,
            maxSafetyLevel: 2,
            isComedogenic: false
        ),
        IngredientCategoryItem(
            title: "Moderate Safety",
            description: "Potential for irritation. Use with caution on compromised barriers.",
            icon: "exclamationmark.triangle.fill",
            color: Color(hex: "F97316"),
            backgroundColor: Color(hex: "FFEDD5"),
            minSafetyLevel: 3,
            maxSafetyLevel: 3,
            isComedogenic: false
        ),
        IngredientCategoryItem(
            title: "Risky",
            description: "High risk of irritation or harm. Avoid or use with extreme caution.",
            icon: "xmark.shield.fill",
            color: Color(hex: "EF4444"),
            backgroundColor: Color(hex: "FEE2E2"),
            minSafetyLevel: 4,
            maxSafetyLevel: 4,
            isComedogenic: false
        ),
        IngredientCategoryItem(
            title: "Comedogenicity",
            description: "Likelihood of the ingredient to clog pores and cause breakouts.",
            icon: "square.grid.2x2.fill",
            color: Color(hex: "9CA3AF"),
            backgroundColor: Color(hex: "F3F4F6"),
            minSafetyLevel: nil,
            maxSafetyLevel: nil,
            isComedogenic: true
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FBF3F3").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // Hero Banner
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "F9D6D6"), Color(hex: "FDE8E8")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Discover what's inside,\nprotect your skin.")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                    .fixedSize(horizontal: false, vertical: true)

                                // Search Bar
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "9CA3AF"))
                                    TextField("Search ingredients (e.g. Retinol)", text: $viewModel.searchText)
                                        .focused($isSearchFocused)
                                        .foregroundColor(Color(hex: "1A1A2E"))
                                        .font(.system(size: 15))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(14)
                            }
                            .padding(20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        // Categories Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ingredient Categories")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A2E"))
                            Text("Understand the safety profile of your products")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "6B7280"))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 12)

                        // Category Rows
                        VStack(spacing: 0) {
                            ForEach(categories) { category in
                                Button {
                                    navigatingTo = category
                                } label: {
                                    CategoryRowView(category: category)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Ingredient Analysis")
                        .font(.headline)
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
            }
            .navigationDestination(item: $navigatingTo) { category in
                IngredientListView(category: category)
            }
        }
    }
}

// MARK: - CategoryRowView

struct CategoryRowView: View {
    let category: IngredientCategoryItem

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(category.backgroundColor)
                    .frame(width: 52, height: 52)
                Image(systemName: category.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(category.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                Text(category.description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "D1D5DB"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .overlay(
            Divider()
                .padding(.leading, 82),
            alignment: .bottom
        )
    }
}

// MARK: - IngredientListView (Ekran 2)

struct IngredientListView: View {
    let category: IngredientCategoryItem
    @StateObject private var vm = IngredientAnalysisViewModel()
    @State private var selectedIngredient: MatchedIngredient? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "FBF3F3").ignoresSafeArea()

            VStack(spacing: 0) {
                // Summary Card
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "FFDDE0"))
                            .frame(width: 52, height: 52)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "EC4899"))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        if vm.isLoading && vm.ingredients.isEmpty {
                            Text("Loading...")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A2E"))
                        } else {
                            Text("\(vm.ingredients.count) Ingredients Found")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A2E"))
                        }
                        Text("All components in \(category.title.lowercased()) category.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Section Header
                HStack {
                    Text("SAFE INGREDIENTS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "D4728C"))
                        .tracking(1)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                // List
                if vm.isLoading && vm.ingredients.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(Color(hex: "D4728C"))
                    Spacer()
                } else if vm.ingredients.isEmpty {
                    Spacer()
                    Text("No ingredients found")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.ingredients) { ingredient in
                                IngredientCard(ingredient: ingredient, categoryColor: category.color, categoryBg: category.backgroundColor, categoryIcon: category.icon)
                                    .onTapGesture { 
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                            selectedIngredient = ingredient 
                                        }
                                    }
                                    .onAppear { vm.loadMoreIfNeeded(currentItem: ingredient) }
                            }
                            if vm.isLoading {
                                ProgressView()
                                    .tint(Color(hex: "D4728C"))
                                    .padding()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(category.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text("ANALYSIS RESULT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "D4728C"))
                        .tracking(1)
                }
            }
        }
        .overlay(
            ZStack {
                if let ingredient = selectedIngredient {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedIngredient = nil
                            }
                        }
                        .zIndex(1)
                    
                    IngredientDetailSheet(ingredient: ingredient) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedIngredient = nil
                        }
                    }
                    .padding(.horizontal, 24)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .zIndex(2)
                }
            }
        )
        .task {
            await vm.selectCategory(category)
        }
    }
}

<<<<<<< HEAD
    private var functionText: String? {
        guard let funcs = ingredient.functions, let first = funcs.first else {
            return nil
        }
        return "FUNCTION: \(first.uppercased())"
=======
// MARK: - IngredientCard (Ekran 2 – Liste Elemanı)

struct IngredientCard: View {
    let ingredient: MatchedIngredient
    let categoryColor: Color
    let categoryBg: Color
    let categoryIcon: String


    private var functionLabel: String? {
        guard let funcs = ingredient.functions, let first = funcs.first, let name = first.name, !name.isEmpty else { return nil }
        return name.uppercased()
>>>>>>> cb7449ce (ingredients sayfası düzeltildi)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(categoryBg)
                        .frame(width: 44, height: 44)
                    Image(systemName: categoryIcon)
                        .font(.system(size: 18))
                        .foregroundColor(categoryColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(ingredient.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    if let fn = functionLabel {
                        Text(fn)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "D4728C"))
                            .tracking(0.3)
                    }
                }

                Spacer()


            }

            if let desc = ingredient.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "4B5563"))
                    .lineSpacing(3)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - IngredientDetailSheet (Ekran 3 – Modal)

struct IngredientDetailSheet: View {
    let ingredient: MatchedIngredient
    var onClose: () -> Void

    private var ewgScoreInt: Int? {
        guard let str = ingredient.ewgScore else { return nil }
        return Int(str.prefix(1))
    }

    private var ewgScoreLabel: String {
        guard let score = ewgScoreInt else { return "N/A" }
        switch score {
        case 1...2: return "Low Risk"
        case 3...6: return "Moderate Risk"
        default:    return "High Risk"
        }
    }

    private func ewgCircleColor(for score: String) -> Color {
        guard let value = Int(score.prefix(2)) else { return Color(hex: "22C55E") }
        switch value {
        case 0...4:
            return Color(hex: "22C55E") // Yeşil
        case 5...6:
            return Color(hex: "EAB308") // Sarı
        case 7...10:
            return Color(hex: "EF4444") // Kırmızı
        default:
            return Color(hex: "22C55E")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .padding(8)
                        .background(Color(hex: "F3F4F6"))
                        .clipShape(Circle())
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name + Description
                    VStack(alignment: .leading, spacing: 10) {
                        Text(ingredient.displayName)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A2E"))
                        if let desc = ingredient.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "4B5563"))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Good For
                    if let good = ingredient.goodFor, !good.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("GOOD FOR")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .tracking(1)
                            FlowLayout(items: good) { item in
                                ChipView(text: item, color: Color(hex: "D4728C"), bgColor: Color(hex: "FDF2F8"))
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Bad For
                    if let bad = ingredient.badFor, !bad.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("BAD FOR")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .tracking(1)
                            FlowLayout(items: bad) { item in
                                ChipView(text: item, color: Color(hex: "EF4444"), bgColor: Color(hex: "FEE2E2"))
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // EWG Score
                    if let score = ingredient.ewgScore, !score.isEmpty {
                        Divider().padding(.horizontal, 24)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("EWG SCORE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "9CA3AF"))
                                    .tracking(1)
                                Text("\(score) (\(ewgScoreLabel))")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .stroke(ewgCircleColor(for: score), lineWidth: 2)
                                    .frame(width: 44, height: 44)
                                Text(score.prefix(2))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(ewgCircleColor(for: score))
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            Spacer(minLength: 20)
        }
        .background(Color.white)
        .cornerRadius(28)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 20)
    }
}

// MARK: - ChipView

struct ChipView: View {
    let text: String
    var color: Color = Color(hex: "D4728C")
    var bgColor: Color = Color(hex: "FDF2F8")

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(bgColor)
            .cornerRadius(20)
    }
}

// MARK: - FlowLayout (chip satırları için)

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content
    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in
            generateContent(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element) { _, item in
                content(item)
                    .alignmentGuide(.leading) { d in
                        if (abs(width - d.width) > geo.size.width) {
                            width = 0
                            height -= d.height + 8
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= d.width + 8
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last { height = 0 }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geo -> Color in
            DispatchQueue.main.async { binding.wrappedValue = geo.size.height }
            return .clear
        }
    }
}

// MARK: - Preview

#Preview {
    IngredientAnalysisView()
}
