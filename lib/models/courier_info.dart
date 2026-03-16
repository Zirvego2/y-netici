class CourierInfo {
  final int sId;
  final String? name;
  final String? surname;
  final String? phone;
  // Status ID'leri:
  // 0: Boşta/Müsait (genelde gösterilmez, filtrelemede kullanılır)
  // 1: Müsait/Boşta (yeşil) - Sipariş alabilir
  // 2: Meşgul (turuncu/mavi) - Sipariş taşıyor
  // 3: Molada (sarı) - Mola veriyor
  // 4: Kaza (kırmızı) - Kaza durumu
  final int? status;

  CourierInfo({
    required this.sId,
    this.name,
    this.surname,
    this.phone,
    this.status,
  });

  // Tam ad (isim + soyisim)
  String get fullName {
    if (name != null && surname != null) {
      return '${name!} ${surname!}'.trim();
    } else if (name != null) {
      return name!;
    } else if (surname != null) {
      return surname!;
    }
    return 'Kurye #$sId';
  }

  String get statusName {
    if (status == null) {
      return 'Çalışmıyor';
    }
    switch (status) {
      case 0:
        return 'Çalışmıyor'; // Pasif durumda
      case 1:
        return 'Müsait'; // Sipariş alabilir durumda
      case 2:
        return 'Meşgul'; // Aktif sipariş taşıyor
      case 3:
        return 'Molada'; // Mola veriyor
      case 4:
        return 'Kaza'; // Kaza durumu
      default:
        return 'Bilinmiyor';
    }
  }
  
  // Status ID açıklamaları
  static String getStatusDescription(int? status) {
    switch (status) {
      case 0:
        return 'Boşta - Genelde gösterilmez';
      case 1:
        return 'Müsait - Sipariş alabilir durumda';
      case 2:
        return 'Meşgul - Aktif sipariş taşıyor';
      case 3:
        return 'Molada - Mola veriyor';
      case 4:
        return 'Kaza - Kaza durumu';
      default:
        return 'Bilinmiyor';
    }
  }

  factory CourierInfo.fromMap(Map<String, dynamic> map) {
    return CourierInfo(
      sId: map['s_id'] ?? 0,
      name: map['s_info']?['ss_name'] ?? map['s_name'],
      surname: map['s_info']?['ss_surname'] ?? map['s_surname'],
      phone: map['s_phone'],
      status: map['s_stat'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      's_id': sId,
      's_name': name,
      's_surname': surname,
      's_phone': phone,
      's_stat': status,
    };
  }
}
