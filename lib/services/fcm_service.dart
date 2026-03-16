import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';
import '../utils/firebase_config.dart';

/// Firebase Cloud Messaging servisi
/// FCM token'ı yönetir ve push notification'ları işler
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// FCM servisini başlat
  Future<void> initialize() async {
    try {
      // Bildirim izni iste (Android 13+ için gerekli)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('📱 FCM İzin durumu: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ FCM izni verildi');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ FCM geçici izin verildi');
      } else {
        debugPrint('❌ FCM izni reddedildi');
        return;
      }

      // FCM token'ı al
      await _getFCMToken();

      // Token yenilendiğinde güncelle
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token yenilendi: ${newToken.substring(0, 20)}...');
        _fcmToken = newToken;
        saveTokenToFirestore(newToken);
      });

      // Foreground mesajları dinleme kaldırıldı
      // Sadece Cloud Functions'tan gelen bildirimler gösterilecek (arka planda/kapalıyken)
      // FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Not: Background message handler main() içinde kayıt edilmeli
      // FirebaseMessaging.onBackgroundMessage() sadece main() içinde çağrılabilir

      // Bildirime tıklandığında
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleMessageOpenedApp(message);
      });

      // Uygulama kapalıyken bildirime tıklandıysa kontrol et
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        await _handleMessageOpenedApp(initialMessage);
      }
    } catch (e) {
      debugPrint('❌ FCM initialize hatası: $e');
    }
  }

  /// FCM token'ı al
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        debugPrint('✅ FCM Token alındı: ${_fcmToken!.substring(0, 20)}...');
        await saveTokenToFirestore(_fcmToken!);
      } else {
        debugPrint('⚠️ FCM Token alınamadı');
      }
    } catch (e) {
      debugPrint('❌ FCM Token alma hatası: $e');
    }
  }

  /// Token'ı Firestore'a kaydet (t_bay collection'ında admin kullanıcısına)
  Future<void> saveTokenToFirestore(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminDataString = prefs.getString('adminData');
      
      if (adminDataString == null) {
        debugPrint('⚠️ Admin data bulunamadı, token kaydedilemedi');
        return;
      }

      // JSON decode
      final Map<String, dynamic> adminDataMap;
      try {
        adminDataMap = jsonDecode(adminDataString) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('❌ Admin data parse hatası: $e');
        return;
      }

      final adminId = adminDataMap['s_id'] as int?;
      if (adminId == null) {
        debugPrint('⚠️ Admin ID bulunamadı');
        return;
      }

      // t_bay collection'ında admin kullanıcısını bul ve fcmToken'ı güncelle
      final querySnapshot = await _firestore
          .collection('t_bay')
          .where('s_id', isEqualTo: adminId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs[0].reference.update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ FCM Token Firestore\'a kaydedildi (Admin ID: $adminId)');
      } else {
        debugPrint('⚠️ Admin kullanıcısı bulunamadı (ID: $adminId)');
      }
    } catch (e) {
      debugPrint('❌ FCM Token Firestore kayıt hatası: $e');
    }
  }

  /// Foreground mesaj işleme (uygulama açıkken) - KALDIRILDI
  /// Sadece Cloud Functions'tan gelen bildirimler gösterilecek (arka planda/kapalıyken)
  // void _handleForegroundMessage(RemoteMessage message) {
  //   debugPrint('📱 Foreground mesaj alındı: ${message.messageId}');
  //   // Bildirim gösterilmiyor - sadece background/terminated durumda gösterilecek
  // }


  /// Bildirime tıklandığında
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    debugPrint('📱 Bildirime tıklandı: ${message.messageId}');
    
    // Bildirime tıklanarak açılan sipariş ID'sini kaydet
    // Böylece uygulama açıldığında tekrar bildirim gösterilmeyecek
    final orderId = int.tryParse(message.data['orderId'] ?? '0') ?? 0;
    if (orderId > 0) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final seenOrderIds = prefs.getStringList('seen_order_ids_from_notification') ?? [];
        seenOrderIds.add(orderId.toString());
        await prefs.setStringList('seen_order_ids_from_notification', seenOrderIds);
        debugPrint('✅ Bildirime tıklanan sipariş ID kaydedildi: $orderId');
      } catch (e) {
        debugPrint('❌ Bildirime tıklanan sipariş ID kayıt hatası: $e');
      }
    }
    
    // Burada sipariş detay sayfasına yönlendirme yapılabilir
    // Şimdilik sadece log
  }

  /// Token'ı sil (logout'ta kullanılabilir)
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;
      debugPrint('✅ FCM Token silindi');
    } catch (e) {
      debugPrint('❌ FCM Token silme hatası: $e');
    }
  }
}

/// Arka planda mesaj işleme (top-level function - Flutter gereksinimi)
/// Bu fonksiyon uygulama kapalıyken veya arka plandayken gelen FCM mesajlarını işler
@pragma('vm:entry-point')
Future<void> fcmBackgroundMessageHandler(RemoteMessage message) async {
  try {
    // Firebase'i başlat (background'da gerekebilir)
    try {
      Firebase.app();
      debugPrint('📱 Background: Firebase zaten başlatılmış');
    } catch (e) {
      debugPrint('📱 Background: Firebase başlatılıyor...');
      await Firebase.initializeApp(
        options: FirebaseConfig.getFirebaseOptions(),
      );
      debugPrint('📱 Background: Firebase başlatıldı');
    }
    
    debugPrint('📱 Background mesaj alındı: ${message.messageId}');
    debugPrint('📱 Background mesaj data: ${message.data}');
    debugPrint('📱 Background mesaj notification: ${message.notification?.title} - ${message.notification?.body}');
    
    // NotificationService'i başlat
    await NotificationService().initialize();
    
    // Bildirim göster
    // Android'de notification payload varsa otomatik gösterilir, ama biz yine de local notification gösterelim
    final orderId = int.tryParse(message.data['orderId'] ?? '0') ?? 0;
    final restaurantName = message.notification?.title ?? 
                          message.data['title'] ?? 
                          'Yeni Sipariş';
    final address = message.notification?.body ?? 
                   message.data['body'] ?? 
                   'Adres bilgisi yok';
    
    debugPrint('📱 Background bildirim gösteriliyor: orderId=$orderId, restaurant=$restaurantName');
    
    await NotificationService().showNewOrderNotification(
      orderId: orderId,
      restaurantName: restaurantName,
      address: address,
    );
    
    debugPrint('✅ Background bildirim gösterildi');
  } catch (e, stackTrace) {
    debugPrint('❌ Background bildirim hatası: $e');
    debugPrint('❌ Stack trace: $stackTrace');
  }
}
