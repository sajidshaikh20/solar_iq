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

  factory GenerationSummary.fromMap(Map<dynamic, dynamic> map) {
    return GenerationSummary(
      today: (map['today'] ?? 0.0).toDouble(),
      yesterday: (map['yesterday'] ?? 0.0).toDouble(),
      thisMonth: (map['thisMonth'] ?? 0.0).toDouble(),
      total: (map['total'] ?? 0.0).toDouble(),
      lastUpdate: map['lastUpdate'] != null 
          ? DateTime.tryParse(map['lastUpdate']) 
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
