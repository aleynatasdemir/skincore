import SwiftUI
import Vision
import UIKit

// MARK: - ScanView

struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()

                VStack(spacing: 0) {

                    // Çekilen fotoğraf önizlemesi
                    if let image = viewModel.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    } else {
                        // Kamera butonu — iki seçenekli
                        Button {
                            viewModel.showSourcePicker = true
                        } label: {
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "D4728C").opacity(0.12))
                                        .frame(width: 88, height: 88)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(Color(hex: "D4728C"))
                                }
                                Text("Fotoğraf Çek")
                                    .font(.title3.bold())
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                Text("Ürün etiketini çek, Vision tüm yazıları okusun")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(Color(hex: "9CA3AF"))
                                    .padding(.horizontal, 32)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color(hex: "D4728C").opacity(0.3),
                                                  style: StrokeStyle(lineWidth: 2, dash: [8]))
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        }
                    }

                    // Durum satırı
                    if viewModel.isProcessing {
                        HStack(spacing: 10) {
                            ProgressView().scaleEffect(0.85)
                            Text("Yazılar okunuyor…")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "1A1A2E"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    } else if viewModel.isSearching {
                        HStack(spacing: 10) {
                            ProgressView().scaleEffect(0.85)
                            if let text = viewModel.detectedText {
                                Text("\"\(text)\" aranıyor…")
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    } else if let text = viewModel.detectedText, !text.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "text.viewfinder")
                                .foregroundColor(Color(hex: "D4728C"))
                            Text(text)
                                .font(.caption.bold())
                                .lineLimit(1)
                                .foregroundColor(Color(hex: "1A1A2E"))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    // Arama sonuçları
                    if !viewModel.searchResults.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.searchResults) { product in
                                    NavigationLink(destination: ProductDetailView(productId: product.id)) {
                                        ProductResultCard(product: product)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                    } else if viewModel.hasSearched && !viewModel.isSearching {
                        // OCR bir şey okuduysa ama eşleşme bulamadıysa satırları göster
                        ScrollView {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 36))
                                    .foregroundColor(Color(hex: "D4728C").opacity(0.4))
                                Text("Ürün bulunamadı")
                                    .font(.subheadline.bold())
                                    .foregroundColor(Color(hex: "1A1A2E"))

                                if !viewModel.allOcrLines.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("OCR okunan satırlar")
                                                .font(.caption.bold())
                                                .foregroundColor(Color(hex: "9CA3AF"))
                                            Spacer()
                                            Text("Birini seç")
                                                .font(.caption)
                                                .foregroundColor(Color(hex: "D4728C"))
                                        }
                                        ForEach(viewModel.allOcrLines, id: \.self) { line in
                                            Button {
                                                Task { await viewModel.search(query: line) }
                                            } label: {
                                                HStack {
                                                    Text(line)
                                                        .font(.caption)
                                                        .foregroundColor(Color(hex: "1A1A2E"))
                                                        .multilineTextAlignment(.leading)
                                                    Spacer()
                                                    Image(systemName: "magnifyingglass")
                                                        .font(.caption2)
                                                        .foregroundColor(Color(hex: "D4728C"))
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color(hex: "FFF0F0"))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                } else {
                                    Text("OCR hiç metin okuyamadı — daha net bir fotoğraf çek")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(Color(hex: "9CA3AF"))
                                        .padding(.horizontal, 32)
                                }

                                Button("Tekrar Çek") { viewModel.reset() }
                                    .font(.subheadline.bold())
                                    .foregroundColor(Color(hex: "D4728C"))
                                    .padding(.top, 4)
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                        }
                    } else {
                        Spacer()
                    }
                }
            }
            .navigationTitle("Tara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.capturedImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { viewModel.reset() } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(Color(hex: "D4728C"))
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCamera) {
                CameraPickerView(sourceType: viewModel.pickerSourceType) { image in
                    viewModel.showCamera = false
                    viewModel.processImage(image)
                }
                .ignoresSafeArea()
            }
            .confirmationDialog("Fotoğraf Seç", isPresented: $viewModel.showSourcePicker, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Kamera") {
                        viewModel.pickerSourceType = .camera
                        viewModel.showCamera = true
                    }
                }
                Button("Galeri") {
                    viewModel.pickerSourceType = .photoLibrary
                    viewModel.showCamera = true
                }
                Button("İptal", role: .cancel) {}
            }
            .alert("Kamera İzni Gerekli", isPresented: $viewModel.showPermissionAlert) {
                Button("Ayarları Aç") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Ürün taramak için kamera iznine ihtiyaç var.")
            }
        }
    }
}

// MARK: - ScanViewModel

