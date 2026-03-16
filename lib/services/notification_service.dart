import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Bildirim servisini başlat
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('📱 NotificationService: Zaten başlatılmış');
      return;
    }

    debugPrint('📱 NotificationService: Başlatılıyor...');

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final bool? initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    debugPrint('📱 NotificationService: Initialize sonucu: $initialized');

    // Android için bildirim kanalı oluştur
    await _createNotificationChannel();

    // Android 13+ için izin kontrolü
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      debugPrint('📱 NotificationService: Android izin durumu: $granted');
    }

    _initialized = true;
    debugPrint('📱 NotificationService: Başlatma tamamlandı');
  }

  // Bildirim iznini kontrol et ve gerekirse iste
  Future<bool> requestPermissionIfNeeded() async {
    if (!_initialized) {
      await initialize();
    }

    // Android için izin kontrolü
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.areNotificationsEnabled();
      final isGranted = granted ?? false;
      debugPrint('📱 NotificationService: Mevcut izin durumu: $isGranted');
      
      if (!isGranted) {
        debugPrint('📱 NotificationService: İzin isteniyor...');
        final requested = await androidImplementation.requestNotificationsPermission();
        final isRequested = requested ?? false;
        debugPrint('📱 NotificationService: İzin isteme sonucu: $isRequested');
        return isRequested;
      }
      return true;
    }

    // iOS için izin kontrolü
    final iosImplementation = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return false;
  }

  // Android bildirim kanalı oluştur
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'new_orders_channel', // id
      'Yeni Sipariş Bildirimleri', // name
      description: 'Yeni sipariş geldiğinde bildirim gösterir',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Bildirim tıklandığında
  void _onNotificationTapped(NotificationResponse response) {
    // Burada uygulamayı açmak için navigasyon yapılabilir
    debugPrint('Bildirim tıklandı: ${response.payload}');
  }

  // Yeni sipariş bildirimi gönder
  Future<void> showNewOrderNotification({
    required int orderId,
    required String restaurantName,
    String? address,
  }) async {
    debugPrint('📱 NotificationService: Bildirim gönderiliyor - Sipariş #$orderId');
    
    if (!_initialized) {
      debugPrint('📱 NotificationService: Henüz başlatılmamış, başlatılıyor...');
      await initialize();
    }

    // Android için izin kontrolü
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.areNotificationsEnabled();
      final isGranted = granted ?? false;
      debugPrint('📱 NotificationService: Android bildirimler aktif mi: $isGranted');
      if (!isGranted) {
        debugPrint('⚠️ NotificationService: Android bildirim izni yok!');
        final requested = await androidImplementation.requestNotificationsPermission();
        final isRequested = requested ?? false;
        debugPrint('📱 NotificationService: İzin istendi, sonuç: $isRequested');
        if (!isRequested) {
          debugPrint('❌ NotificationService: Bildirim izni verilmedi, bildirim gönderilemiyor');
          return;
        }
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'new_orders_channel',
      'Yeni Sipariş Bildirimleri',
      channelDescription: 'Yeni sipariş geldiğinde bildirim gösterir',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      // Bildirim ID'si 32-bit integer olmalı, sipariş ID'si çok büyük olabilir
      // Sipariş ID'sini hash'leyerek 32-bit integer'a dönüştür
      final notificationId = _generateNotificationId(orderId);
      
      await _notifications.show(
        notificationId, // 32-bit integer ID
        'Yeni Sipariş Geldi!',
        'Sipariş #$orderId - $restaurantName${address != null ? '\n$address' : ''}',
        details,
        payload: 'order_$orderId',
      );
      debugPrint('✅ NotificationService: Bildirim başarıyla gönderildi - Sipariş #$orderId (ID: $notificationId)');
    } catch (e) {
      debugPrint('❌ NotificationService: Bildirim gönderme hatası: $e');
    }
  }

  // Sipariş ID'sini 32-bit integer'a dönüştür (hash kullanarak)
  int _generateNotificationId(int orderId) {
    // Sipariş ID'sini hash'leyerek 32-bit integer'a dönüştür
    // Java hashCode benzeri bir yaklaşım kullanıyoruz
    final idString = orderId.toString();
    int hash = 0;
    for (int i = 0; i < idString.length; i++) {
      hash = ((hash << 5) - hash) + idString.codeUnitAt(i);
      hash = hash & hash; // 32-bit integer'a dönüştür
    }
    // Pozitif bir sayı elde etmek için mutlak değer al
    final positiveHash = hash.abs();
    // 32-bit integer sınırları içinde olduğundan emin ol (max: 2147483647)
    return positiveHash % 2147483647;
  }

  // Bildirimleri temizle
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // Belirli bir bildirimi iptal et
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
