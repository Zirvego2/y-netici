# Firebase Yapılandırması

## google-services.json Dosyası Eksik

Uygulama şu anda Firebase yapılandırması olmadan çalışacak şekilde ayarlandı. Ancak Firebase özelliklerini (Firestore, Auth) kullanmak için `google-services.json` dosyasını eklemeniz gerekiyor.

## Adımlar

### 1. Firebase Console'a Giriş Yapın

1. https://console.firebase.google.com/ adresine gidin
2. `zirvenew` projenizi seçin (veya yeni proje oluşturun)

### 2. Android Uygulaması Ekleyin

1. Firebase Console'da "Project Settings" (⚙️) → "Your apps" bölümüne gidin
2. "Add app" → Android seçeneğini seçin
3. **Package name**: `com.zirvego.mainapp` (app/build.gradle'daki applicationId ile aynı olmalı)
4. **App nickname**: "ZirveGo Main App" (opsiyonel)
5. "Register app" butonuna tıklayın

### 3. google-services.json İndirin

1. İndirilen `google-services.json` dosyasını kopyalayın
2. Dosyayı şu konuma yerleştirin:
   ```
   ZirveGo-MainApp/android/app/google-services.json
   ```

### 4. Uygulamayı Yeniden Derleyin

```powershell
flutter clean
flutter pub get
flutter run
```

## Alternatif: FlutterFire CLI (Önerilen)

Daha kolay bir yöntem:

```powershell
# FlutterFire CLI'ı yükleyin (eğer yoksa)
dart pub global activate flutterfire_cli

# Firebase'e giriş yapın
firebase login

# Projeyi yapılandırın
flutterfire configure
```

Bu komut:
- Firebase projenizi seçmenizi sağlar
- `google-services.json` dosyasını otomatik oluşturur
- `lib/firebase_options.dart` dosyasını oluşturur
- Tüm platformlar için yapılandırma yapar

## Not

- `google-services.json` dosyası `.gitignore`'da olduğu için Git'e commit edilmeyecek (güvenlik için)
- Her geliştirici kendi Firebase projesini kullanabilir veya ortak bir proje kullanılabilir
- Production'da gerçek Firebase projesi kullanılmalı

## Test İçin

Firebase yapılandırması olmadan da uygulama çalışır, ancak:
- Firestore sorguları çalışmaz
- Firebase Auth çalışmaz
- Login ekranı hata verebilir

Bu durumda `lib/utils/firebase_config.dart` dosyasındaki fallback yapılandırması kullanılır (sadece test için).
