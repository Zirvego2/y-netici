import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_info.dart';
import 'payment_info.dart';
import 'work_info.dart';
import 'courier_info.dart';
import 'bay_info.dart';

class Order {
  final String id; // Firebase document ID
  final int sId; // Sipariş numarası
  final String? orderNumber; // s_orderid
  final int sStat; // Durum: -1, 0, 1, 2, 3, 4
  final int sCourier; // Kurye ID (0 = atanmamış)
  final int sOrderscr; // Platform: 0=Manuel, 1=Getir, 2=YemekSepeti, 3=Trendyol, 4=Migros
  final int sBay; // Bayi ID
  final int sWork; // İşletme ID
  final DateTime sCdate; // Oluşturulma zamanı
  final int sReadyMinutes; // Hazırlık süresi (dakika)
  final DateTime? sReadyTime; // Hazır olacağı zaman
  final DateTime? sAssignedTime; // Atama zamanı
  final DateTime? sReceivedTime; // Alınma zamanı
  final DateTime? sOnRoadTime; // Yola çıkış zamanı
  final double sDinstance; // Mesafe (km)

  // İlişkili veriler
  final CustomerInfo customer;
  final PaymentInfo payment;
  final WorkInfo? workInfo;
  final CourierInfo? courierInfo;
  final BayInfo? bayInfo;

  Order({
    required this.id,
    required this.sId,
    this.orderNumber,
    required this.sStat,
    required this.sCourier,
    required this.sOrderscr,
    required this.sBay,
    required this.sWork,
    required this.sCdate,
    required this.sReadyMinutes,
    this.sReadyTime,
    this.sAssignedTime,
    this.sReceivedTime,
    this.sOnRoadTime,
    required this.sDinstance,
    required this.customer,
    required this.payment,
    this.workInfo,
    this.courierInfo,
    this.bayInfo,
  });

  // Durum adı
  String get statusName {
    switch (sStat) {
      case -1:
        return 'Onay Bekliyor';
      case 0:
        return 'Hazır';
      case 1:
        return 'Yolda';
      case 2:
        return 'Teslim Edildi';
      case 3:
        return 'İptal Edildi';
      case 4:
        return 'İşletmede';
      default:
        return 'Bilinmiyor';
    }
  }

  // Platform adı
  String get platformName {
    switch (sOrderscr) {
      case 1:
        return 'Getir';
      case 2:
        return 'Yemek Sepeti';
      case 3:
        return 'Trendyol';
      case 4:
        return 'Migros';
      default:
        return 'Manuel';
    }
  }

  // Platform ikon path
  String? get platformIconPath {
    switch (sOrderscr) {
      case 0:
        return 'assets/images/manuel.png';
      case 1:
        return 'assets/images/getir.png';
      case 2:
        return 'assets/images/yemeksepeti.png';
      case 3:
        return 'assets/images/trendyol.png';
      case 4:
        return 'assets/images/migros.png';
      default:
        return null;
    }
  }

  // Restoran adı (workInfo veya bayInfo'dan)
  String get restaurantName {
    return workInfo?.name ?? bayInfo?.bayName ?? 'Bilinmiyor';
  }

  // Restoran telefonu
  String? get restaurantPhone {
    return workInfo?.phone;
  }

  // Kurye adı (isim + soyisim)
  String? get courierName {
    return courierInfo?.fullName;
  }

  // Paket ID (son 7 hane)
  String get shortId {
    return id.length > 7 ? id.substring(id.length - 7) : id;
  }

  // Geçen süre (dakika)
  int get elapsedMinutes {
    final now = DateTime.now();
    final diff = now.difference(sCdate);
    return diff.inMinutes;
  }

  // Kalan hazırlık süresi (dakika)
  int get remainingReadyMinutes {
    if (sStat == 0 || sCourier > 0) {
      return 0; // Hazır veya kurye atanmış
    }
    final elapsed = elapsedMinutes;
    return (sReadyMinutes - elapsed).clamp(0, sReadyMinutes);
  }

  // Oluşturma zamanı formatı
  String get formattedCreateTime {
    return '${sCdate.hour.toString().padLeft(2, '0')}:${sCdate.minute.toString().padLeft(2, '0')}';
  }

  // Oluşturma zamanı + hazırlık durumu
  String get createTimeWithStatus {
    if (sStat == 0 || remainingReadyMinutes == 0 || sCourier > 0) {
      return '$formattedCreateTime (Hazır)';
    } else {
      return '$formattedCreateTime ($remainingReadyMinutes dk)';
    }
  }

