import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/courier_info.dart';

class CourierService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<int, CourierInfo> _cache = {};

  // Courier bilgisini cache'ten veya Firestore'dan getir
  Future<CourierInfo?> getCourierInfo(int courierId) async {
    if (courierId == 0) return null; // Atanmamış kurye

    // Cache'te varsa direkt dön
    if (_cache.containsKey(courierId)) {
      return _cache[courierId];
    }

    // Firestore'dan çek
    try {
      final querySnapshot = await _firestore
          .collection('t_courier')
          .where('s_id', isEqualTo: courierId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final courierData = querySnapshot.docs[0].data();
      final courierInfo = CourierInfo.fromMap(courierData);
      
      // Cache'e ekle
      _cache[courierId] = courierInfo;
      
      return courierInfo;
    } catch (e) {
      print('CourierService error: $e');
      return null;
    }
  }

  // Birden fazla courier bilgisini toplu çek
  Future<Map<int, CourierInfo>> getCourierInfos(List<int> courierIds) async {
    final Map<int, CourierInfo> result = {};
    final List<int> missingIds = courierIds.where((id) => id > 0).toList();

    // Önce cache'ten kontrol et
    for (final courierId in missingIds) {
      if (_cache.containsKey(courierId)) {
        result[courierId] = _cache[courierId]!;
      }
    }

    // Cache'te olmayanları bul
    final toFetch = missingIds.where((id) => !result.containsKey(id)).toList();

    // Firestore'dan çek
    if (toFetch.isNotEmpty) {
      try {
        // Firestore'da 'in' operatörü maksimum 10 değer alabilir
        for (int i = 0; i < toFetch.length; i += 10) {
          final batch = toFetch.skip(i).take(10).toList();
          final querySnapshot = await _firestore
              .collection('t_courier')
              .where('s_id', whereIn: batch)
              .get();

          for (final doc in querySnapshot.docs) {
            final courierData = doc.data();
            final courierInfo = CourierInfo.fromMap(courierData);
            result[courierInfo.sId] = courierInfo;
            _cache[courierInfo.sId] = courierInfo;
          }
        }
      } catch (e) {
        print('CourierService batch error: $e');
      }
    }

    return result;
  }

  // Bayiye ait tüm kuryeleri getir
  Future<List<CourierInfo>> getCouriersByBay(int bayId) async {
    try {
      final querySnapshot = await _firestore
          .collection('t_courier')
          .where('s_bay', isEqualTo: bayId)
          .get();

      final couriers = querySnapshot.docs.map((doc) {
        final data = doc.data();
        final courierInfo = CourierInfo.fromMap(data);
        _cache[courierInfo.sId] = courierInfo;
        return courierInfo;
      }).toList();

      return couriers;
    } catch (e) {
      print('CourierService getCouriersByBay error: $e');
      return [];
    }
  }

  // Kurye status'ünü güncelle
  Future<bool> updateCourierStatus(int courierId, int newStatus) async {
    try {
      final querySnapshot = await _firestore
          .collection('t_courier')
          .where('s_id', isEqualTo: courierId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return false;
      }

      final docRef = querySnapshot.docs[0].reference;
      await docRef.update({
        's_stat': newStatus,
      });

      // Cache'i güncelle
      if (_cache.containsKey(courierId)) {
        final oldCourier = _cache[courierId]!;
        final updatedCourier = CourierInfo(
          sId: oldCourier.sId,
          name: oldCourier.name,
          surname: oldCourier.surname,
          phone: oldCourier.phone,
          status: newStatus,
        );
        _cache[courierId] = updatedCourier;
      }

      return true;
    } catch (e) {
      print('CourierService updateStatus error: $e');
      return false;
    }
  }

  // Cache'i temizle
  void clearCache() {
    _cache.clear();
  }
}
