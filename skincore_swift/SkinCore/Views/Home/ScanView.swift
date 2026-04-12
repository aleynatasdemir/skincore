import SwiftUI
import Vision
import UIKit
import AVFoundation
import Kingfisher


// String'i fullScreenCover(item:) için Identifiable yap
extension String: Identifiable {
    public var id: String { self }
}

// MARK: - ScanView

struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var showResults = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                if let image = viewModel.capturedImage {
                    // ── Arka plan: bulanık fotoğraf ──
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .blur(radius: 28)
                        .opacity(0.45)
                        .scaleEffect(1.1)

                    Color(hex: "FFF0F0").opacity(0.55).ignoresSafeArea()

                    VStack(spacing: 28) {
                        Spacer()

                        // ── Fotoğraf çerçevesi ──
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .clipped()

                            // Üst & alt vignette
                            LinearGradient(
                                colors: [
                                    Color(hex: "D4728C").opacity(0.12),
                                    Color.clear,
                                    Color(hex: "D4728C").opacity(0.12)
                                ],
                                startPoint: .top, endPoint: .bottom
                            )

                            // Tarama animasyonu (çerçeve içinde)
                            if viewModel.isProcessing || viewModel.isSearching {
                                PhotoScanAnimation()
                            }

                            // Köşe braketleri
                            ScanBrackets()
                        }
                        .aspectRatio(3/4, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
                        .padding(.horizontal, 28)

                        // ── Durum göstergesi ──
                        if viewModel.isProcessing || viewModel.isSearching {
                            VStack(spacing: 10) {
                                HStack(spacing: 10) {
                                    PulsingDot()
                                    Text(viewModel.isProcessing ? lang.s(.scanAnalyzing) : lang.s(.scanSearchingProducts))
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Color(hex: "73585F"))
                                }
                                .padding(.horizontal, 22)
                                .padding(.vertical, 13)
                                .background(Color(hex: "FED9E2").opacity(0.85))
                                .clipShape(Capsule())
                                .shadow(color: Color(hex: "D4728C").opacity(0.15), radius: 12)

                                Text(lang.s(.scanDBSearching))
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "9CA3AF"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "4ADE80"))
                                Text(lang.s(.scanAnalyzeDone))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.08), radius: 12)
                        }

                        Spacer()
                    }

                } else {
                    // ── Kamera açma ekranı ──
                    Color(hex: "FFF0F0").ignoresSafeArea()

                    VStack(spacing: 0) {
                        Spacer()
                        VStack(spacing: 20) {
                            Button {
                                if subscriptionService.canScan() {
                                    viewModel.openCamera()
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "D4728C").opacity(0.06))
                                        .frame(width: 140, height: 140)
                                    Circle()
                                        .fill(Color(hex: "D4728C").opacity(0.12))
                                        .frame(width: 108, height: 108)
                                    Circle()
                                        .fill(Color(hex: "D4728C").opacity(0.18))
                                        .frame(width: 80, height: 80)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 34))
                                        .foregroundColor(Color(hex: "D4728C"))
                                }
                            }
                            VStack(spacing: 8) {
                                Text(lang.s(.scanTapProduct))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                Text(lang.s(.scanTapProductDesc))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "9CA3AF"))
                            }

                            if !subscriptionService.isPremium {
                                Button { showPaywall = true } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                        let remaining = subscriptionService.getRemainingScans()
                                        if remaining > 0 {
                                            Text(String(format: lang.s(.paywallScansLeft), remaining))
                                        } else {
                                            Text(lang.s(.paywallLimitReached))
                                        }
                                    }
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(Color(hex: "D4728C"))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Color(hex: "D4728C").opacity(0.1))
                                    .cornerRadius(20)
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle(lang.s(.scanTitle))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(subscriptionService)
                    .environmentObject(lang)
            }
            .toolbarBackground(
                {
                    if #available(iOS 26.0, *) {
                        return AnyShapeStyle(.ultraThinMaterial)
                    } else {
                        return AnyShapeStyle(.regularMaterial)
                    }
                }(),
                for: .navigationBar
            )
            .toolbar {
                if viewModel.capturedImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewModel.reset()
                            showResults = false
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(Color(hex: "D4728C"))
                        }
                    }
                }
            }
            .sheet(isPresented: $showResults) {
                CameraResultSheet(viewModel: viewModel, onDismiss: {
                    showResults = false
                    viewModel.reset()
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "FFF0F0"))
            }
            .onChange(of: viewModel.hasSearched) { _, searched in
                if searched { showResults = true }
            }
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                SkinCoreCameraView(
                    viewModel: viewModel,
                    onCapture: { image in
                        viewModel.showCamera = false
                        subscriptionService.incrementScanCount()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            viewModel.processImage(image)
                        }
                    },
                    onGallery: {},
                    onCancel: { viewModel.showCamera = false }
                )
            }
            .alert(lang.s(.scanCameraPermissionTitle), isPresented: $viewModel.showPermissionAlert) {
                Button(lang.s(.scanOpenSettings)) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(lang.s(.cancel), role: .cancel) {}
            } message: {
                Text(lang.s(.scanCameraPermissionMsg))
            }
        }
    }
}

// MARK: - Çerçeve içi tarama animasyonu

private struct PhotoScanAnimation: View {
    @State private var scanProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let glowH: CGFloat = 70

            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [Color(hex: "D4728C").opacity(0.30), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: glowH)

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(hex: "D4728C").opacity(0.9),
                        Color.white.opacity(0.9),
                        Color(hex: "D4728C").opacity(0.9),
                        Color.clear
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 2.5)
            }
            .frame(width: w, height: glowH)
            .offset(y: (scanProgress - 0.5) * (h - glowH))
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    scanProgress = 1
                }
            }
        }
    }
}

// MARK: - Çerçeve köşe braketleri

