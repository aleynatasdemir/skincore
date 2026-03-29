# API Server Deployment Instructions

## Ortam Değişkenleri (Environment Variables)
Uygulamayı bir server'da çalıştırırken aşağıdaki değişkenleri sistem düzeyinde (Linux/Windows Environment Variables) tanımlayabilirsiniz.

### 1. MongoDB Bağlantısı
Uygulamanın MongoDB'ye bağlanacağı adresi değiştirmek için ortam değişkeni olarak şunu ekleyin:

**Linux / macOS:**
```bash
export MongoDbSettings__ConnectionString="mongodb://KENDI_SERVER_IP_VEYA_ATLAS_URL:27017"
```

**Windows (PowerShell):**
```powershell
$env:MongoDbSettings__ConnectionString="mongodb://KENDI_SERVER_IP_VEYA_ATLAS_URL:27017"
```

*Not: Eğer `appsettings.json` içerisindeki diğer ayarları ezmek isterseniz `__` (çift alt çizgi) kullanarak hiyerarşiyi belirtebilirsiniz. Örneğin: `MongoDbSettings__DatabaseName`.*

### 2. Uygulama Portunu Değiştirme (Özel Port)
Server'da uygulamanızın başka servislerle çakışmaması için .NET'e özel bir port atayabilirsiniz (Örn: `5050`):

**Linux / macOS:**
```bash
export ASPNETCORE_URLS="http://0.0.0.0:5050"
```

**Windows (PowerShell):**
```powershell
$env:ASPNETCORE_URLS="http://0.0.0.0:5050"
```

*Not: Bunu yaptıktan sonra Frontend'deki `.env` dosyanızda yer alan `VITE_API_URL` ayarını da bu portu gösterecek şekilde (`http://sunucu_ip:5050`) güncellemeyi unutmayın.*

### 3. Uygulamayı Yayınlama
Terminal üzerinden backend dizininde şu komutu çalıştırarak sunucu için yayın (publish) klasörünü oluşturabilirsiniz:
```bash
dotnet publish -c Release -o ./publish
```

Oluşan `publish` klasörünü sunucuya yükleyip komut satırından `dotnet SilkProductManager.Api.dll` ile veya Nginx/IIS arkasında çalıştırabilirsiniz.