@MainActor
class ScanViewModel: ObservableObject {
    @Published var capturedImage: UIImage? = nil
    @Published var detectedText: String? = nil
    @Published var allOcrLines: [String] = []
    @Published var searchResults: [Product] = []
    @Published var isProcessing: Bool = false
    @Published var isSearching: Bool = false
    @Published var hasSearched: Bool = false
    @Published var showCamera: Bool = false
    @Published var showSourcePicker: Bool = false
    @Published var pickerSourceType: UIImagePickerController.SourceType = .camera
    @Published var showPermissionAlert: Bool = false
    @Published var showOcrDebug: Bool = false

    // Fotoğraf çekildikten sonra Vision OCR → API search
    func processImage(_ image: UIImage) {
        capturedImage = image
        isProcessing = true
        detectedText = nil
        allOcrLines = []
        searchResults = []
        hasSearched = false

        Task { @MainActor in
            guard let cgImage = image.cgImage else {
                isProcessing = false
                return
            }

            let lines = await recognizeText(from: cgImage)
            allOcrLines = lines
            print("📷 OCR toplam satır: \(lines.count)")
            lines.forEach { print("  → \($0)") }

            isProcessing = false

            // Tüm anlamlı satırları birleştir → tek sorgu
            let query = buildSearchQuery(from: lines)

            guard !query.isEmpty else {
                print("⚠️ OCR: hiç metin okunamadı")
                hasSearched = true
                return
            }

            print("✅ Arama sorgusu: \(query)")
            detectedText = query
            await search(query: query)
        }
    }

    // Tüm OCR satırlarını filtrele ve birleştir
    private func buildSearchQuery(from lines: [String]) -> String {
        let meaningful = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                let len = line.count
                guard len >= 2 && len <= 60 else { return false }
                // Sadece rakam/sembol olan satırları atla (200, ML, %, ® vs)
                let letters = line.filter { $0.isLetter }
                return letters.count >= 2
            }
        // Hepsini boşlukla birleştir, max 80 karakter
        let joined = meaningful.joined(separator: " ")
        return String(joined.prefix(80))
    }

    // Vision OCR — tüm metin satırlarını döner
    private func recognizeText(from cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    print("❌ OCR hatası: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                let observations = req.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["tr-TR", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("❌ VNImageRequestHandler hatası: \(error)")
                continuation.resume(returning: [])
            }
        }
    }

    func search(query: String) async {
        isSearching = true
        do {
            let results = try await APIClient.shared.searchProductsByName(query: query, maxResults: 5)
            searchResults = results
            print("🔍 Arama sonuç: \(results.count) ürün")
        } catch {
            print("❌ Arama hatası: \(error)")
            searchResults = []
        }
        isSearching = false
        hasSearched = true
    }

    func reset() {
        capturedImage = nil
        detectedText = nil
        allOcrLines = []
        searchResults = []
        isProcessing = false
        isSearching = false
        hasSearched = false
        showOcrDebug = false
        showSourcePicker = false
    }
}

// MARK: - CameraPickerView

struct CameraPickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Product Result Card

struct ProductResultCard: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: product.firstImageUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Image(systemName: "photo")
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .frame(width: 56, height: 56)
                }
            }
            .frame(width: 56, height: 56)
            .background(Color(hex: "FFF0F0"))
            .clipShape(RoundedRectangle(cornerRadius: 10))

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
                if let ingredients = product.productIngredients {
                    Text("\(ingredients.count) içerik")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "D4728C"))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(hex: "9CA3AF"))
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Product Detail View

struct ProductDetailView: View {
    let productId: String
    @State private var product: ProductWithEnrichedIngredients? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var selectedFilter: SafetyFilter = .all

    enum SafetyFilter: String, CaseIterable {
        case all      = "Tümü"
        case safe     = "Güvenli"
        case moderate = "Orta"
        case avoid    = "Kaçın"
    }

    // Safety Score: level1=100p, level2=50p, level3=0p
    private func computeSafetyScore(_ items: [IngredientMatchResult]) -> Int {
        let matched = items.filter { $0.matchedIngredient != nil }
        guard !matched.isEmpty else { return 0 }
        let total = matched.reduce(0) { acc, item in
            switch item.matchedIngredient?.resolvedSafetyLevel {
            case 1: return acc + 100
            case 2: return acc + 50
            default: return acc
            }
        }
        return total / matched.count
    }

    private func safetyLabel(for score: Int) -> String {
        if score > 80 { return "Güvenli & Temiz" }
        if score > 50 { return "Dikkatli Kullan" }
        return "Yüksek Risk"
    }

