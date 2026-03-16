import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bay_info.dart';

class BayService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<int, BayInfo> _cache = {};

  // Bay bilgisini cache'ten veya Firestore'dan getir
  Future<BayInfo?> getBayInfo(int bayId) async {
    if (bayId == 0) return null;

    // Cache'te varsa direkt dön
    if (_cache.containsKey(bayId)) {
      return _cache[bayId];
    }

    // Firestore'dan çek
    try {
      final querySnapshot = await _firestore
          .collection('t_bay')
          .where('s_id', isEqualTo: bayId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final bayData = querySnapshot.docs[0].data();
      final bayInfo = BayInfo.fromMap(bayData);
      
      // Cache'e ekle
      _cache[bayId] = bayInfo;
      
      return bayInfo;
    } catch (e) {
      print('BayService error: $e');
      return null;
    }
  }

  // Birden fazla bay bilgisini toplu çek
  Future<Map<int, BayInfo>> getBayInfos(List<int> bayIds) async {
    final Map<int, BayInfo> result = {};
    final List<int> missingIds = bayIds.where((id) => id > 0).toList();

    // Önce cache'ten kontrol et
    for (final bayId in missingIds) {
      if (_cache.containsKey(bayId)) {
        result[bayId] = _cache[bayId]!;
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
              .collection('t_bay')
              .where('s_id', whereIn: batch)
              .get();

          for (final doc in querySnapshot.docs) {
            final bayData = doc.data();
            final bayInfo = BayInfo.fromMap(bayData);
            result[bayInfo.sId] = bayInfo;
            _cache[bayInfo.sId] = bayInfo;
          }
        }
      } catch (e) {
        print('BayService batch error: $e');
      }
    }

    return result;
  }

  // Cache'i temizle
  void clearCache() {
    _cache.clear();
  }
}
