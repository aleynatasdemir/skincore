import SwiftUI
import PhotosUI

@MainActor
class RoutineCreateViewModel: ObservableObject {
    enum RoutineType: String, CaseIterable, Identifiable {
        case morning
        case evening

        var id: String { rawValue }
        var title: String { self == .morning ? "Sabah Rutini" : "Akşam Rutini" }
        var apiValue: String { rawValue }
    }

    @Published var routineType: RoutineType = .morning
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var searchQuery: String = ""
    @Published var searchResults: [Product] = []
    @Published var popularProducts: [PopularProductResponse] = []
    @Published var selectedProducts: [RoutineProductRequest] = []
    @Published var isSaving = false
    @Published var isSearching = false
    @Published var selectedItem: PhotosPickerItem? = nil {
        didSet { Task { await handleImageSelection() } }
    }
    @Published var selectedImage: UIImage? = nil
    @Published var uploadedImageUrl: String? = nil

    private var searchTask: Task<Void, Never>?

    func loadPopular() async {
        do {
            popularProducts = try await APIClient.shared.getPopularProducts(limit: 8)
        } catch {
            print("Popular fetch error: \(error)")
        }
    }

    func updateSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await search(query: trimmed)
        }
    }

    private func search(query: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await APIClient.shared.searchProductsByName(query: query, maxResults: 8)
        } catch {
            print("Search error: \(error)")
        }
    }

    func addProduct(product: RoutineProductRequest) {
        if selectedProducts.contains(where: { $0.productId == product.productId }) { return }
        selectedProducts.append(product)
    }

    func removeProduct(productId: String) {
        selectedProducts.removeAll { $0.productId == productId }
    }

    private func handleImageSelection() async {
        guard let selectedItem = selectedItem else { return }
        if let data = try? await selectedItem.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            selectedImage = uiImage
        }
    }

    func createRoutine() async -> Bool {
        isSaving = true
        defer { isSaving = false }

        // 1. Upload image if selected
        if let image = selectedImage, let data = image.jpegData(compressionQuality: 0.8) {
            do {
                uploadedImageUrl = try await APIClient.shared.uploadImage(data: data)
            } catch {
                print("Image upload error: \(error)")
                // Devam etmeli miyiz? Kullanıcı foto yükleyemezse hata versin mi? 
                // Şimdilik hata vermesin, fotosuz devam etsin.
            }
        }

        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let routineTitle = finalTitle.isEmpty ? routineType.title : finalTitle
        let finalDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        let req = CreateRoutineRequest(
            title: routineTitle,
            description: finalDescription.isEmpty ? nil : finalDescription,
            skinType: nil,
            focus: nil,
            routineType: routineType.apiValue,
            tags: nil,
            coverImageUrl: uploadedImageUrl, // Use the uploaded URL or nil
            products: selectedProducts
        )

        do {
            _ = try await APIClient.shared.createRoutine(req)
            return true
        } catch {
            print("Create routine error: \(error)")
            return false
        }
    }
}

