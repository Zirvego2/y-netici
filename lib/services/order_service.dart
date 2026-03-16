import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart' as order_model;
import 'work_service.dart';
import 'courier_service.dart';
import 'bay_service.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WorkService _workService = WorkService();
  final CourierService _courierService = CourierService();
  final BayService _bayService = BayService();

  // Yeni siparişler stream'i (atanmamış)
  Stream<List<order_model.Order>> getNewOrdersStream(int bayId) {
    print('🔍 OrderService: getNewOrdersStream called with bayId: $bayId');
    return _firestore
        .collection('t_orders')
        .where('s_courier', isEqualTo: 0)
        .where('s_stat', whereIn: [0, 4])
        .where('s_bay', isEqualTo: bayId)
        .orderBy('s_cdate', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snapshot) async {
          try {
            print('🔍 OrderService: Snapshot received, docs count: ${snapshot.docs.length}');
            if (snapshot.docs.isEmpty) {
              print('⚠️ OrderService: No documents found. Checking query...');
              // Test query - tüm siparişleri kontrol et
              final testQuery = await _firestore
                  .collection('t_orders')
                  .where('s_bay', isEqualTo: bayId)
                  .limit(5)
                  .get();
              print('🔍 OrderService: Test query (all orders with bayId=$bayId): ${testQuery.docs.length} documents');
              
              // Bay ID olmadan test
              final testQuery2 = await _firestore
                  .collection('t_orders')
                  .limit(5)
                  .get();
              print('🔍 OrderService: Test query (all orders): ${testQuery2.docs.length} documents');
              if (testQuery2.docs.isNotEmpty) {
                final sampleDoc = testQuery2.docs[0].data();
                print('🔍 OrderService: Sample order s_bay value: ${sampleDoc['s_bay']} (type: ${sampleDoc['s_bay'].runtimeType})');
                print('🔍 OrderService: Sample order s_stat value: ${sampleDoc['s_stat']}');
                print('🔍 OrderService: Sample order s_courier value: ${sampleDoc['s_courier']}');
              }
            }
            return await _processOrders(snapshot.docs);
          } catch (e, stackTrace) {
            print('❌ OrderService getNewOrdersStream error: $e');
            print('❌ Stack trace: $stackTrace');
            return <order_model.Order>[];
          }
        });
  }

  // Yoldaki siparişler stream'i (atanmış)
  Stream<List<order_model.Order>> getInTransitOrdersStream(int bayId) {
    print('🔍 OrderService: getInTransitOrdersStream called with bayId: $bayId');
    return _firestore
        .collection('t_orders')
        .where('s_bay', isEqualTo: bayId)
        .where('s_courier', isGreaterThan: 0)
        .where('s_stat', whereIn: [0, 1, 4])
        .orderBy('s_cdate', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snapshot) async {
          try {
            print('🔍 OrderService: InTransit Snapshot received, docs count: ${snapshot.docs.length}');
            return await _processOrders(snapshot.docs);
          } catch (e, stackTrace) {
            print('❌ OrderService getInTransitOrdersStream error: $e');
            print('❌ Stack trace: $stackTrace');
            return <order_model.Order>[];
          }
        });
  }

  // Siparişleri işle ve ilişkili verileri ekle
  Future<List<order_model.Order>> _processOrders(List<DocumentSnapshot> docs) async {
    if (docs.isEmpty) return [];

    // Tüm siparişleri parse et
    final orders = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'doc': doc,
        'workId': data['s_work'] ?? 0,
        'courierId': data['s_courier'] ?? 0,
        'bayId': data['s_bay'] ?? 0,
      };
    }).toList();

    // Tüm work, courier ve bay ID'lerini topla
    final workIds = orders.map((o) => o['workId'] as int).where((id) => id > 0).toSet().toList();
    final courierIds = orders.map((o) => o['courierId'] as int).where((id) => id > 0).toSet().toList();
    final bayIds = orders.map((o) => o['bayId'] as int).where((id) => id > 0).toSet().toList();

    // Toplu çek (cache mekanizması içinde)
    final workInfos = await _workService.getWorkInfos(workIds);
    final courierInfos = await _courierService.getCourierInfos(courierIds);
    final bayInfos = await _bayService.getBayInfos(bayIds);

    // Siparişleri oluştur ve ilişkili verileri ekle
    return orders.map((orderData) {
      final doc = orderData['doc'] as DocumentSnapshot;
      final workId = orderData['workId'] as int;
      final courierId = orderData['courierId'] as int;
      final bayId = orderData['bayId'] as int;

      return order_model.Order.fromFirestore(
        doc,
        workInfo: workInfos[workId],
        courierInfo: courierInfos[courierId],
        bayInfo: bayInfos[bayId],
      );
    }).toList();
  }

  // Tek bir sipariş getir
  Future<order_model.Order?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('t_orders').doc(orderId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      final workId = data['s_work'] ?? 0;
      final courierId = data['s_courier'] ?? 0;
      final bayId = data['s_bay'] ?? 0;

      final workInfo = workId > 0 ? await _workService.getWorkInfo(workId) : null;
      final courierInfo = courierId > 0 ? await _courierService.getCourierInfo(courierId) : null;
      final bayInfo = bayId > 0 ? await _bayService.getBayInfo(bayId) : null;

      return order_model.Order.fromFirestore(
        doc,
        workInfo: workInfo,
        courierInfo: courierInfo,
        bayInfo: bayInfo,
      );
    } catch (e) {
      print('OrderService getOrderById error: $e');
      return null;
    }
  }

  // Kurye ata veya değiştir
  Future<bool> assignCourier(String orderId, int courierId) async {
    try {
      await _firestore.collection('t_orders').doc(orderId).update({
        's_courier': courierId,
        's_assigned_time': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('OrderService assignCourier error: $e');
      return false;
    }
  }

  // Kurye atamasını kaldır
  Future<bool> unassignCourier(String orderId) async {
    try {
      await _firestore.collection('t_orders').doc(orderId).update({
        's_courier': 0,
        's_assigned_time': FieldValue.delete(),
      });
      return true;
    } catch (e) {
      print('OrderService unassignCourier error: $e');
      return false;
    }
  }

  // Manual teslim (s_stat = 2)
  Future<bool> manualDeliver(String orderId) async {
    try {
      await _firestore.collection('t_orders').doc(orderId).update({
        's_stat': 2,
        's_delivered_time': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('OrderService manualDeliver error: $e');
      return false;
    }
  }

  // Paket iptal (s_stat = 3)
  Future<bool> cancelOrder(String orderId) async {
    try {
      await _firestore.collection('t_orders').doc(orderId).update({
        's_stat': 3,
        's_cancelled_time': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('OrderService cancelOrder error: $e');
      return false;
    }
  }
}
