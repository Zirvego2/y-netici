class BayInfo {
  final int sId;
  final String? bayName;

  BayInfo({
    required this.sId,
    this.bayName,
  });

  factory BayInfo.fromMap(Map<String, dynamic> map) {
    return BayInfo(
      sId: map['s_id'] ?? 0,
      bayName: map['s_bay_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      's_id': sId,
      's_bay_name': bayName,
    };
  }
}