private struct ScanBrackets: View {
    let size: CGFloat = 22
    let lineW: CGFloat = 2.5
    let color = Color(hex: "D4728C").opacity(0.5)
    let padding: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Sol üst
                bracket(at: CGPoint(x: padding, y: padding), hFlip: false, vFlip: false)
                // Sağ üst
                bracket(at: CGPoint(x: w - padding, y: padding), hFlip: true, vFlip: false)
                // Sol alt
                bracket(at: CGPoint(x: padding, y: h - padding), hFlip: false, vFlip: true)
                // Sağ alt
                bracket(at: CGPoint(x: w - padding, y: h - padding), hFlip: true, vFlip: true)
            }
        }
    }

    @ViewBuilder
    private func bracket(at origin: CGPoint, hFlip: Bool, vFlip: Bool) -> some View {
        let sx: CGFloat = hFlip ? -1 : 1
        let sy: CGFloat = vFlip ? -1 : 1

        Path { p in
            p.move(to: CGPoint(x: origin.x, y: origin.y + sy * size))
            p.addLine(to: origin)
            p.addLine(to: CGPoint(x: origin.x + sx * size, y: origin.y))
        }
        .stroke(color, style: StrokeStyle(lineWidth: lineW, lineCap: .round))
    }
}

// MARK: - Pulsing dot

private struct PulsingDot: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "D4728C").opacity(0.35))
                .frame(width: 14, height: 14)
                .scaleEffect(pulsing ? 2 : 1)
                .opacity(pulsing ? 0 : 1)
                .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: pulsing)
            Circle()
                .fill(Color(hex: "D4728C"))
                .frame(width: 8, height: 8)
        }
        .onAppear { pulsing = true }
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
    @Published var showPermissionAlert: Bool = false
    @Published var showOcrDebug: Bool = false

    func openCamera() {
        Task { @MainActor in
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                showCamera = true
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                showCamera = granted
                showPermissionAlert = !granted
            default:
                showPermissionAlert = true
            }
        }
    }

    // Fotoğraf çekildikten sonra: OCR + Image embedding → hybrid search
    func processImage(_ image: UIImage) {
        capturedImage = image
        isProcessing = true
        detectedText = nil
        allOcrLines = []
        searchResults = []
        hasSearched = false

        Task { @MainActor in
            // 1) Orientation normalize + boyut küçült
            let prepared = image.preparedForOCR(maxDimension: 2048)

            // 2) Çerçeve alanına göre crop
            let cropped = cropToScanFrame(prepared)

            guard let cgImage = cropped.cgImage else {
                isProcessing = false
                hasSearched = true
                return
            }

            // 3) OCR — arka planda metin çıkar
            let ocrResults = await recognizeText(from: cgImage)
            allOcrLines = ocrResults.map { $0.text }

            let query = buildSearchQuery(from: ocrResults)
            if !query.isEmpty {
                detectedText = query
            }

            // 4) JPEG data hazırla (embedding için)
            guard let imageData = cropped.jpegData(compressionQuality: 0.8) else {
                isProcessing = false
                hasSearched = true
                return
            }

            // 5) Hybrid search: image + OCR text birlikte gönder
            isProcessing = false
            isSearching = true

            do {
                let results = try await APIClient.shared.searchProductsByImage(
                    imageData: imageData,
                    ocrText: query.isEmpty ? nil : query,
                    maxResults: 5
                )
                searchResults = results
            } catch {
                print("Image search error: \(error)")
                // Fallback: sadece OCR text ile ara
                if !query.isEmpty {
                    await search(query: query)
                    return
                }
                searchResults = []
            }

            isSearching = false
            hasSearched = true
        }
    }

    /// Ekrandaki pembe çerçeveye göre fotoğrafı crop et.
    /// Çerçeve: yatay padding 24pt, yükseklik ekranın %50'si, dikeyde ortalanmış.
    /// Kamera preview scale edildiği için oranları hesaplıyoruz.
    private func cropToScanFrame(_ image: UIImage) -> UIImage {
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height

        // Çerçeve ekrandaki oranları
        let framePaddingH: CGFloat = 24  // her iki tarafta
        let frameW = screenW - (framePaddingH * 2)
        let frameH = screenH * 0.50

        // Çerçevenin ekran üzerindeki oransal konumu
        // Üst bar ~60pt, alt bar ~130pt, geri kalan Spacer-çerçeve-chip-Spacer
        // Çerçeve yaklaşık dikeyde ortalanmış
        let frameXRatio = framePaddingH / screenW
        let frameWRatio = frameW / screenW
        let frameHRatio = frameH / screenH
        // Dikeyde orta: çerçevenin üst kenarı ≈ (1 - frameHRatio) / 2
        let frameYRatio = (1.0 - frameHRatio) / 2.0

        // Fotoğraf boyutuna uygula
        let imgW = image.size.width
        let imgH = image.size.height

        let cropX = imgW * frameXRatio
        let cropY = imgH * frameYRatio
        let cropW = imgW * frameWRatio
        let cropH = imgH * frameHRatio

        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
            .intersection(CGRect(origin: .zero, size: image.size))

        guard !cropRect.isEmpty,
              let cgImage = image.cgImage?.cropping(to: cropRect) else {
            print("⚠️ Crop başarısız, orijinal görseli kullanıyoruz")
            return image
        }

        return UIImage(cgImage: cgImage)
    }

    // OCR sonuçlarından (confidence ile) gelen tüm satırları kullanarak sorgu oluştur
    // - Sıralamayı OCR çıktısının sırasına göre korur
    // - Çok kısa / tamamen sayısal satırları ve belirgin UI gürültüsünü filtreler
    private func buildSearchQuery(from results: [(text: String, confidence: Float)]) -> String {
        let uiNoise: Set<String> = [
            "ara", "search", "kategori", "marka", "makyaj", "saç bakım", "cilt bakım",
            "made in", "sadece", "bakın", "bakım", "yalnızca", "only",
            "add to cart", "sepete ekle", "satın al", "buy", "share", "paylaş",
            "home", "anasayfa", "menu", "menü", "back", "geri", "next", "ileri",
            "login", "giriş", "register", "kayıt", "cancel", "iptal", "ok", "tamam"
        ]

        let cleaned = results.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                let len = line.count
                // Çok kısa veya çok uzun satırları at
                guard len >= 2 && len <= 80 else { return false }
                // En az 2 harf içersin
                let letters = line.filter { $0.isLetter }
                guard letters.count >= 2 else { return false }
                // Harf oranı çok düşükse at (barkod/kod satırları)
                let letterRatio = Double(letters.count) / Double(len)
                guard letterRatio > 0.25 else { return false }
                // UI gürültüsünü at
                let lower = line.lowercased()
                if uiNoise.contains(where: { lower.contains($0) }) { return false }
                return true
            }

        guard !cleaned.isEmpty else { return "" }

        // Tüm temiz satırları OCR sırasıyla birleştir (kullanıcının taradığı tüm metinler DB'de varsa faydalı olur)
        let query = cleaned.joined(separator: " ")
        print("🎯 Kullanılan satırlar: \(cleaned.joined(separator: " | "))")
        return String(query.prefix(200))
    }

    // Vision OCR — confidence ile birlikte döner
    private func recognizeText(from cgImage: CGImage) async -> [(text: String, confidence: Float)] {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            let resumeOnce: ([(String, Float)]) -> Void = { result in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: result)
            }

            // 15 saniye timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                if !hasResumed {
                    print("⏰ OCR TIMEOUT — 15 saniyede yanıt yok, atlanıyor")
                    resumeOnce([])
                }
            }

            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    print("❌ OCR request hatası: \(error.localizedDescription)")
                    resumeOnce([])
                    return
                }
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    print("⚠️ OCR: results nil veya cast edilemedi")
                    resumeOnce([])
                    return
                }
                print("📝 OCR observation sayısı: \(observations.count)")
                let lines: [(String, Float)] = observations.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    let conf = candidate.confidence
                    let text = candidate.string
                    if conf < 0.25 {
                        print("   ⚡ Düşük güven atlandı (\(String(format: "%.0f", conf * 100))%): \(text)")
                        return nil
                    }
                    print("   ✓ [\(String(format: "%.0f", conf * 100))%] \(text)")
                    return (text, conf)
                }
                resumeOnce(lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US", "tr-TR"]
            request.minimumTextHeight = 0.015

            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                print("🔬 VNImageRequestHandler perform başlıyor...")
                try handler.perform([request])
                print("🔬 VNImageRequestHandler perform tamamlandı")
            } catch {
                print("❌ VNImageRequestHandler EXCEPTION: \(error.localizedDescription)")
                resumeOnce([])
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
    }
}

