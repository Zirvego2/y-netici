# Codemagic iOS Signing Hatası Çözümü

## 🔴 Hata Mesajı
```
Error (Xcode): Provisioning profile "kurye operasyon yonetimi ios_app_store 1773700171" 
doesn't include signing certificate "Apple Distribution: Ali Öksz (7GFLBJ5RR5)".
```

## 🔍 Sorun
Provisioning profile ile signing certificate uyumsuz. Profile içinde bu certificate yok.

## ✅ Çözüm Adımları

### 1. Codemagic UI'da Code Signing Ayarları

1. **Codemagic Dashboard'a gidin:** https://codemagic.io
2. **Projenizi seçin**
3. **Settings > Code signing identities** bölümüne gidin
4. **Apple Distribution certificate kontrolü:**
   - Certificate adı: `Apple Distribution: Ali Öksz (7GFLBJ5RR5)`
   - Bu certificate'in yüklü olduğundan emin olun
   - Eğer yoksa, `.p12` dosyasını yükleyin

### 2. Provisioning Profile Güncelleme

**Seçenek A: App Store Connect'te Profile Güncelleme**
1. https://developer.apple.com/account adresine gidin
2. **Certificates, Identifiers & Profiles** bölümüne gidin
3. **Profiles** sekmesine tıklayın
4. `kurye operasyon yonetimi ios_app_store` profile'ını bulun
5. **Edit** butonuna tıklayın
6. **Certificates** bölümünde `Apple Distribution: Ali Öksz (7GFLBJ5RR5)` certificate'inin seçili olduğundan emin olun
7. **Save** ve **Download** yapın
8. Codemagic'e yükleyin

**Seçenek B: Codemagic'te Otomatik Profile Oluşturma**
- Codemagic yapılandırmasında `app-store-connect fetch-signing-files` komutu var
- Bu komut otomatik olarak doğru certificate ile profile oluşturabilir
- Ancak App Store Connect API key'lerinin Codemagic'te tanımlı olması gerekir

### 3. Codemagic Environment Variables Kontrolü

Codemagic'te şu environment variable'ların tanımlı olduğundan emin olun:
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_PRIVATE_KEY`

Bu değişkenler tanımlıysa, `fetch-signing-files` komutu otomatik olarak doğru profile'ı oluşturur.

### 4. Codemagic Groups Kontrolü

`codemagic.yaml` dosyasında:
```yaml
groups:
  - app_store_credentials
```

Bu group'un Codemagic'te tanımlı olduğundan ve doğru certificate/profile içerdiğinden emin olun.

## 🔧 Yapılan Kod Değişiklikleri

### 1. Diagnostic Bilgileri Eklendi
- Archive öncesi certificate ve profile kontrolü
- Export öncesi certificate ve profile eşleştirme kontrolü
- Daha detaylı hata mesajları

### 2. Archive Aşaması İyileştirildi
- Certificate ve profile bilgileri loglanıyor
- Archive sırasında doğru signing bilgilerinin kullanıldığından emin olunuyor

## 📋 Kontrol Listesi

- [ ] Codemagic'te `Apple Distribution: Ali Öksz (7GFLBJ5RR5)` certificate'i yüklü mü?
- [ ] Provisioning profile `kurye operasyon yonetimi ios_app_store` bu certificate'i içeriyor mu?
- [ ] App Store Connect API key'leri Codemagic'te tanımlı mı?
- [ ] `app_store_credentials` group'u doğru yapılandırılmış mı?

## 🚀 Sonraki Adımlar

1. Codemagic UI'da certificate ve profile'ı kontrol edin
2. Gerekirse profile'ı güncelleyin veya yeniden oluşturun
3. Build'i tekrar çalıştırın
4. Diagnostic loglarını kontrol edin

## 📝 Notlar

- Archive aşaması başarılı olabilir ama export aşamasında hata alabilirsiniz
- Bu durumda profile ile certificate'in uyumsuz olduğu kesindir
- En iyi çözüm: App Store Connect'te profile'ı güncelleyip Codemagic'e yüklemek
