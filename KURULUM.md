# ZirveGo Main App - Kurulum Rehberi

## Hızlı Başlangıç

### 1. Flutter Kurulumu

Flutter SDK'nın yüklü olduğundan emin olun:

```bash
flutter --version
```

Eğer yüklü değilse: https://flutter.dev/docs/get-started/install

### 2. Projeyi Klonlayın ve Bağımlılıkları Yükleyin

```bash
cd ZirveGo-MainApp
flutter pub get
```

### 3. Firebase Yapılandırması

#### Yöntem 1: FlutterFire CLI (Önerilen)

```bash
# FlutterFire CLI'ı yükleyin
dart pub global activate flutterfire_cli

# Firebase'e giriş yapın
firebase login

# Projeyi yapılandırın
flutterfire configure
```

Bu komut sizin için:
- Firebase projenizi seçmenizi sağlar
- Platform dosyalarını (google-services.json, GoogleService-Info.plist) otomatik oluşturur
- `firebase_options.dart` dosyasını oluşturur

#### Yöntem 2: Manuel Yapılandırma

1. Firebase Console'dan (`zirvenew` projesi):
   - Android için `google-services.json` dosyasını indirin
   - iOS için `GoogleService-Info.plist` dosyasını indirin

2. Dosyaları yerleştirin:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

3. `lib/utils/firebase_config.dart` dosyasını güncelleyin:
   ```dart
   static FirebaseOptions getFirebaseOptions() {
     return const FirebaseOptions(
       apiKey: "GERÇEK_API_KEY",
       authDomain: "zirvenew.firebaseapp.com",
       projectId: "zirvenew",
       storageBucket: "zirvenew.appspot.com",
       messagingSenderId: "GERÇEK_SENDER_ID",
       appId: "GERÇEK_APP_ID",
     );
   }
   ```

### 4. Android Yapılandırması

`android/app/build.gradle` dosyasında `minSdkVersion` ve diğer ayarlar zaten yapılandırılmış durumda.

### 5. iOS Yapılandırması (Sadece macOS)

```bash
cd ios
pod install
cd ..
```

### 6. Uygulamayı Çalıştırın

```bash
# Android
flutter run

# iOS (macOS gerekli)
flutter run -d ios

# Belirli bir cihaz için
flutter devices
flutter run -d <device-id>
```

## Test Kullanıcısı

Firestore'da `t_bay` koleksiyonunda admin kullanıcısı olduğundan emin olun:

```javascript
{
  s_username: "admin",
  s_password: "password123",
  s_admin: 1,
  s_info: {
    ss_name: "Admin",
    ss_surname: "User"
  },
  s_bay_name: "Test Bay"
}
```

## Sorun Giderme

### Firebase bağlantı hatası

- Firebase yapılandırma dosyalarının doğru yerde olduğundan emin olun
- Firebase Console'da proje ayarlarını kontrol edin
- Internet bağlantınızı kontrol edin

### Build hataları

```bash
flutter clean
flutter pub get
flutter run
```

### Android build hatası

- Android Studio'da SDK'yı güncelleyin
- `android/gradle/wrapper/gradle-wrapper.properties` dosyasında Gradle versiyonunu kontrol edin

### iOS build hatası

```bash
cd ios
pod deintegrate
pod install
cd ..
```

## Geliştirme Notları

- Login ekranı tamamen çalışır durumda
- Home screen şu anda basit bir hoş geldiniz ekranı gösteriyor
- İleride ana panel özellikleri eklenecek

## Destek

Sorularınız için: support@zirvego.com
