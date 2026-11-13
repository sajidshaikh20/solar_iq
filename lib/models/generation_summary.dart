class GenerationSummary {
  final double today;
  final double yesterday;
  final double thisMonth;
  final double total;
  final DateTime? lastUpdate;

  GenerationSummary({
    this.today = 0.0,
    this.yesterday = 0.0,
    this.thisMonth = 0.0,
    this.total = 0.0,
    this.lastUpdate,
  });

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  factory GenerationSummary.fromMap(Map<dynamic, dynamic> map) {
    return GenerationSummary(
      today: _toDouble(map['today']),
      yesterday: _toDouble(map['yesterday']),
      thisMonth: _toDouble(map['thisMonth']),
      total: _toDouble(map['total']),
      lastUpdate: map['lastUpdate'] != null 
          ? DateTime.tryParse(map['lastUpdate'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'today': today,
      'yesterday': yesterday,
      'thisMonth': thisMonth,
      'total': total,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }
}
