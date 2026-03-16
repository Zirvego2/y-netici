# Firestore Index Kurulum Rehberi

## Gerekli Index'ler

Mobil uygulama için aşağıdaki Firestore composite index'ler gereklidir:

### 1. Yeni Siparişler Sorgusu İçin

**Sorgu:**
```dart
.where('s_courier', isEqualTo: 0)
.where('s_stat', whereIn: [0, 4])
.where('s_bay', isEqualTo: bayId)
.orderBy('s_cdate', descending: true)
```

**Index:**
- Collection: `t_orders`
- Fields:
  1. `s_courier` (ASCENDING)
  2. `s_stat` (ASCENDING)
  3. `s_bay` (ASCENDING)
  4. `s_cdate` (DESCENDING)

### 2. Yoldaki Siparişler Sorgusu İçin

**Sorgu:**
```dart
.where('s_bay', isEqualTo: bayId)
.where('s_courier', isGreaterThan: 0)
.where('s_stat', whereIn: [0, 1, 4])
.orderBy('s_cdate', descending: true)
```

**Index:**
- Collection: `t_orders`
- Fields:
  1. `s_bay` (ASCENDING)
  2. `s_courier` (ASCENDING)
  3. `s_stat` (ASCENDING)
  4. `s_cdate` (DESCENDING)

## Index'leri Oluşturma Yöntemleri

### Yöntem 1: Firebase Console'dan (Önerilen)

1. Firebase Console'a gidin: https://console.firebase.google.com
2. Projenizi seçin
3. Sol menüden **Firestore Database** > **Indexes** sekmesine gidin
4. **Create Index** butonuna tıklayın
5. Her iki index'i yukarıdaki bilgilere göre oluşturun

### Yöntem 2: Firebase CLI ile

1. Terminal'de proje root dizinine gidin
2. `firestore.indexes.json` dosyası güncellendi (zaten yapıldı)
3. Şu komutu çalıştırın:
   ```bash
   firebase deploy --only firestore:indexes
   ```

### Yöntem 3: Hata Mesajından Link

Eğer uygulamada index hatası alırsanız:
1. Terminal'deki hata mesajında bir link göreceksiniz
2. Bu linke tıklayarak direkt index oluşturma sayfasına gidebilirsiniz
3. **Create Index** butonuna tıklayın

## Index Oluşturma Süresi

- Index'ler genellikle birkaç dakika içinde oluşturulur
- Büyük koleksiyonlarda (100K+ doküman) 10-30 dakika sürebilir
- Index oluşturulana kadar sorgular çalışmayabilir

## Index Durumunu Kontrol Etme

Firebase Console > Firestore Database > Indexes sekmesinden:
- **Building**: Index oluşturuluyor
- **Enabled**: Index hazır, sorgular çalışabilir
- **Error**: Hata var, kontrol edin

## Notlar

- Index'ler otomatik olarak oluşturulmaz, manuel oluşturulmalıdır
- Her farklı sorgu kombinasyonu için ayrı index gerekebilir
- Index'ler Firestore okuma maliyetini etkilemez, sadece performansı artırır