// MARK: - SkinCore Camera View (custom kamera UI)

struct SkinCoreCameraView: View {
    @ObservedObject var viewModel: ScanViewModel
    @EnvironmentObject var lang: LanguageManager
    let onCapture: (UIImage) -> Void
    let onGallery: () -> Void
    let onCancel: () -> Void

    @State private var triggerCapture = false
    @State private var showResultSheet = false
    @State private var showGallerySheet = false
    @State private var flashOn = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // ── Kamera preview tam ekran ──
            CameraPickerRepresentable(
                sourceType: .camera,
                triggerCapture: $triggerCapture,
                flashOn: $flashOn,
                onCapture: onCapture,
                onCancel: onCancel
            )
            .ignoresSafeArea()

            // ── Üstüne bizim UI'ımız ──
            VStack(spacing: 0) {
                // Üst bar
                HStack {
                    Button { onCancel() } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.20))
                                .frame(width: 44, height: 44)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    Text(lang.s(.appBrand))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button { flashOn.toggle() } label: {
                        ZStack {
                            Circle()
                                .fill(flashOn ? Color.yellow.opacity(0.30) : Color.white.opacity(0.20))
                                .frame(width: 44, height: 44)
                            Image(systemName: flashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 16))
                                .foregroundColor(flashOn ? .yellow : .white)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Köşe çerçevesi overlay — orta bölgeyi kaplar
                ScanFrameOverlay(
                    isAnimating: !viewModel.isProcessing && !viewModel.isSearching
                )
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.50)
                .padding(.horizontal, 24)

                // "Analiz ediliyor" / "hizala" chip
                if viewModel.isProcessing || viewModel.isSearching {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white).scaleEffect(0.8)
                        Text(viewModel.isProcessing ? lang.s(.scanAnalyzing) : lang.s(.scanSearchingProducts))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.60))
                    .clipShape(Capsule())
                    .padding(.top, 18)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        Text(lang.s(.scanAlignHint))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.50))
                    .clipShape(Capsule())
                    .padding(.top, 18)
                }

                Spacer()

                // Alt bar: GALERİ + Shutter
                HStack(alignment: .center) {
                    Button { showGallerySheet = true } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                            Text(lang.s(.scanGallery))
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(.white.opacity(0.90))
                        }
                        .frame(width: 70)
                    }

                    Spacer()

                    Button { triggerCapture = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "D4728C").opacity(0.30))
                                .frame(width: 86, height: 86)
                            Circle()
                                .fill(Color(hex: "D4728C"))
                                .frame(width: 68, height: 68)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                        }
                    }

                    Spacer()

                    // Simetri için boş alan
                    Color.clear.frame(width: 70)
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 44)
            }
        }
        // Sonuçlar gelince kamera üstüne alttan yukarı sheet kayar
        .sheet(isPresented: $showResultSheet) {
            CameraResultSheet(viewModel: viewModel, onDismiss: {
                showResultSheet = false
                onCancel()
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(hex: "FFF0F0"))
        }
        // Galeri — kamera içinden açılır, kamera kapanmaz
        .sheet(isPresented: $showGallerySheet) {
            CameraPickerRepresentable(
                sourceType: .photoLibrary,
                triggerCapture: .constant(false),
                flashOn: .constant(false),
                onCapture: { image in
                    showGallerySheet = false
                    // Galeri seçimi sonrası kamerayı kapat, sonuçları işle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onCapture(image)
                    }
                },
                onCancel: { showGallerySheet = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: viewModel.hasSearched) { _, searched in
            if searched { showResultSheet = true }
        }
        .onDisappear {
            flashOn = false
        }
    }
}

