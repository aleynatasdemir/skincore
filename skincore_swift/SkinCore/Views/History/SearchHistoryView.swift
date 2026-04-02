import SwiftUI

// MARK: - ViewModel

@MainActor
class SearchHistoryViewModel: ObservableObject {
    @Published var historyItems: [SearchHistoryResponse] = []
    @Published var isLoading: Bool = false

    func fetchHistory() async {
        isLoading = true
        do {
            historyItems = try await APIClient.shared.getSearchHistory(limit: 30)
        } catch {
            print("History fetch error: \(error)")
        }
        isLoading = false
    }

    func deleteItem(id: String) async {
        do {
            _ = try await APIClient.shared.deleteSearchHistoryItem(itemId: id)
            historyItems.removeAll { $0.id == id }
        } catch {
            print("Delete history item error: \(error)")
        }
    }

    func clearAll() async {
        do {
            _ = try await APIClient.shared.clearSearchHistory()
            historyItems = []
        } catch {
            print("Clear history error: \(error)")
        }
    }
}

// MARK: - SearchHistoryView

struct SearchHistoryView: View {
    @StateObject private var viewModel = SearchHistoryViewModel()
    @EnvironmentObject var lang: LanguageManager
    @State private var selectedProductId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()

                if viewModel.isLoading && viewModel.historyItems.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color(hex: "D4728C"))
                        Text(lang.s(.loading))
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                } else if viewModel.historyItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.counterclockwise")
                            .font(.system(size: 56))
                            .foregroundColor(Color(hex: "D4728C").opacity(0.25))
                        Text(lang.s(.historyEmpty))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1A2E"))
                        Text(lang.s(.historyEmptySubtitle))
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.historyItems) { item in
                                Button(action: {
                                    if let pid = item.productId, !pid.isEmpty {
                                        selectedProductId = pid
                                    }
                                }) {
                                    HistoryCard(item: item) {
                                        Task { await viewModel.deleteItem(id: item.id) }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle(lang.s(.historyTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.historyItems.isEmpty {
                        Button {
                            Task { await viewModel.clearAll() }
                        } label: {
                            Text(lang.s(.historyClearAll))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "D4728C"))
                        }
                    }
                }
            }
            .fullScreenCover(item: $selectedProductId) { productId in
                NavigationStack {
                    ProductDetailView(productId: productId)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    selectedProductId = nil
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "1A1A2E"))
                                }
                            }
                        }
                }
            }
            .task {
                await viewModel.fetchHistory()
            }
        }
    }
}

// MARK: - History Card

private struct HistoryCard: View {
    let item: SearchHistoryResponse
    let onDelete: () -> Void
    @EnvironmentObject var lang: LanguageManager

    private var badge: (text: String, color: Color)? {
        guard let category = item.category?.lowercased(), !category.isEmpty else { return nil }
        switch category {
        case let c where c.contains("clean") || c.contains("temiz"):
            return (lang.s(.badgeClean), Color(hex: "10B981"))
        case let c where c.contains("safe") || c.contains("güvenli"):
            return (lang.s(.badgeSafe), Color(hex: "3B82F6"))
        case let c where c.contains("alert") || c.contains("dikkat") || c.contains("uyarı"):
            return (lang.s(.badgeAlert), Color(hex: "EF4444"))
        default:
            return nil
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sol taraf: badge + isim + marka
            VStack(alignment: .leading, spacing: 6) {
                if let badge = badge {
                    Text(badge.text)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(badge.color)
                        .cornerRadius(6)
                }

                Text(item.productName ?? item.query)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                    .lineLimit(2)

                if let category = item.category, !category.isEmpty {
                    Text(category)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.vertical, 18)

            // Ürün görseli
            AsyncImage(url: URL(string: item.resolvedImageUrl ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                default:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "F3F4F6"))
                        .frame(width: 90, height: 90)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "CBD5E1"))
                        )
                }
            }
            .padding(.trailing, 8)

            // Silme butonu
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "D4728C"))
                    .frame(width: 32, height: 32)
            }
            .padding(.trailing, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    SearchHistoryView()
}
