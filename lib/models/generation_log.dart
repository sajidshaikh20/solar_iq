import 'dart:developer' as dev;

class GenerationLogEntry {
  final String? id;
  final double units;
  final DateTime timestamp;
  final String? note;

  GenerationLogEntry({
    this.id,
    required this.units,
    required this.timestamp,
    this.note,
  });

  factory GenerationLogEntry.fromMap(String id, Map<dynamic, dynamic> map) {
    final units = _parseUnits(map);
    final timestamp = _parseTimestamp(map);
    // Per-entry diagnostic. Tag with [GEN-LOG] so it's easy to filter:
    //   adb logcat | grep GEN-LOG
    dev.log(
      '[GEN-LOG] id=$id raw=$map -> units=$units ts=$timestamp',
      name: 'GenerationLogEntry',
    );
    return GenerationLogEntry(
      id: id,
      units: units,
      timestamp: timestamp,
      note: map['note']?.toString(),
    );
  }

  // Accept either `units`, `kwh`, `value`, `unit` and any numeric/string form.
  static double _parseUnits(Map<dynamic, dynamic> map) {
    final raw = map['units'] ?? map['kwh'] ?? map['value'] ?? map['unit'];
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  // Accept ISO strings, epoch milliseconds (13-digit int), epoch seconds
  // (10-digit int) and Firebase ServerValue.TIMESTAMP resolved values.
  // Also tolerate alternate keys (`time`, `date`, `createdAt`).
  static DateTime _parseTimestamp(Map<dynamic, dynamic> map) {
    final raw = map['timestamp'] ??
        map['time'] ??
        map['date'] ??
        map['createdAt'] ??
        map['created_at'];
    if (raw == null) return DateTime.now();

    if (raw is int) {
      // Heuristic: > 10^12 → milliseconds, otherwise seconds.
      if (raw > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    if (raw is double) {
      final asInt = raw.toInt();
      if (asInt > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
    }

    final s = raw.toString().trim();
    // Numeric string?
    final asNum = int.tryParse(s);
    if (asNum != null) {
      if (asNum > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(asNum);
      }
      return DateTime.fromMillisecondsSinceEpoch(asNum * 1000);
    }
    // ISO string fallback.
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'units': units,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
    };
  }
}