// MARK: - Camera Result Sheet (kamera üstüne alttan kayar)

private struct CameraResultSheet: View {
    @ObservedObject var viewModel: ScanViewModel
    @EnvironmentObject var lang: LanguageManager
    let onDismiss: () -> Void

    @State private var selectedProductId: String? = nil
    @State private var showProductRequest = false
    @State private var productTapCount = 0
    @EnvironmentObject var subscriptionService: SubscriptionService

    var body: some View {
        VStack(spacing: 0) {
            // ── Drag handle ──
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(hex: "D1D5DB"))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // ── Başlık ──
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(lang.s(.scanResultsTitle))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(Color(hex: "D4728C"))
                    Text("\(viewModel.searchResults.count) \(lang.s(.matchesFound))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
                Spacer()
                Button { onDismiss() } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F3F4F6"))
                            .frame(width: 34, height: 34)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            if viewModel.searchResults.isEmpty {
                // ── Boş durum ──
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.30))
                    Text(lang.s(.scanProductNotFound))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text(lang.s(.scanRetryPhotoDesc))
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "9CA3AF"))
                    Button { onDismiss() } label: {
                        Text(lang.s(.scanRetryPhoto))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "1A1A2E"))
                            .cornerRadius(25)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
                    Spacer()
                }
            } else {
                // ── Sonuç kartları ──
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, product in
                            Button {
                                if !subscriptionService.isPremium {
                                    productTapCount += 1
                                    if productTapCount % 3 == 0 {
                                        InterstitialAdManager.shared.showAd()
                                    }
                                }
                                selectedProductId = product.id
                            } label: {
                                ScanResultCard(product: product, rank: index + 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    // ── Ürün bulunamadı mı? ──
                    Button {
                        showProductRequest = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 14))
                            Text(lang.s(.scanNotYourProduct))
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "D4728C"))
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "D4728C").opacity(0.08))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
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
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text(lang.s(.scanBackToResults))
                                }
                                .foregroundColor(Color(hex: "D4728C"))
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showProductRequest) {
            NavigationStack {
                ProductRequestView()
            }
        }
    }
}

// MARK: - Scan Frame Overlay (köşeli çerçeve + Google Lens tarama animasyonu)

private struct ScanFrameOverlay: View {
    var isAnimating: Bool = true

    let cornerLength: CGFloat = 32
    let lineWidth: CGFloat = 3
    let color = Color(hex: "D4728C")

    @State private var scanProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let glowH: CGFloat = 56

            ZStack {
                // ── Tarama çizgisi + glow (Google Lens efekti) ──
                if isAnimating {
                    ZStack(alignment: .top) {
                        // Alt glow
                        LinearGradient(
                            colors: [color.opacity(0.22), color.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: glowH)

                        // Çizgi
                        LinearGradient(
                            colors: [color.opacity(0), color, color.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 2)
                    }
                    .frame(width: w, height: glowH)
                    .offset(y: (scanProgress - 0.5) * (h - glowH))
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 2.2)
                            .repeatForever(autoreverses: true)
                        ) {
                            scanProgress = 1
                        }
                    }
                }

                // ── Sol üst köşe ──
                Path { p in
                    p.move(to: CGPoint(x: 0, y: cornerLength))
                    p.addLine(to: .zero)
                    p.addLine(to: CGPoint(x: cornerLength, y: 0))
                }.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // ── Sağ üst köşe ──
                Path { p in
                    p.move(to: CGPoint(x: w - cornerLength, y: 0))
                    p.addLine(to: CGPoint(x: w, y: 0))
                    p.addLine(to: CGPoint(x: w, y: cornerLength))
                }.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // ── Sol alt köşe ──
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h - cornerLength))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.addLine(to: CGPoint(x: cornerLength, y: h))
                }.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // ── Sağ alt köşe ──
                Path { p in
                    p.move(to: CGPoint(x: w - cornerLength, y: h))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: w, y: h - cornerLength))
                }.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
    }
}

// MARK: - CameraPickerRepresentable
// showsCameraControls = false → kendi UI'ımız kontrol eder
// triggerCapture = true yapıldığında takePicture() çağrılır

