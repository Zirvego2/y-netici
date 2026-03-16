class CustomerInfo {
  final String fullname;
  final String phone;
  final String address;
  final String? note;
  final Map<String, double>? location; // {latitude: double, longitude: double}

  CustomerInfo({
    required this.fullname,
    required this.phone,
    required this.address,
    this.note,
    this.location,
  });

  factory CustomerInfo.fromMap(Map<String, dynamic> map) {
    Map<String, double>? loc;
    if (map['ss_loc'] != null) {
      final geoPoint = map['ss_loc'];
      if (geoPoint is Map) {
        loc = {
          'latitude': (geoPoint['latitude'] ?? 0.0).toDouble(),
          'longitude': (geoPoint['longitude'] ?? 0.0).toDouble(),
        };
      } else {
        // GeoPoint objesi için
        try {
          loc = {
            'latitude': geoPoint.latitude?.toDouble() ?? 0.0,
            'longitude': geoPoint.longitude?.toDouble() ?? 0.0,
          };
        } catch (e) {
          loc = null;
        }
      }
    }

    // String dönüşümü (int veya String olabilir)
    String _parseString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      if (value is String) return value;
      if (value is int) return value.toString();
      return value.toString();
    }

    return CustomerInfo(
      fullname: _parseString(map['ss_fullname'], 'Bilinmiyor'),
      phone: _parseString(map['ss_phone'], ''),
      address: _parseString(map['ss_adres'], ''),
      note: map['ss_note'] != null ? _parseString(map['ss_note'], '') : null,
      location: loc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ss_fullname': fullname,
      'ss_phone': phone,
      'ss_adres': address,
      'ss_note': note,
      'ss_loc': location,
    };
  }
}
