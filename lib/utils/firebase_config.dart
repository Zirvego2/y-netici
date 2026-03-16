import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  // Firebase yapılandırması
  // Bu değerler environment variables veya config dosyasından alınmalı
  static FirebaseOptions getFirebaseOptions() {
    return const FirebaseOptions(
      apiKey: "YOUR_API_KEY", // .env'den alınacak
      authDomain: "zirvenew.firebaseapp.com",
      projectId: "zirvenew",
      storageBucket: "zirvenew.appspot.com",
      messagingSenderId: "YOUR_SENDER_ID", // .env'den alınacak
      appId: "YOUR_APP_ID", // .env'den alınacak
      measurementId: "YOUR_MEASUREMENT_ID", // .env'den alınacak (opsiyonel)
    );
  }
}