    private func safetyDescription(for score: Int) -> String {
        if score > 80 { return "Bu ürün, tahriş veya toksisite riski düşük kaliteli içerikler barındırıyor." }
        if score > 50 { return "Bu ürün, hassas cilt tipleri için hafif tahriş yapabilecek bazı içerikler içeriyor." }
        return "Bu ürün zararlı olabilecek içerikler barındırıyor. Alternatif ürünleri değerlendirmenizi öneririz."
    }

    private func safetyRingColor(for score: Int) -> Color {
        if score > 80 { return Color(hex: "D4728C") }   // pembe — Safe
        if score > 50 { return Color(hex: "F59E0B") }   // amber — Caution
        return Color(hex: "EF4444")                      // kırmızı — High Risk
    }

    private func filteredIngredients(_ items: [IngredientMatchResult]) -> [IngredientMatchResult] {
        switch selectedFilter {
        case .all:      return items
        case .safe:     return items.filter { $0.matchedIngredient?.resolvedSafetyLevel == 1 }
        case .moderate: return items.filter { $0.matchedIngredient?.resolvedSafetyLevel == 2 }
        case .avoid:    return items.filter { ($0.matchedIngredient?.resolvedSafetyLevel ?? 0) >= 3 }
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F8FC").ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(Color(hex: "D4728C"))
                    Text("Analiz ediliyor…")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "EF4444"))
                    Text(error)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(hex: "6B7280"))
                        .padding(.horizontal, 32)
                }
            } else if let product = product {
                let ingredients = product.enrichedIngredients ?? []
                let score = computeSafetyScore(ingredients)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Hero Image ──────────────────────────────────
                        // Fotoğraf ayrı — üstünde yazı yok
                        ZStack {
                            Color.white
                            if let urlStr = product.firstImageUrl, let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().aspectRatio(contentMode: .fit)
                                    default:
                                        Image(systemName: "photo")
                                            .font(.system(size: 52))
                                            .foregroundColor(Color(hex: "CBD5E1"))
                                    }
                                }
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 52))
                                    .foregroundColor(Color(hex: "CBD5E1"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipped()

                        // ── Ürün Adı + Marka (fotoğrafın altında, beyaz kart) ──
                        VStack(alignment: .leading, spacing: 8) {
                            if let brand = product.brand {
                                Text(brand.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(Color(hex: "D4728C"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "FFF0F0"))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color(hex: "F3C6D1"), lineWidth: 1))
                            }
                            Text(product.name ?? "Ürün")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A2E"))
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 6) {
                                if let count = product.productIngredients?.count {
                                    Text("\(count) İçerik")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "6B7280"))
                                    Circle().fill(Color(hex: "CBD5E1")).frame(width: 3, height: 3)
                                }
                                Text("Vegan & Temiz")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "6B7280"))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.white)

                        // ── Overall Safety Score Card ──────────────────
                        VStack(spacing: 16) {
                            // "GENEL GÜVENLİK SKORU" üst başlık
                            Text("GENEL GÜVENLİK SKORU")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.4)
                                .foregroundColor(Color(hex: "94A3B8"))

                            // Büyük ring — sadece daire, ortada sayı
                            ZStack {
                                // Arka plan halkası
                                Circle()
                                    .stroke(Color(hex: "F1F5F9"), lineWidth: 14)
                                // Dolgu halkası — iki renk geçiş
                                Circle()
                                    .trim(from: 0, to: CGFloat(score) / 100.0)
                                    .stroke(
                                        AngularGradient(
                                            colors: [safetyRingColor(for: score).opacity(0.6),
                                                     safetyRingColor(for: score)],
                                            center: .center
                                        ),
                                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeOut(duration: 1.2), value: score)

                                // Ortadaki yazı
                                VStack(spacing: 2) {
                                    Text("\(score)")
                                        .font(.system(size: 52, weight: .black, design: .rounded))
                                        .foregroundColor(Color(hex: "1A1A2E"))
                                    Text("100 üzerinden")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(hex: "94A3B8"))
                                }
                            }
                            .frame(width: 160, height: 160)
                            .padding(.vertical, 8)

                            // Alt etiket + açıklama
                            VStack(spacing: 8) {
                                Text(safetyLabel(for: score))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A2E"))

                                Text(safetyDescription(for: score))
                                    .font(.system(size: 13))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(Color(hex: "6B7280"))
                                    .lineSpacing(3)
                                    .padding(.horizontal, 24)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .padding(.horizontal, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                        // ── İçerikler Başlık + Filtre ────────────────
                        VStack(alignment: .leading, spacing: 0) {
                            // Section header
                            HStack {
                                Text("İçerikler")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                Text("(\(ingredients.count))")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                Spacer()
                                Button {
                                    // filter action
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Filtrele")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color(hex: "9CA3AF"))
                                        Image(systemName: "line.3.horizontal.decrease")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(hex: "9CA3AF"))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 28)
                            .padding(.bottom, 12)

                            // Filtre pill'leri
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(SafetyFilter.allCases, id: \.self) { filter in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedFilter = filter
                                            }
                                        } label: {
                                            Text(filter.rawValue)
                                                .font(.caption.bold())
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 7)
                                                .background(selectedFilter == filter
                                                    ? Color(hex: "D4728C")
                                                    : Color.white)
                                                .foregroundColor(selectedFilter == filter
                                                    ? .white
                                                    : Color(hex: "6B7280"))
                                                .clipShape(Capsule())
                                                .overlay(
                                                    Capsule()
                                                        .stroke(selectedFilter == filter
                                                            ? Color.clear
                                                            : Color(hex: "E2E8F0"), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.bottom, 16)

                            // Ingredient cards
                            LazyVStack(spacing: 12) {
                                let filtered = filteredIngredients(ingredients)
                                if filtered.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "tray")
                                            .font(.system(size: 32))
                                            .foregroundColor(Color(hex: "CBD5E1"))
                                        Text("Bu kategoride içerik yok")
                                            .font(.subheadline)
                                            .foregroundColor(Color(hex: "94A3B8"))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 32)
                                } else {
                                    ForEach(filtered) { item in
                                        IngredientDetailCard(item: item)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                product = try await APIClient.shared.getProductDetails(id: productId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Safety Stat Badge

private struct SafetyStatBadge: View {
    let count: Int
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(.caption2.bold())
                .foregroundColor(Color(hex: "374151"))
        }
    }
}

// MARK: - Ingredient Detail Card

struct IngredientDetailCard: View {
    let item: IngredientMatchResult

    private var safetyLevel: Int { item.matchedIngredient?.resolvedSafetyLevel ?? 0 }
    private var isMatched: Bool  { item.matchedIngredient != nil }

    private var accentColor: Color {
        switch safetyLevel {
        case 1: return Color(hex: "22C55E")
        case 2: return Color(hex: "F59E0B")
        case 3: return Color(hex: "EF4444")
        default: return Color(hex: "94A3B8")
        }
    }

    private var badgeText: String {
        switch safetyLevel {
        case 1: return "GÜVENLİ"
        case 2: return "ORTA"
        case 3: return "KAÇIN"
        default: return "BİLİNMİYOR"
        }
    }

    private var iconName: String {
        switch safetyLevel {
        case 1: return "checkmark.circle.fill"
        case 2: return "exclamationmark.triangle.fill"
        case 3: return "xmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var displayName: String {
        item.matchedIngredient?.displayName ?? item.originalString?.capitalized ?? "-"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 22))
                    .foregroundColor(accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: "1A1A2E"))
                        .lineLimit(2)

                    if let funcs = item.matchedIngredient?.functions, !funcs.isEmpty {
                        Text(funcs.prefix(3).compactMap { $0.name }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundColor(Color(hex: "94A3B8"))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Safety badge pill
                Text(badgeText)
                    .font(.system(size: 10, weight: .black))
                    .tracking(0.8)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            // Description
            if let desc = item.matchedIngredient?.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(Color(hex: "6B7280"))
                    .lineLimit(3)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
            }

            // EWG score row
            if let ewg = item.matchedIngredient?.ewgScore, !ewg.isEmpty {
                HStack(spacing: 6) {
                    Text("EWG Skoru:")
                        .font(.caption2.bold())
                        .foregroundColor(Color(hex: "94A3B8"))
                    Text(ewg)
                        .font(.caption2.bold())
                        .foregroundColor(accentColor)
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }

            // EU/US limited warning box
            let isLimitedEu = item.matchedIngredient?.limitedEu ?? false
            let isLimitedUs = item.matchedIngredient?.limitedUs ?? false
            if isLimitedEu || isLimitedUs {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "EF4444"))
                    var regions: [String] {
                        var r: [String] = []
                        if isLimitedEu { r.append("AB") }
                        if isLimitedUs { r.append("ABD") }
                        return r
                    }
                    Text("⚠ \(regions.joined(separator: " & "))'de kısıtlı / potansiyel uyarı")
                        .font(.caption2.bold())
                        .foregroundColor(Color(hex: "B91C1C"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "FEE2E2"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }

            Spacer().frame(height: 14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(isMatched ? 0.18 : 0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - (legacy stub — kept for backward compat)
private struct IngredientRow: View {
    let item: IngredientMatchResult
    var body: some View { EmptyView() }
}
