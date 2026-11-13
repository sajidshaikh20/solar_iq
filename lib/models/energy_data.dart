class EnergyData {
  final double battery;
  final double current;
  final double power;
  final double units;
  final double voltage;
  final DateTime timestamp;

  EnergyData({
    this.battery = 0.0,
    this.current = 0.0,
    this.power = 0.0,
    this.units = 0.0,
    this.voltage = 0.0,
    required this.timestamp,
  });

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  factory EnergyData.fromMap(Map<dynamic, dynamic> map) {
    DateTime? parsedTs;
    if (map['timestamp'] != null) {
      final raw = map['timestamp'];
      final int? numVal = raw is num ? raw.toInt() : int.tryParse(raw.toString());
      if (numVal != null) {
        if (numVal > 1700000000000) {
          parsedTs = DateTime.fromMillisecondsSinceEpoch(numVal);
        } else if (numVal > 1700000000) {
          parsedTs = DateTime.fromMillisecondsSinceEpoch(numVal * 1000);
        } else {
          // Hardware uptime/boot counter (e.g. 11649) -> reading is occurring right now
          parsedTs = DateTime.now();
        }
      } else {
        parsedTs = DateTime.tryParse(raw.toString());
        if (parsedTs != null && parsedTs.year < 2020) {
          parsedTs = DateTime.now();
        }
      }
    }
    // If timestamp is not provided by the IoT hardware, the live reading
    // is occurring right now, so default to DateTime.now().
    return EnergyData(
      battery: _toDouble(map['battery']),
      current: _toDouble(map['current']),
      power: _toDouble(map['power']),
      units: _toDouble(map['units']),
      voltage: _toDouble(map['voltage']),
      timestamp: parsedTs ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'battery': battery,
      'current': current,
      'power': power,
      'units': units,
      'voltage': voltage,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
