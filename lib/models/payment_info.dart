class PaymentInfo {
  final int? type; // 0: Nakit, 1: Kredi Kartı, 2: Online
  final double amount;
  final double? workPay;
  final double? poss;

  PaymentInfo({
    this.type,
    required this.amount,
    this.workPay,
    this.poss,
  });

  String get typeName {
    switch (type) {
      case 0:
        return 'Nakit';
      case 1:
        return 'Kredi Kartı';
      case 2:
        return 'Online';
      default:
        return 'Bilinmiyor';
    }
  }

  factory PaymentInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return PaymentInfo(amount: 0);
    }

    return PaymentInfo(
      type: map['ss_paytype'] as int?,
      amount: (map['ss_paycount'] ?? 0).toDouble(),
      workPay: map['ss_workpay'] != null ? (map['ss_workpay'] as num).toDouble() : null,
      poss: map['ss_poss'] != null ? (map['ss_poss'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ss_paytype': type,
      'ss_paycount': amount,
      'ss_workpay': workPay,
      'ss_poss': poss,
    };
  }
}
