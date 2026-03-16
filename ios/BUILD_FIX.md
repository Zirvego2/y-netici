# iOS Build -G Hatası Çözümü

## Sorun
`Error (Xcode): unsupported option '-G' for target 'arm64-apple-ios15.0'`

## Neden
Bu hata genellikle Flutter SDK sürümü veya Xcode build tools ile ilgilidir. Flutter'ın native kod derlemesi sırasında `-G` flag'i kullanılıyor ancak bu flag iOS için desteklenmiyor.

## Çözüm

### 1. Flutter SDK Sürümünü Kontrol Edin
CI/CD pipeline'ınızda Flutter sürümünü kontrol edin:
```bash
flutter --version
```

**Önerilen:** Flutter 3.10+ veya 3.16+ kullanın.

### 2. CI/CD Pipeline'ında Flutter Sürümünü Sabitleyin

#### Codemagic
✅ `codemagic.yaml` dosyası oluşturuldu ve Flutter sürümü 3.16.0 olarak sabitlendi.
```yaml
workflows:
  ios-workflow:
    environment:
      flutter: "3.16.0"  # -G hatasını önlemek için güncel Flutter sürümü
      xcode: latest
```

#### GitHub Actions
```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.16.0'
    channel: 'stable'
```

#### Bitrise
```yaml
- flutter-install@1:
    inputs:
    - flutter_version: "3.16.0"
```

### 3. Build Öncesi Temizlik
```bash
flutter clean
cd ios
rm -rf Pods Podfile.lock .symlinks
pod install
cd ..
flutter pub get
```

### 4. Build Komutu
```bash
flutter build ios --release --no-codesign
```

## Yapılan Değişiklikler

1. ✅ iOS deployment target: 15.0
2. ✅ Debug sembol üretimi devre dışı (`GCC_GENERATE_DEBUGGING_SYMBOLS = NO`)
3. ✅ Debug bilgi formatı: `dwarf`
4. ✅ Podfile'da `-G` flag'i temizleniyor
5. ✅ Xcode build settings'te `OTHER_CFLAGS` ve `OTHER_CPLUSPLUSFLAGS` eklendi

## Not
Eğer hata devam ederse, CI/CD ortamındaki Flutter SDK sürümünü güncelleyin. Flutter 3.0+ sürümlerinde bu sorun genellikle çözülmüş durumda.
