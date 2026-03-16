class WorkInfo {
  final int sId;
  final String? name;
  final String? phone;
  final int? readyMinutes; // Hazırlık süresi (dakika)

  WorkInfo({
    required this.sId,
    this.name,
    this.phone,
    this.readyMinutes,
  });

  factory WorkInfo.fromMap(Map<String, dynamic> map) {
    return WorkInfo(
      sId: map['s_id'] ?? 0,
      name: map['s_name'],
      phone: map['s_phone'],
      readyMinutes: map['s_ready'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      's_id': sId,
      's_name': name,
      's_phone': phone,
      's_ready': readyMinutes,
    };
  }
}
