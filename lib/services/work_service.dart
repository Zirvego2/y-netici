import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/work_info.dart';

class WorkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<int, WorkInfo> _cache = {};

  // Work bilgisini cache'ten veya Firestore'dan getir
  Future<WorkInfo?> getWorkInfo(int workId) async {
    // Cache'te varsa direkt dön
    if (_cache.containsKey(workId)) {
      return _cache[workId];
    }

    // Firestore'dan çek
    try {
      final querySnapshot = await _firestore
          .collection('t_work')
          .where('s_id', isEqualTo: workId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final workData = querySnapshot.docs[0].data();
      final workInfo = WorkInfo.fromMap(workData);
      
      // Cache'e ekle
      _cache[workId] = workInfo;
      
      return workInfo;
    } catch (e) {
      print('WorkService error: $e');
      return null;
    }
  }

  // Birden fazla work bilgisini toplu çek
  Future<Map<int, WorkInfo>> getWorkInfos(List<int> workIds) async {
    final Map<int, WorkInfo> result = {};
    final List<int> missingIds = [];

    // Önce cache'ten kontrol et
    for (final workId in workIds) {
      if (_cache.containsKey(workId)) {
        result[workId] = _cache[workId]!;
      } else {
        missingIds.add(workId);
      }
    }

    // Cache'te olmayanları Firestore'dan çek
    if (missingIds.isNotEmpty) {
      try {
        // Firestore'da 'in' operatörü maksimum 10 değer alabilir, bu yüzden batch'ler halinde çek
        for (int i = 0; i < missingIds.length; i += 10) {
          final batch = missingIds.skip(i).take(10).toList();
          final querySnapshot = await _firestore
              .collection('t_work')
              .where('s_id', whereIn: batch)
              .get();

          for (final doc in querySnapshot.docs) {
            final workData = doc.data();
            final workInfo = WorkInfo.fromMap(workData);
            result[workInfo.sId] = workInfo;
            _cache[workInfo.sId] = workInfo;
          }
        }
      } catch (e) {
        print('WorkService batch error: $e');
      }
    }

    return result;
  }

  // Cache'i temizle
  void clearCache() {
    _cache.clear();
  }
}
