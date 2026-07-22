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

  factory EnergyData.fromMap(Map<dynamic, dynamic> map) {
    DateTime parsedTs = DateTime.now();
    if (map['timestamp'] != null) {
      final ts = DateTime.tryParse(map['timestamp'].toString());
      if (ts != null) parsedTs = ts;
    }
    return EnergyData(
      battery: (map['battery'] ?? 0.0).toDouble(),
      current: (map['current'] ?? 0.0).toDouble(),
      power: (map['power'] ?? 0.0).toDouble(),
      units: (map['units'] ?? 0.0).toDouble(),
      voltage: (map['voltage'] ?? 0.0).toDouble(),
      timestamp: parsedTs,
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
