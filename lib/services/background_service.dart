import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';
import 'dart:convert';

/// Arka planda çalışacak görevler için callback
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('📱 BackgroundService: Görev başlatıldı - $task');
      
      if (task == 'checkNewOrders') {
        await _checkNewOrdersInBackground();
      }
      
      return Future.value(true);
    } catch (e) {
      debugPrint('❌ BackgroundService: Hata - $e');
      return Future.value(false);
    }
  });
}

/// Arka planda yeni siparişleri kontrol et
Future<void> _checkNewOrdersInBackground() async {
  try {
    debugPrint('📱 BackgroundService: Yeni siparişler kontrol ediliyor...');
    
    // Firebase'i başlat (eğer başlatılmamışsa)
    try {
      Firebase.app();
    } catch (e) {
      debugPrint('📱 BackgroundService: Firebase başlatılıyor...');
      // Firebase config'i almak için utils'e ihtiyaç var, ama background'da çalışmayabilir
      // Bu durumda Firebase zaten başlatılmış olmalı
    }
    
    // Bildirim ayarını kontrol et
    final prefs = await SharedPreferences.getInstance();
    final newOrderNotificationsEnabled = prefs.getBool('new_order_notifications_enabled') ?? true;
    
    if (!newOrderNotificationsEnabled) {
      debugPrint('📱 BackgroundService: Yeni sipariş bildirimleri kapalı');
      return;
    }
    
    // Son kontrol edilen sipariş ID'lerini al
    final lastCheckedIdsJson = prefs.getString('last_checked_order_ids') ?? '[]';
    final lastCheckedIds = List<int>.from(jsonDecode(lastCheckedIdsJson));
    
    // Bay ID'yi al (varsayılan: 1)
    final bayId = prefs.getInt('current_bay_id') ?? 1;
    
    // Firestore'dan yeni siparişleri çek
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('t_orders')
        .where('s_courier', isEqualTo: 0)
        .where('s_stat', whereIn: [0, 4])
        .where('s_bay', isEqualTo: bayId)
        .orderBy('s_cdate', descending: true)
        .limit(10)
        .get();
    
    debugPrint('📱 BackgroundService: ${snapshot.docs.length} sipariş bulundu');
    
    final newOrderIds = <int>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final orderId = data['s_id'] as int?;
      if (orderId != null && !lastCheckedIds.contains(orderId)) {
        newOrderIds.add(orderId);
        
        // Bildirim gönder
        // Restoran adını t_work'ten çekmeye çalış
        String restaurantName = 'Yeni Sipariş';
        try {
          final workId = data['s_work'] as int?;
          if (workId != null && workId > 0) {
            final workDoc = await firestore
                .collection('t_work')
                .where('s_id', isEqualTo: workId)
                .limit(1)
                .get();
            if (workDoc.docs.isNotEmpty) {
              final workData = workDoc.docs[0].data();
              restaurantName = workData['s_name'] ?? 'Restoran #$workId';
            } else {
              restaurantName = 'Restoran #$workId';
            }
          }
        } catch (e) {
          debugPrint('⚠️ BackgroundService: Restoran adı alınamadı: $e');
          restaurantName = 'Yeni Sipariş';
        }
        
        final customerData = data['s_customer'] as Map<String, dynamic>?;
        final address = customerData?['ss_adres'] as String?;
        
        await NotificationService().showNewOrderNotification(
          orderId: orderId,
          restaurantName: restaurantName,
          address: address,
        );
        
        debugPrint('📱 BackgroundService: Yeni sipariş bildirimi gönderildi - #$orderId');
      }
    }
    
    // Son kontrol edilen ID'leri güncelle
    if (newOrderIds.isNotEmpty) {
      final updatedIds = [...lastCheckedIds, ...newOrderIds];
      // Son 50 ID'yi tut (bellek tasarrufu için)
      final trimmedIds = updatedIds.length > 50 
          ? updatedIds.sublist(updatedIds.length - 50)
          : updatedIds;
      await prefs.setString('last_checked_order_ids', jsonEncode(trimmedIds));
    }
    
    debugPrint('📱 BackgroundService: ${newOrderIds.length} yeni sipariş tespit edildi');
  } catch (e) {
    debugPrint('❌ BackgroundService: Hata - $e');
  }
}

/// Background service'i başlat
Future<void> initializeBackgroundService() async {
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  
  // Periyodik görev kaydet (her 15 dakikada bir - Android minimum)
  // Not: Android'de minimum interval 15 dakika, iOS'ta daha kısa olabilir
  await Workmanager().registerPeriodicTask(
    'checkNewOrders',
    'checkNewOrders',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    initialDelay: const Duration(seconds: 10), // İlk kontrol 10 saniye sonra
  );
  
  debugPrint('📱 BackgroundService: Başlatıldı - Her 15 dakikada bir kontrol edilecek');
}

/// Background service'i durdur
Future<void> stopBackgroundService() async {
  await Workmanager().cancelByUniqueName('checkNewOrders');
  debugPrint('📱 BackgroundService: Durduruldu');
}
