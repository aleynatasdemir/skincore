# SkinCore 🧴

Kozmetik ürünlerin içeriklerini analiz eden iOS mobil uygulaması.  
**Stack:** React Native (TypeScript) · .NET 8 Web API · PostgreSQL / MongoDB

---

## 📱 Mobil Uygulama (React Native)

### Kurulum & Temel Yapı
- [ ] React Native + TypeScript projesi oluştur
- [ ] React Navigation kur (Stack + Bottom Tab)
- [ ] Axios HTTP istemcisini kur
- [ ] `react-native-vision-camera` kütüphanesini entegre et
- [ ] Genel klasör yapısını oluştur (`screens/`, `components/`, `services/`, `navigation/`)

### Ekranlar
- [ ] **Ana Sayfa / Arama Ekranı** – ürün adı ile arama
- [ ] **Barkod Tarama Ekranı** – kamera ile barkod okuma
- [ ] **OCR Ekranı** – kamera ile ürün adı tanıma
- [ ] **Ürün Detay Ekranı** – ürün bilgileri + içerik listesi
- [ ] **İçerik Analiz Ekranı** – güvenlik etiketleri + komedojenite skorları (renk kodlu)
- [ ] **Favoriler Ekranı** – favori ürün listesi
- [ ] **Tarama Geçmişi Ekranı** – önceki taramalar
- [ ] **Kullanıcı Profil Ekranı** – cilt profili & hesap bilgileri

### Backend Entegrasyonu
- [ ] API base URL konfigürasyonu
- [ ] Ürün arama isteği (`GET /products/search?q=`)
- [ ] Ürün detay isteği (`GET /products/:id`)
- [ ] Barkod ile ürün bulma (`GET /products/barcode/:code`)
- [ ] OCR metin ile ürün arama (`POST /scan/ocr`)
- [ ] Ingredient analiz sonuçlarını çekme (`GET /products/:id/ingredients`)
- [ ] Favori ekleme / kaldırma
- [ ] Kullanıcı profil işlemleri

---

## 🔧 Backend (.NET 8 Web API)

### Kurulum & Yapılandırma
- [ ] .NET 8 Web API projesi oluştur
- [ ] Katmanlı mimari klasör yapısını oluştur (`Controllers/`, `Services/`, `Repositories/`, `Models/`, `DTOs/`, `Data/`, `Middleware/`)
- [ ] PostgreSQL veya MongoDB bağlantısını yapılandır
- [ ] Global exception middleware yaz
- [ ] Logging sistemini kur (Serilog)

### Controller'lar
- [ ] `AuthController` – giriş / kayıt
- [ ] `ProductController` – ürün arama, detay, barkod
- [ ] `IngredientController` – içerik listesi & analiz
- [ ] `ScanController` – barkod & OCR işleme
- [ ] `FavoritesController` – favori ekleme / listeleme
- [ ] `UserController` – profil yönetimi

### Servisler
- [ ] `ProductService` – ürün arama, barkod eşleştirme
- [ ] `IngredientService` – içerik güvenlik analizi
- [ ] `ScanService` – barkod & OCR veri işleme
- [ ] `SearchService` – fuzzy search algoritması
- [ ] `UserService` – kullanıcı işlemleri
- [ ] `FavoriteService` – favori yönetimi

### Repository'ler
- [ ] `ProductRepository`
- [ ] `IngredientRepository`
- [ ] `UserRepository`
- [ ] `FavoriteRepository`

---

## 🗄️ Veritabanı

- [ ] Veritabanı teknolojisine karar ver (PostgreSQL / MongoDB)
- [ ] `users` tablosunu oluştur
- [ ] `products` tablosunu oluştur
- [ ] `ingredients` tablosunu oluştur
- [ ] `product_ingredients` (M:N) tablosunu oluştur
- [ ] `favorites` tablosunu oluştur
- [ ] `scan_history` tablosunu oluştur
- [ ] Ürün & ingredient verilerini veritabanına yükle

---

## 📷 Computer Vision (OCR & Barkod)

- [ ] `react-native-vision-camera` ile kamera akışını başlat
- [ ] **Barkod okuma** – `AVFoundation` ile iOS barkod tanıma
- [ ] **OCR** – `Apple Vision` framework ile metin tanıma
- [ ] Metin normalizasyonu – küçük harf, özel karakter temizleme, fazla boşluk kaldırma
- [ ] OCR metnini backend'e gönderme pipeline'ı

---

## 🔍 Ürün Arama Algoritması

- [ ] **Manuel arama** – tam metin araması
- [ ] **Barkod araması** – barkod ile doğrudan eşleştirme
- [ ] **Fuzzy search** – OCR çıktısı için benzerlik skoru hesaplama
- [ ] Token tabanlı eşleştirme (kelime sırası farklı olsa bile eşleştir)
- [ ] Benzerlik skoru eşiği belirle ve en iyi sonucu döndür

---

## 🧪 Ingredient Analysis Engine

- [ ] Ingredient veritabanını oluştur (isim, safety label, komedojenite skoru, kategori, açıklama)
- [ ] Ürün ingredient listesini ingredient DB ile eşleştir
- [ ] Her içerik için güvenlik etiketi çıkar
- [ ] Komedojenite skoru çıkar
- [ ] Genel ürün güvenlik değerlendirmesi hesapla
- [ ] Yüksek komedojenite uyarı sistemi
- [ ] Analiz sonucunu API üzerinden mobile gönder

---

## ✅ Test & Teslim

- [ ] API endpoint'lerini test et
- [ ] Barkod tarama testleri
- [ ] OCR doğruluk testleri
- [ ] Fuzzy search sonuçlarını doğrula
- [ ] Uygulama genel kullanıcı akışı testi
- [ ] README güncelle & projeyi teslim et