struct RoutineCreateView: View {
    var onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var lang: LanguageManager
    @StateObject private var viewModel = RoutineCreateViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker("", selection: $viewModel.routineType) {
                            Text(lang.s(.routineMorning)).tag(RoutineCreateViewModel.RoutineType.morning)
                            Text(lang.s(.routineEvening)).tag(RoutineCreateViewModel.RoutineType.evening)
                        }
                        .pickerStyle(.segmented)
                        .tint(Color(hex: "D4728C"))
                        .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 10) {
                            TextField(lang.s(.routineNamePlaceholder), text: $viewModel.title)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(Color.white)
                                .cornerRadius(14)

                            TextEditor(text: $viewModel.description)
                                .frame(minHeight: 90)
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(hex: "F3D5DC"), lineWidth: 1)
                                )
                                .overlay(
                                    Group {
                                        if viewModel.description.isEmpty {
                                            Text(lang.s(.routineDescPlaceholder))
                                                .foregroundColor(Color(hex: "9CA3AF"))
                                                .font(.system(size: 14))
                                                .padding(.horizontal, 16)
                                                .padding(.top, 18)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                )
                        }

                        // Photo Picker Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text(lang.s(.routinePhotoOptional))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .tracking(1)
                            
                            PhotosPicker(selection: $viewModel.selectedItem, matching: .images) {
                                if let image = viewModel.selectedImage {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                        
                                        Button {
                                            viewModel.selectedImage = nil
                                            viewModel.selectedItem = nil
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white)
                                                .padding(8)
                                        }
                                    }
                                } else {
                                    VStack(spacing: 12) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(Color(hex: "D4728C"))
                                        Text(lang.s(.routineAddPhoto))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: "1A1A2E"))
                                        Text(lang.s(.routineShareJourney))
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "9CA3AF"))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 32)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(hex: "F3D5DC"), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    )
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color(hex: "D4728C"))
                                TextField(lang.s(.routineSearchProduct), text: $viewModel.searchQuery)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .onChange(of: viewModel.searchQuery) { _, newValue in viewModel.updateSearch(newValue) }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: "F3D5DC"), lineWidth: 1)
                            )

                            if viewModel.isSearching {
                                HStack {
                                    ProgressView()
                                        .tint(Color(hex: "D4728C"))
                                    Text(lang.s(.routineSearching))
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "9CA3AF"))
                                }
                            }
                        }

                        if !viewModel.searchResults.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(lang.s(.routineSearchResults))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "9CA3AF"))

                                ForEach(viewModel.searchResults) { product in
                                    RoutineProductPickerRow(
                                        name: product.name ?? "-",
                                        brand: product.brand,
                                        imageUrl: product.firstImageUrl,
                                        actionTitle: lang.s(.routineAdd),
                                        actionColor: Color(hex: "D4728C")
                                    ) {
                                        let item = RoutineProductRequest(
                                            productId: product.id,
                                            name: product.name ?? "-",
                                            brand: product.brand,
                                            imageUrl: product.firstImageUrl
                                        )
                                        viewModel.addProduct(product: item)
                                    }
                                }
                            }
                        } else if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(lang.s(.routineNoResults))
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "9CA3AF"))
                        } else if !viewModel.popularProducts.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(lang.s(.routinePopularProducts))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "9CA3AF"))

                                ForEach(viewModel.popularProducts) { product in
                                    RoutineProductPickerRow(
                                        name: product.productName ?? lang.s(.productDefault),
                                        brand: nil,
                                        imageUrl: product.resolvedImageUrl,
                                        actionTitle: lang.s(.routineAdd),
                                        actionColor: Color(hex: "D4728C")
                                    ) {
                                        let item = RoutineProductRequest(
                                            productId: product.productId,
                                            name: product.productName ?? "-",
                                            brand: nil,
                                            imageUrl: product.resolvedImageUrl
                                        )
                                        viewModel.addProduct(product: item)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(lang.s(.routineSelectedProducts))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                Spacer()
                                Text("\(viewModel.selectedProducts.count) \(lang.s(.routineProductCount))")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "9CA3AF"))
                            }

                            if viewModel.selectedProducts.isEmpty {
                                Text(lang.s(.routineNoProducts))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "9CA3AF"))
                            } else {
                                ForEach(viewModel.selectedProducts, id: \.productId) { product in
                                    RoutineProductPickerRow(
                                        name: product.name,
                                        brand: product.brand,
                                        imageUrl: product.imageUrl,
                                        actionTitle: lang.s(.routineRemove),
                                        actionColor: Color(hex: "9CA3AF")
                                    ) {
                                        viewModel.removeProduct(productId: product.productId)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle(lang.s(.routineTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color(hex: "1A1A2E"))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task {
                        let success = await viewModel.createRoutine()
                        if success {
                            onCreated()
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(viewModel.isSaving ? lang.s(.loading) : lang.s(.save))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.selectedProducts.isEmpty ? Color(hex: "E5E7EB") : Color(hex: "D4728C"))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
                .disabled(viewModel.selectedProducts.isEmpty || viewModel.isSaving)
                .padding(.vertical, 10)
                .background(Color(hex: "FFF0F0").ignoresSafeArea())
            }
            .task {
                await viewModel.loadPopular()
            }
        }
    }
}

private struct RoutineProductPickerRow: View {
    let name: String
    let brand: String?
    let imageUrl: String?
    let actionTitle: String
    let actionColor: Color
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: imageUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                default:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "F3F4F6"))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(Color(hex: "CBD5E1"))
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                if let brand = brand, !brand.isEmpty {
                    Text(brand)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "6B7280"))
                }
            }

            Spacer()

            Button(action: onAction) {
                Text(actionTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(actionColor.opacity(0.15))
                    .foregroundColor(actionColor)
                    .cornerRadius(12)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    RoutineCreateView {
        print("Created")
    }
}