struct CameraPickerRepresentable: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var triggerCapture: Bool
    @Binding var flashOn: Bool
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        if sourceType == .camera {
            picker.showsCameraControls = false
            picker.cameraDevice = .rear
            picker.cameraFlashMode = flashOn ? .on : .off
            let screenH = UIScreen.main.bounds.height
            let screenW = UIScreen.main.bounds.width
            let cameraAspect: CGFloat = 4.0 / 3.0
            let previewH = screenW * cameraAspect
            let scale = screenH / previewH
            picker.cameraViewTransform = CGAffineTransform(scaleX: scale, y: scale)
            picker.cameraOverlayView = UIView()
        }
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        if sourceType == .camera {
            picker.cameraFlashMode = flashOn ? .on : .off
        }
        if triggerCapture && sourceType == .camera {
            DispatchQueue.main.async {
                picker.takePicture()
                triggerCapture = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void
        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel  = onCancel
        }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

// MARK: - CameraPickerView (galeri için legacy wrapper)
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
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Scan Result Card

struct ScanResultCard: View {
    let product: Product
    let rank: Int // sıralama (1, 2, 3...)
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        HStack(spacing: 14) {
            // Ürün fotoğrafı
            CachedImageView(url: URL(string: product.firstImageUrl ?? ""))
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                // Marka
                if let brand = product.brand {
                    Text(brand.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(Color(hex: "94A3B8"))
                }

                // Ürün adı
                Text(product.name ?? "İsimsiz Ürün")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                    .lineLimit(2)

                // Sıralama bilgisi
                HStack(spacing: 5) {
                    Image(systemName: "number")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "D4728C"))
                    Text("\(rank). \(lang.s(.nearestMatch))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "D4728C"))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "CBD5E1"))
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Product Detail View

struct ProductDetailView: View {
    let productId: String
    @State private var product: ProductWithEnrichedIngredients? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var selectedFilter: SafetyFilter = .all
    @State private var isFavorite: Bool = false
    @State private var isFavoriteLoading: Bool = false
    @State private var selectedIngredient: MatchedIngredient? = nil
    @State private var showModerationSheet = false
    @State private var showSkinCompatSheet = false
    @State private var showPaywall = false
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService

    enum SafetyFilter: String, CaseIterable {
        case all, safe, moderate, avoid
    }

    private func filterLabel(_ filter: SafetyFilter) -> String {
        switch filter {
        case .all: return lang.s(.filterAll)
        case .safe: return lang.s(.filterSafe)
        case .moderate: return lang.s(.filterModerate)
        case .avoid: return lang.s(.filterRisky)
        }
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
        if score > 80 { return lang.s(.scanSafetyClean) }
        if score > 50 { return lang.s(.scanSafetyCaution) }
        return lang.s(.scanSafetyHighRisk)
    }

    private func safetyDescription(for score: Int) -> String {
        if score > 80 { return lang.s(.scanSafetyCleanDesc) }
        if score > 50 { return lang.s(.scanSafetyCautionDesc) }
        return lang.s(.scanSafetyHighRiskDesc)
    }

    private func safetyRingColor(for score: Int) -> Color {
        if score > 80 { return Color(hex: "D4728C") }   // pembe — Safe
        if score > 50 { return Color(hex: "F59E0B") }   // amber — Caution
        return Color(hex: "EF4444")                      // kırmızı — High Risk
    }

    private func filteredIngredients(_ items: [IngredientMatchResult]) -> [IngredientMatchResult] {
        let filtered: [IngredientMatchResult]
        switch selectedFilter {
        case .all:      filtered = items
        case .safe:     filtered = items.filter { $0.matchedIngredient?.resolvedSafetyLevel == 1 }
        case .moderate: filtered = items.filter { $0.matchedIngredient?.resolvedSafetyLevel == 2 }
        case .avoid:    filtered = items.filter { ($0.matchedIngredient?.resolvedSafetyLevel ?? 0) >= 3 }
        }
        // Riskli olanlar önce (yüksek safety level), eşleşmeyenler en sonda
        return filtered.sorted { a, b in
            let aLevel = a.matchedIngredient?.resolvedSafetyLevel ?? 0
            let bLevel = b.matchedIngredient?.resolvedSafetyLevel ?? 0
            if aLevel == 0 && bLevel == 0 { return false }
            if aLevel == 0 { return false }
            if bLevel == 0 { return true }
            return aLevel > bLevel
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
                    Text(lang.s(.analyzing))
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
                                CachedImageView(url: url, contentMode: .fit, placeholderIconSize: 52)
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
                            Text(product.name ?? lang.s(.productDefault))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A2E"))
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 6) {
                                if let count = product.productIngredients?.count {
                                    Text("\(count) \(lang.s(.productIngredientCount))")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "6B7280"))
                                    Circle().fill(Color(hex: "CBD5E1")).frame(width: 3, height: 3)
                                }
                                Text(lang.s(.scanVeganClean))
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
                            Text(lang.s(.scanOverallScore))
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
                                    Text(lang.s(.scanScoreOutOf))
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

                        // ── Cilt Tipi Uyumluluk Butonu ────────────────
                        if let skinType = authViewModel.currentUser?.skinType {
                            Button {
                                if subscriptionService.isPremium {
                                    showSkinCompatSheet = true
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: subscriptionService.isPremium ? "staroflife.fill" : "lock.fill")
                                        .font(.system(size: 14))
                                    Text(subscriptionService.isPremium
                                         ? lang.s(.skinCompatButton)
                                         : lang.s(.skinCompatButtonLocked))
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "D4728C").opacity(0.6))
                                }
                                .foregroundColor(Color(hex: "D4728C"))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color(hex: "FFF0F5"))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "D4728C").opacity(0.25), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .sheet(isPresented: $showSkinCompatSheet) {
                                SkinCompatibilitySheet(
                                    ingredients: ingredients,
                                    skinType: skinType
                                )
                                .environmentObject(lang)
                            }
                        }

                        // ── İçerikler Başlık + Filtre ────────────────
                        VStack(alignment: .leading, spacing: 0) {
                            // Section header
                            HStack {
                                Text(lang.s(.scanIngredientsList))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                Text("(\(ingredients.count))")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
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
                                            Text(filterLabel(filter))
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
                                        Text(lang.s(.scanNoIngredientsInCategory))
                                            .font(.subheadline)
                                            .foregroundColor(Color(hex: "94A3B8"))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 32)
                                } else {
                                    ForEach(filtered) { item in
                                        IngredientDetailCard(
                                            item: item,
                                            userSkinType: subscriptionService.isPremium ? authViewModel.currentUser?.skinType : nil
                                        )
                                            .onTapGesture {
                                                if let matched = item.matchedIngredient {
                                                    selectedIngredient = matched
                                                }
                                            }
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
        .sheet(item: $selectedIngredient) { ingredient in
            IngredientDetailSheet(ingredient: ingredient) {
                selectedIngredient = nil
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showModerationSheet) {
            ModerationRequestView(productId: productId, productName: product?.name)
                .presentationDetents([.fraction(1.0)])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionService)
                .environmentObject(lang)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Button {
                        showModerationSheet = true
                    } label: {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                    Button {
                        guard !isFavoriteLoading, let product = product else { return }
                        isFavoriteLoading = true
                        Task {
                            do {
                                let req = AddFavoriteRequest(
                                    productId: productId,
                                    productName: product.name ?? "",
                                    productBrand: product.brand,
                                    productImageURL: product.firstImageUrl
                                )
                                let response = try await APIClient.shared.toggleFavorite(req)
                                isFavorite = response.isFavorite
                            } catch {
                                print("Toggle favorite error: \(error)")
                            }
                            isFavoriteLoading = false
                        }
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isFavorite ? Color(hex: "D4728C") : Color(hex: "6B7280"))
                    }
                }
            }
        }
        .task {
            do {
                product = try await APIClient.shared.getProductDetails(id: productId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false

            // Favori durumunu kontrol et
            do {
                let favResult = try await APIClient.shared.checkFavorite(productId: productId)
                isFavorite = favResult.isFavorite
            } catch {
                print("Check favorite error: \(error)")
            }
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
    var userSkinType: String? = nil
    @EnvironmentObject var lang: LanguageManager

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
        case 1: return lang.s(.ingredientBadgeSafe)
        case 2: return lang.s(.ingredientBadgeModerate)
        case 3: return lang.s(.ingredientBadgeAvoid)
        default: return lang.s(.ingredientBadgeUnknown)
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

                    if let funcs = item.matchedIngredient?.localizedFunctions, !funcs.isEmpty {
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
            if let desc = item.matchedIngredient?.localizedDescription, !desc.isEmpty {
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
                    Text(lang.s(.ewgScoreLabel))
                        .font(.caption2.bold())
                        .foregroundColor(Color(hex: "94A3B8"))
                    Text(ewg)
                        .font(.caption2.bold())
                        .foregroundColor(accentColor)
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }

            // Cilt Uyumluluğu (Premium)
            if let skinType = userSkinType,
               let ingredient = item.matchedIngredient {
                let goodFor = ingredient.goodFor ?? []
                let badFor = ingredient.badFor ?? []
                // DB'de Türkçe saklanır, EN modunda EN karşılığını da kontrol et
                let skinTypeEn = SkinTypeTranslation.toEn(skinType)
                let isGood = goodFor.contains(skinType) || goodFor.contains(skinTypeEn)
                let isBad = badFor.contains(skinType) || badFor.contains(skinTypeEn)

                if isGood || isBad {
                    HStack(spacing: 6) {
                        Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(isGood ? Color(hex: "22C55E") : Color(hex: "F59E0B"))
                        Text(isGood ? lang.s(.skinTypeCompatible) : lang.s(.skinTypeIncompatible))
                            .font(.caption2.bold())
                            .foregroundColor(isGood ? Color(hex: "22C55E") : Color(hex: "F59E0B"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isGood ? Color(hex: "F0FDF4") : Color(hex: "FFFBEB"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                }
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
                    Text("⚠ \(regions.joined(separator: " & "))\(lang.s(.restrictedRegion))")
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

// MARK: - Skin Compatibility Sheet

struct SkinCompatibilitySheet: View {
    let ingredients: [IngredientMatchResult]
    let skinType: String
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss

    private var skinTypeEn: String { SkinTypeTranslation.toEn(skinType) }

    private var goodIngredients: [IngredientMatchResult] {
        ingredients.filter {
            let gf = $0.matchedIngredient?.goodFor ?? []
            return gf.contains(skinType) || gf.contains(skinTypeEn)
        }
    }

    private var badIngredients: [IngredientMatchResult] {
        ingredients.filter {
            let bf = $0.matchedIngredient?.badFor ?? []
            return bf.contains(skinType) || bf.contains(skinTypeEn)
        }
    }

    private var dataCount: Int {
        ingredients.filter { $0.matchedIngredient?.goodFor != nil || $0.matchedIngredient?.badFor != nil }.count
    }

    // MARK: - Skor Hesaplama

    private struct SkinScoreResult {
        let final: Int          // 0–100
        let compatibility: Int  // 0–100
        let ewgSafety: Int      // 0–100
        let hasData: Bool
    }

    private func computeSkinScore() -> SkinScoreResult {
        guard dataCount >= 3 else {
            return SkinScoreResult(final: 0, compatibility: 0, ewgSafety: 0, hasData: false)
        }

        let matched = ingredients.compactMap { $0.matchedIngredient }
        let total = Double(dataCount)

        // ── 1. Cilt Uyumluluk Skoru (0–100) ──────────────────
        let goodCount = Double(goodIngredients.count)
        let badCount  = Double(badIngredients.count)

        // Bad ingredientlere 1.5x ağırlık ver
        let rawCompat = (goodCount - badCount * 1.5) / total * 100
        let compatScore = max(0.0, min(100.0, rawCompat + 50)) // 50 offset: nötr = 50

        // ── 2. EWG Güvenlik Skoru (0–100) ────────────────────
        var ewgWeightedSum = 0.0
        var ewgMaxSum      = 0.0

        for ing in matched {
            // EWG skoru "1", "1-2", "3-6" gibi gelebilir — ilk sayıyı al
            guard let ewgStr = ing.ewgScore,
                  let ewgVal = Double(ewgStr.components(separatedBy: "-").first ?? ewgStr)
            else { continue }

            let clampedEwg = max(1.0, min(10.0, ewgVal))
            let normalized = (10.0 - clampedEwg) / 9.0 * 100  // EWG 1→100, EWG 10→0
            ewgWeightedSum += normalized
            ewgMaxSum      += 100
        }

        let ewgScore: Double
        if ewgMaxSum > 0 {
            ewgScore = ewgWeightedSum / ewgMaxSum * 100
        } else {
            ewgScore = 60.0 // veri yoksa nötr varsay
        }

        // ── 3. Kritik EWG Cezası ─────────────────────────────
        var penalty = 0.0
        for item in ingredients {
            guard let ing = item.matchedIngredient,
                  let ewgStr = ing.ewgScore,
                  let ewgVal = Double(ewgStr.components(separatedBy: "-").first ?? ewgStr)
            else { continue }

            if ewgVal >= 8 {
                // Cilde iyi gelse bile EWG≥8 ise ek ceza
                penalty += 5.0
            }
        }
        penalty = min(penalty, 25.0) // max 25 puan ceza

        // ── 4. Final Skor ─────────────────────────────────────
        // EWG kötüyse cilt uyumu ne kadar iyi olursa olsun skoru sınırla
        let rawFinal = min(compatScore, ewgScore) - penalty
        let finalScore = max(0.0, min(100.0, rawFinal))

        return SkinScoreResult(
            final: Int(finalScore.rounded()),
            compatibility: Int(compatScore.rounded()),
            ewgSafety: Int(ewgScore.rounded()),
            hasData: true
        )
    }

    private var scoreResult: SkinScoreResult { computeSkinScore() }

    private var score: Int { scoreResult.hasData ? scoreResult.final : -999 }

    private var scoreLabel: String {
        if score == -999 { return lang.s(.skinCompatInsufficientData) }
        if score >= 80 { return lang.s(.skinCompatVeryGood) }
        if score >= 65 { return lang.s(.skinCompatGood) }
        if score >= 50 { return lang.s(.skinCompatNeutral) }
        if score >= 35 { return lang.s(.skinCompatCaution) }
        return lang.s(.skinCompatBad)
    }

    private var scoreColor: Color {
        if score == -999 { return Color(hex: "94A3B8") }
        if score >= 80 { return Color(hex: "22C55E") }
        if score >= 65 { return Color(hex: "86EFAC") }
        if score >= 50 { return Color(hex: "94A3B8") }
        if score >= 35 { return Color(hex: "F59E0B") }
        return Color(hex: "EF4444")
    }

    // 0..1 aralığına çevir ring için (0–100 skala)
    private var scoreProgress: CGFloat {
        guard score != -999 else { return 0 }
        return CGFloat(score) / 100.0
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Score Card (overall safety ile aynı stil) ──
                    VStack(spacing: 16) {
                        Text(lang.s(.skinCompatScore))
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(Color(hex: "94A3B8"))

                        ZStack {
                            Circle()
                                .stroke(Color(hex: "F1F5F9"), lineWidth: 14)
                            Circle()
                                .trim(from: 0, to: scoreProgress)
                                .stroke(
                                    AngularGradient(
                                        colors: [scoreColor.opacity(0.6), scoreColor],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 1.2), value: scoreProgress)

                            VStack(spacing: 2) {
                                if score == -999 {
                                    Image(systemName: "questionmark")
                                        .font(.system(size: 36, weight: .black))
                                        .foregroundColor(Color(hex: "94A3B8"))
                                } else {
                                    Text("\(score)")
                                        .font(.system(size: 52, weight: .black, design: .rounded))
                                        .foregroundColor(Color(hex: "1A1A2E"))
                                    Text(lang.s(.scanScoreOutOf))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(hex: "94A3B8"))
                                }
                            }
                        }
                        .frame(width: 160, height: 160)
                        .padding(.vertical, 8)

                        VStack(spacing: 8) {
                            Text(scoreLabel)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A2E"))

                            Text(SkinTypeTranslation.localized(skinType, lang: lang))
                                .font(.caption.bold())
                                .foregroundColor(Color(hex: "D4728C"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color(hex: "FFF0F5"))
                                .clipShape(Capsule())
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

                    // ── Ingredient Listeleri ──
                    if dataCount < 3 {
                        Text(lang.s(.skinCompatNoData))
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 32)
                    } else {
                        VStack(spacing: 0) {
                            if !goodIngredients.isEmpty {
                                SkinCompatSection(
                                    title: lang.s(.skinCompatGoodSection),
                                    items: goodIngredients,
                                    isGood: true
                                )
                            }
                            if !badIngredients.isEmpty {
                                SkinCompatSection(
                                    title: lang.s(.skinCompatBadSection),
                                    items: badIngredients,
                                    isGood: false
                                )
                            }
                        }
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(hex: "F8F9FA").ignoresSafeArea())
            .navigationTitle(lang.s(.skinCompatTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.s(.paywallClose)) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color(hex: "94A3B8"))
        }
    }
}

// MARK: - Skin Compat Section

private struct SkinCompatSection: View {
    let title: String
    let items: [IngredientMatchResult]
    let isGood: Bool
    @EnvironmentObject var lang: LanguageManager

    private var accentColor: Color {
        isGood ? Color(hex: "22C55E") : Color(hex: "F59E0B")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header — IngredientDetailCard listesindekiyle aynı stil
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                Text("(\(items.count))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 12)

            // Ingredient kartları — IngredientDetailCard ile aynı
            VStack(spacing: 10) {
                ForEach(items) { item in
                    SkinCompatIngredientCard(item: item, isGood: isGood)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Skin Compat Ingredient Card

private struct SkinCompatIngredientCard: View {
    let item: IngredientMatchResult
    let isGood: Bool
    @EnvironmentObject var lang: LanguageManager

    private var ingredient: MatchedIngredient? { item.matchedIngredient }
    private var safetyLevel: Int { ingredient?.resolvedSafetyLevel ?? 0 }

    private var safetyColor: Color {
        switch safetyLevel {
        case 1: return Color(hex: "22C55E")
        case 2: return Color(hex: "F59E0B")
        case 3: return Color(hex: "EF4444")
        default: return Color(hex: "94A3B8")
        }
    }

    private var compatIcon: String {
        isGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var compatColor: Color {
        isGood ? Color(hex: "22C55E") : Color(hex: "F59E0B")
    }

    private var displayName: String {
        ingredient?.displayName ?? item.originalString?.capitalized ?? "-"
    }

    private var badgeText: String {
        switch safetyLevel {
        case 1: return lang.s(.ingredientBadgeSafe)
        case 2: return lang.s(.ingredientBadgeModerate)
        case 3: return lang.s(.ingredientBadgeAvoid)
        default: return lang.s(.ingredientBadgeUnknown)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                Image(systemName: compatIcon)
                    .font(.system(size: 22))
                    .foregroundColor(compatColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                        .lineLimit(2)
                    if let inci = ingredient?.inciName, !inci.isEmpty,
                       inci.lowercased() != displayName.lowercased() {
                        Text(inci)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "94A3B8"))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Güvenlik badge
                Text(badgeText)
                    .font(.caption2.bold())
                    .foregroundColor(safetyColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(safetyColor.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, ingredient?.localizedDescription != nil ? 8 : 14)

            // Açıklama
            if let desc = ingredient?.localizedDescription, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(Color(hex: "6B7280"))
                    .lineLimit(3)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }

            // EWG skoru
            if let ewg = ingredient?.ewgScore, !ewg.isEmpty {
                HStack(spacing: 6) {
                    Text(lang.s(.ewgScoreLabel))
                        .font(.caption2.bold())
                        .foregroundColor(Color(hex: "94A3B8"))
                    Text(ewg)
                        .font(.caption2.bold())
                        .foregroundColor(safetyColor)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(compatColor.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Skin Type TR ↔ EN Map

enum SkinTypeTranslation {
    static let trToEn: [String: String] = [
        "Normal": "Normal",
        "Kuru": "Dry",
        "Yağlı": "Oily",
        "Karma": "Combination",
        "Hassas": "Sensitive",
        "Akneye Meyilli": "Acne-Prone",
        "Olgun": "Mature"
    ]

    static func toEn(_ tr: String) -> String {
        trToEn[tr] ?? tr
    }

    static func localized(_ tr: String, lang: LanguageManager) -> String {
        if lang.language == .en {
            return toEn(tr)
        }
        return tr
    }
}

// MARK: - (legacy stub — kept for backward compat)
private struct IngredientRow: View {
    let item: IngredientMatchResult
    var body: some View { EmptyView() }
}

// MARK: - UIImage OCR Preparation

extension UIImage {
    /// Kamera fotoğrafını OCR için hazırlar:
    /// 1) imageOrientation'ı .up'a normalize eder (döndürme düzeltir)
    /// 2) Boyutu maxDimension'a küçültür (bellek + hız optimizasyonu)
    /// 3) Kontrast iyileştirmesi (gri tonlama yok, sadece boyut)
    func preparedForOCR(maxDimension: CGFloat = 2048) -> UIImage {
        let targetSize: CGSize
        if size.width > size.height {
            if size.width <= maxDimension { targetSize = size }
            else {
                let ratio = maxDimension / size.width
                targetSize = CGSize(width: maxDimension, height: size.height * ratio)
            }
        } else {
            if size.height <= maxDimension { targetSize = size }
            else {
                let ratio = maxDimension / size.height
                targetSize = CGSize(width: size.width * ratio, height: maxDimension)
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1  // @1x — OCR için retina gereksiz
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - ModerationRequestView

struct ModerationRequestView: View {
    let productId: String
    let productName: String?

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lang: LanguageManager

    @State private var note = ""
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var showPhotoDialog = false
    @State private var showImagePicker = false
    @State private var isPickingFront = true
    @State private var currentSourceType: UIImagePickerController.SourceType = .photoLibrary

    private var canSubmit: Bool {
        !isLoading && (frontImage != nil || backImage != nil || !note.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 8)

                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Color(hex: "D4728C"))

                            Text(lang.s(.moderationTitle))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A2E"))

                            if let name = productName {
                                Text(name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "D4728C"))
                            }

                            Text(lang.s(.moderationSubtitle))
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "6B7280"))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .padding(.top, 2)
                        }
                        .padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(lang.s(.moderationNoteLabel))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "6B7280"))
                                .padding(.horizontal, 24)

                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "F3D5DC"), lineWidth: 1))

                                if note.isEmpty {
                                    Text(lang.s(.moderationNotePlaceholder))
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "C0A0A8"))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                }

                                TextEditor(text: $note)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 90, maxHeight: 120)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                            }
                            .padding(.horizontal, 24)
                        }

                        VStack(spacing: 12) {
                            Text(lang.s(.moderationPhotoLabel))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "6B7280"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)

                            HStack(spacing: 12) {
                                ModerationPhotoCard(title: lang.s(.moderationFrontPhoto), image: frontImage) {
                                    isPickingFront = true; showPhotoDialog = true
                                }
                                ModerationPhotoCard(title: lang.s(.moderationBackPhoto), image: backImage) {
                                    isPickingFront = false; showPhotoDialog = true
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Color(hex: "EF4444"))
                                .padding(.horizontal, 24)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill").font(.system(size: 15))
                                    Text(lang.s(.moderationSubmit)).font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(canSubmit ? Color(hex: "D4728C") : Color(hex: "E5E7EB"))
                            .foregroundColor(canSubmit ? .white : Color(hex: "9CA3AF"))
                            .cornerRadius(28)
                        }
                        .disabled(!canSubmit)
                        .padding(.horizontal, 24)

                        Spacer().frame(height: 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(Color(hex: "1A1A2E"))
                    }
                }
            }
            .confirmationDialog(lang.s(.moderationPhotoDialog), isPresented: $showPhotoDialog, titleVisibility: .visible) {
                Button(lang.s(.moderationCamera)) { currentSourceType = .camera; showImagePicker = true }
                Button(lang.s(.moderationGallery)) { currentSourceType = .photoLibrary; showImagePicker = true }
                Button(lang.s(.cancel), role: .cancel) { }
            }
            .fullScreenCover(isPresented: $showImagePicker) {
                ProductRequestImagePicker(
                    sourceType: currentSourceType,
                    selectedImage: isPickingFront ? $frontImage : $backImage
                )
                .ignoresSafeArea()
            }
            .alert(lang.s(.moderationSuccessTitle), isPresented: $showSuccess) {
                Button(lang.s(.ok)) { dismiss() }
            } message: {
                Text(lang.s(.moderationSuccessMsg))
            }
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await APIClient.shared.submitModerationRequest(
                productId: productId,
                note: note.isEmpty ? nil : note.trimmingCharacters(in: .whitespaces),
                frontImageData: frontImage?.jpegData(compressionQuality: 0.8),
                backImageData: backImage?.jpegData(compressionQuality: 0.8)
            )
            showSuccess = true
        } catch let error as APIClientError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ModerationPhotoCard: View {
    let title: String
    let image: UIImage?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(image != nil ? Color(hex: "D4728C") : Color(hex: "F3D5DC"),
                                    lineWidth: image != nil ? 1.5 : 1)
                    )

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "D4728C").opacity(0.5))
                        Text(title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "9CA3AF"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(12)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 120)
        }
    }
}
