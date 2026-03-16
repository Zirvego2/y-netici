# Google Maps Kurulum Rehberi

## Google Maps API Key Alma

1. Google Cloud Console'a gidin: https://console.cloud.google.com
2. Projenizi seçin (veya yeni proje oluşturun)
3. **APIs & Services** > **Library** sekmesine gidin
4. **Maps SDK for Android** ve **Maps SDK for iOS** API'lerini etkinleştirin
5. **APIs & Services** > **Credentials** sekmesine gidin
6. **Create Credentials** > **API Key** seçin
7. API key'i kopyalayın

## Android Konfigürasyonu

1. `android/app/src/main/AndroidManifest.xml` dosyasını açın
2. `YOUR_GOOGLE_MAPS_API_KEY` yerine gerçek API key'inizi yazın:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSy..."/>
```

## iOS Konfigürasyonu

1. `ios/Runner/AppDelegate.swift` dosyası oluşturuldu
2. Google Maps API key'i eklendi:

```swift
GMSServices.provideAPIKey("AIzaSyBpgppKBVULdvG8yHq8F57TljP9PpXTvCM")
```

3. `Info.plist` dosyasına konum izinleri eklendi:
   - `NSLocationWhenInUseUsageDescription`
   - `NSLocationAlwaysUsageDescription`

## API Key Kısıtlamaları (Önerilen)

Güvenlik için API key'inize kısıtlama ekleyin:

1. Google Cloud Console > **APIs & Services** > **Credentials**
2. API key'inize tıklayın
3. **Application restrictions** altında:
   - Android: Package name: `com.zirvego.mainapp`
   - iOS: Bundle ID: `com.zirvego.mainapp`
4. **API restrictions** altında:
   - Sadece **Maps SDK for Android** ve **Maps SDK for iOS** seçin

## Notlar

- API key olmadan harita çalışmaz
- Test için development key kullanabilirsiniz
- Production için mutlaka kısıtlama ekleyin
