import SwiftUI

// MARK: - ViewModel

@MainActor
class FavoritesViewModel: ObservableObject {
    @Published var favorites: [FavoriteResponse] = []
    @Published var isLoading: Bool = false

    func fetchFavorites() async {
        isLoading = true
        do {
            favorites = try await APIClient.shared.getFavorites()
        } catch {
            print("Favorites fetch error: \(error)")
        }
        isLoading = false
    }

    func removeFavorite(productId: String) async {
        do {
            _ = try await APIClient.shared.removeFavorite(productId: productId)
            favorites.removeAll { $0.productId == productId }
        } catch {
            print("Remove favorite error: \(error)")
        }
    }
}

// MARK: - FavoritesView

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @State private var selectedProductId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF5F5").ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Tab bar (sadece All Products) ──
                    HStack(spacing: 0) {
                        VStack(spacing: 6) {
                            Text("All Products")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "D4728C"))
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(hex: "D4728C"))
                                .frame(height: 3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    // ── Content ──
                    if viewModel.isLoading && viewModel.favorites.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(Color(hex: "D4728C"))
                            Text("Loading...")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "9CA3AF"))
                        }
                        Spacer()
                    } else if viewModel.favorites.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 56))
                                .foregroundColor(Color(hex: "D4728C").opacity(0.25))
                            Text("No favorites yet")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A2E"))
                            Text("Products you favorite will appear here")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "9CA3AF"))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.favorites) { fav in
                                    FavoriteCard(favorite: fav) {
                                        Task { await viewModel.removeFavorite(productId: fav.productId) }
                                    }
                                    .onTapGesture {
                                        selectedProductId = fav.productId
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("My Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $selectedProductId) { productId in
                NavigationStack {
                    ProductDetailView(productId: productId)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    selectedProductId = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "1A1A2E"))
                                }
                            }
                        }
                }
            }
            .task {
                await viewModel.fetchFavorites()
            }
        }
    }
}

// MARK: - Favorite Card

private struct FavoriteCard: View {
    let favorite: FavoriteResponse
    let onRemove: () -> Void

    /// Badge bilgisi – category yoksa CLEAN default
    private var badgeInfo: (text: String, color: Color) {
        // Backend'den category bilgisi gelmediğinden varsayılan CLEAN
        return ("CLEAN", Color(hex: "10B981"))
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sol taraf: Badge + isim + brand + Remove
            VStack(alignment: .leading, spacing: 8) {
                // Badge
                Text(badgeInfo.text)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(badgeInfo.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeInfo.color.opacity(0.12))
                    .cornerRadius(6)

                // Ürün adı
                Text(favorite.productName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                    .lineLimit(2)

                // Marka
                if let brand = favorite.productBrand, !brand.isEmpty {
                    Text(brand)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "6B7280"))
                }

                Spacer(minLength: 8)

                // Remove butonu
                Button {
                    onRemove()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.slash.fill")
                            .font(.system(size: 13))
                        Text("Remove")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "D4728C"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "D4728C").opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding(.leading, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Sağ taraf: Ürün fotoğrafı
                let imageStr = favorite.resolvedImageUrl
                if let imageStr = imageStr, let url = URL(string: imageStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        productPlaceholder
                    case .empty:
                        ProgressView()
                            .tint(Color(hex: "D4728C"))
                    @unknown default:
                        productPlaceholder
                    }
                }
                .frame(width: 130, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.trailing, 14)
                .padding(.vertical, 14)
            } else {
                productPlaceholder
                    .frame(width: 130, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.trailing, 14)
                    .padding(.vertical, 14)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "D4728C").opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var productPlaceholder: some View {
        ZStack {
            Color(hex: "FFF0F0")
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundColor(Color(hex: "D4728C").opacity(0.3))
        }
    }
}

#Preview {
    FavoritesView()
}
