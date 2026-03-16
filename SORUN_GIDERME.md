# Sorun Giderme Rehberi

## Gradle/Java Uyumsuzluk Hataları

### Hata: "Unsupported class file major version 65"

Bu hata, Java 21 kullanıldığında Gradle 8.0 ile uyumsuzluk olduğunu gösterir.

**Çözüm:**
1. Gradle versiyonunu güncelledik (8.0 → 8.3)
2. AndroidX'i etkinleştirdik
3. Java versiyonunu 17'ye ayarladık

Eğer hala sorun yaşıyorsanız:

```bash
# Gradle cache'i temizle
cd android
./gradlew clean --no-daemon
cd ..

# Flutter cache'i temizle
flutter clean
flutter pub get

# Tekrar dene
flutter run
```

### Java Versiyonunu Kontrol Etme

```bash
# Java versiyonunu kontrol et
java -version

# Flutter'ın kullandığı Java'yı kontrol et
flutter doctor -v
```

**Önerilen Java Versiyonları:**
- Java 17 (LTS) - Önerilen
- Java 21 - Çalışır ama Gradle 8.3+ gerektirir

### AndroidX Uyarısı

AndroidX artık otomatik olarak etkinleştirildi (`gradle.properties` dosyasında).

Eğer hala uyarı alıyorsanız:

```bash
# Android klasörünü temizle
cd android
./gradlew clean
cd ..

# Flutter clean
flutter clean
flutter pub get
flutter run
```

## Build Hataları

### "Could not resolve all files for configuration"

```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

### "SDK location not found"

`android/local.properties` dosyasını kontrol edin:

```properties
sdk.dir=C\:\\Users\\YOUR_USERNAME\\AppData\\Local\\Android\\Sdk
flutter.sdk=C\:\\path\\to\\flutter
```

### Firebase Yapılandırma Hataları

1. `google-services.json` dosyasının `android/app/` klasöründe olduğundan emin olun
2. `build.gradle` dosyasında `apply plugin: 'com.google.gms.google-services'` satırının en sonda olduğundan emin olun

## Genel Çözümler

### 1. Tam Temizlik ve Yeniden Build

```bash
# Flutter temizliği
flutter clean

# Android temizliği
cd android
./gradlew clean
cd ..

# Bağımlılıkları yeniden yükle
flutter pub get

# Build ve çalıştır
flutter run
```

### 2. Gradle Wrapper'ı Yeniden İndir

```bash
cd android
./gradlew wrapper --gradle-version=8.3
cd ..
```

### 3. Flutter Doctor Kontrolü

```bash
flutter doctor -v
```

Tüm sorunları çözün (Android Studio, Android SDK, Java, vb.)

### 4. Android Studio ile Build

Bazen Android Studio üzerinden build yapmak daha iyi çalışır:

1. Android Studio'yu açın
2. `ZirveGo-MainApp/android` klasörünü açın
3. "Sync Project with Gradle Files" yapın
4. Build → Make Project

## Yaygın Hatalar ve Çözümleri

### "Execution failed for task ':app:processDebugGoogleServices'"

**Çözüm:** `google-services.json` dosyasının doğru yerde olduğundan emin olun:
- `android/app/google-services.json`

### "minSdkVersion flutter.minSdkVersion" hatası

**Çözüm:** `android/app/build.gradle` dosyasında `minSdkVersion` zaten düzeltildi.

### Kotlin versiyon uyarıları

**Çözüm:** Kotlin versiyonu 1.9.22'ye güncellendi.

## Hala Sorun mu Var?

1. `flutter doctor -v` çıktısını kontrol edin
2. Gradle loglarını inceleyin: `flutter run --verbose`
3. Android Studio'da "Build" → "Clean Project" yapın
4. Projeyi yeniden oluşturmayı deneyin

## Destek

Sorunlarınız için: support@zirvego.com