  // Alınma zamanı formatı (yoldaki siparişler için)
  String? get formattedReceivedTime {
    if (sReceivedTime == null) return null;
    return '${sReceivedTime!.hour.toString().padLeft(2, '0')}:${sReceivedTime!.minute.toString().padLeft(2, '0')}';
  }

  // Yolda durumu (zamanla birlikte)
  String get statusWithTime {
    if (sStat == 1) {
      // Yolda durumunda zaman bilgisi ekle
      if (sOnRoadTime != null) {
        final time = '${sOnRoadTime!.hour.toString().padLeft(2, '0')}:${sOnRoadTime!.minute.toString().padLeft(2, '0')}';
        return 'Yolda ($time)';
      } else if (sReceivedTime != null) {
        return 'Yolda ($formattedReceivedTime)';
      } else {
        return 'Yolda';
      }
    }
    return statusName;
  }

  // Durum rengi (UI için)
  int get statusColor {
    switch (sStat) {
      case 4: // İşletmede
        return 0xFF2196F3; // Mavi
      case 0: // Hazır
        return 0xFF4CAF50; // Yeşil
      case 1: // Yolda
        return 0xFFFF9800; // Turuncu
      case 2: // Teslim Edildi
        return 0xFF9E9E9E; // Gri
      case 3: // İptal
        return 0xFFF44336; // Kırmızı
      default:
        return 0xFF757575; // Gri
    }
  }

  factory Order.fromFirestore(DocumentSnapshot doc, {
    WorkInfo? workInfo,
    CourierInfo? courierInfo,
    BayInfo? bayInfo,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Timestamp dönüşümleri
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp == null) return DateTime.now();
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      }
      if (timestamp is DateTime) {
        return timestamp;
      }
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return DateTime.now();
    }

    // Double dönüşümü (String veya num olabilir)
    double _parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    final sCdate = parseTimestamp(data['s_cdate']);
    final sReadyTime = data['s_ready_time'] != null 
        ? parseTimestamp(data['s_ready_time']) 
        : null;
    final sAssignedTime = data['s_assigned_time'] != null 
        ? parseTimestamp(data['s_assigned_time']) 
        : null;
    final sReceivedTime = data['s_received'] != null 
        ? parseTimestamp(data['s_received']) 
        : null;
    final sOnRoadTime = data['s_on_road_time'] != null 
        ? parseTimestamp(data['s_on_road_time']) 
        : null;

    // String dönüşümü (int veya String olabilir)
    String? _parseString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is int) return value.toString();
      return value.toString();
    }

    return Order(
      id: doc.id,
      sId: data['s_id'] is int ? data['s_id'] : (data['s_id'] is String ? int.tryParse(data['s_id']) ?? 0 : 0),
      orderNumber: _parseString(data['s_orderid']),
      sStat: data['s_stat'] ?? 0,
      sCourier: data['s_courier'] ?? 0,
      sOrderscr: data['s_orderscr'] ?? 0,
      sBay: data['s_bay'] ?? 0,
      sWork: data['s_work'] ?? 0,
      sCdate: sCdate,
      sReadyMinutes: data['s_ready_minutes'] ?? workInfo?.readyMinutes ?? 10,
      sReadyTime: sReadyTime,
      sAssignedTime: sAssignedTime,
      sReceivedTime: sReceivedTime,
      sOnRoadTime: sOnRoadTime,
      sDinstance: _parseDouble(data['s_dinstance']),
      customer: CustomerInfo.fromMap(data['s_customer'] ?? {}),
      payment: PaymentInfo.fromMap(data['s_pay']),
      workInfo: workInfo,
      courierInfo: courierInfo,
      bayInfo: bayInfo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      's_id': sId,
      's_orderid': orderNumber,
      's_stat': sStat,
      's_courier': sCourier,
      's_orderscr': sOrderscr,
      's_bay': sBay,
      's_work': sWork,
      's_cdate': sCdate.toIso8601String(),
      's_ready_minutes': sReadyMinutes,
      's_ready_time': sReadyTime?.toIso8601String(),
      's_assigned_time': sAssignedTime?.toIso8601String(),
      's_received': sReceivedTime?.toIso8601String(),
      's_on_road_time': sOnRoadTime?.toIso8601String(),
      's_dinstance': sDinstance,
      'customer': customer.toMap(),
      'payment': payment.toMap(),
    };
  }
}
