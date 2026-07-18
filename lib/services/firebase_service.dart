import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import '../models/generation_summary.dart';
import '../models/generation_log.dart';
import '../models/energy_data.dart';
import '../models/api_response.dart';
import '../models/notification_model.dart';
import '../constants.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _rootRef = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: AppConstants.DATABASE_URL,
  ).ref();

  DatabaseReference get _dbRef => _rootRef.child('solar_app');

  String? get currentUid => _auth.currentUser?.uid;

  FirebaseService._internal() {
    _initEnergySync();
  }

  void _initEnergySync() {
    _rootRef.child('energy').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;
      try {
        final energy = EnergyData.fromMap(Map<dynamic, dynamic>.from(data as Map));
        if (energy.units > 0) {
          updateDailyReading(energy.units);
        }
      } catch (e) {
        dev.log('[GEN-FB] Error in energy sync: $e', name: 'FirebaseService');
      }
    });
  }

  // --- User Profile ---

  Future<ApiResponse<UserModel>> getUserProfile() async {
    final uid = currentUid;
    if (uid == null) return ApiResponse.error('User not authenticated');

    try {
      final snapshot = await _dbRef.child('users').child(uid).get();
      if (snapshot.exists) {
        return ApiResponse.success(
          UserModel.fromMap(uid, Map<String, dynamic>.from(snapshot.value as Map)),
        );
      }
      return ApiResponse.error('User profile not found');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<void>> saveUserProfile(UserModel user) async {
    try {
      await _dbRef.child('users').child(user.uid).set(user.toMap());
      return ApiResponse.success(null);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  Stream<UserModel?> getUserProfileStream(String uid) {
    return _dbRef.child('users').child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return UserModel.fromMap(uid, Map<String, dynamic>.from(data as Map));
    });
  }

  // --- Generation Tracking ---

  Stream<GenerationSummary> getGenerationSummaryStream() {
    final uid = currentUid ?? 'anonymous';
    return _dbRef.child('generation').child('summaries').child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return GenerationSummary();

      GenerationSummary summary = GenerationSummary.fromMap(data as Map);

      // --- Virtual Rollover for UI ---
      // This ensures that when the app is opened on a new day,
      // "Today" shows 0 and "Yesterday" shows previous day's total,
      // even if the database hasn't been updated yet.
      //
      // IMPORTANT: We never discard valid Firebase values for `yesterday` /
      // `thisMonth`. We only adjust `today` (and shift today -> yesterday
      // when the last update happened exactly yesterday).
      if (summary.lastUpdate == null) {
        // No timestamp metadata — trust whatever is in Firebase as-is.
        return summary;
      }

      final now = DateTime.now();
      final last = summary.lastUpdate!;

      final bool isNewDay = now.year != last.year ||
          now.month != last.month ||
          now.day != last.day;

      if (!isNewDay) {
        // Same day — return Firebase data unchanged.
        return summary;
      }

      // It's a new day relative to the last DB write.
      final DateTime yesterdayDate = now.subtract(const Duration(days: 1));
      final bool wasLastUpdateYesterday =
          last.year == yesterdayDate.year &&
              last.month == yesterdayDate.month &&
              last.day == yesterdayDate.day;

      // If the most recent write was yesterday, the value sitting in
      // `summary.today` is actually yesterday's accumulated total — promote it.
      // Otherwise keep whatever Firebase has stored under `yesterday` (do NOT
      // wipe it to 0; the device may simply not have pushed an update today).
      final double yesterdayVal =
          wasLastUpdateYesterday ? summary.today : summary.yesterday;

      // Same month? keep stored value. Different month? `thisMonth` is stale,
      // so reset to 0 until a new entry rolls in for the current month.
      final bool isSameMonth =
          now.year == last.year && now.month == last.month;
      final double thisMonthVal = isSameMonth ? summary.thisMonth : 0.0;

      return GenerationSummary(
        today: 0.0,
        yesterday: yesterdayVal,
        thisMonth: thisMonthVal,
        total: summary.total,
        lastUpdate: summary.lastUpdate,
      );
    });
  }

  Future<ApiResponse<void>> saveGenerationEntry(GenerationLogEntry entry) async {
    final uid = currentUid ?? 'anonymous';
    try {
      // 1. Save entry to logs
      await _dbRef.child('generation').child('logs').child(uid).push().set(entry.toMap());

      // 2. Update summary via transaction
      final summaryRef = _dbRef.child('generation').child('summaries').child(uid);
      await summaryRef.runTransaction((Object? post) {
        final now = DateTime.now();
        GenerationSummary currentSummary;
        
        if (post == null) {
          currentSummary = GenerationSummary(
            today: entry.units,
            thisMonth: entry.units,
            total: entry.units,
            lastUpdate: now,
          );
        } else {
          final data = Map<String, dynamic>.from(post as Map);
          final lastUpdateStr = data['lastUpdate'] as String?;
          DateTime? lastUpdate = lastUpdateStr != null ? DateTime.tryParse(lastUpdateStr) : null;
          
          double today = (data['today'] ?? 0.0).toDouble();
          double yesterday = (data['yesterday'] ?? 0.0).toDouble();
          double thisMonth = (data['thisMonth'] ?? 0.0).toDouble();
          double total = (data['total'] ?? 0.0).toDouble();

          if (lastUpdate != null) {
            bool isNewDay = now.year != lastUpdate.year || 
                            now.month != lastUpdate.month || 
                            now.day != lastUpdate.day;
            
            bool isNewMonth = now.year != lastUpdate.year || 
                              now.month != lastUpdate.month;

            if (isNewDay) {
              // --- Generate Notification for the completed day ---
              addNotification(NotificationModel(
                id: '',
                title: 'Daily Generation Report',
                body: 'You generated ${today.toStringAsFixed(1)} kWh yesterday. Keep it up! ☀️',
                timestamp: now,
                type: NotificationType.generation,
              ));

              // Check if the last update was actually yesterday
              DateTime yesterdayDate = now.subtract(const Duration(days: 1));
              bool wasLastUpdateYesterday = lastUpdate.year == yesterdayDate.year && 
                                           lastUpdate.month == yesterdayDate.month && 
                                           lastUpdate.day == yesterdayDate.day;
              
              yesterday = wasLastUpdateYesterday ? today : 0.0;
              today = entry.units;
            } else {
              today += entry.units;
            }

            if (isNewMonth) {
              thisMonth = entry.units;
            } else {
              thisMonth += entry.units;
            }
          } else {
            today += entry.units;
            thisMonth += entry.units;
          }
          
          total += entry.units;
          
          currentSummary = GenerationSummary(
            today: today,
            yesterday: yesterday,
            thisMonth: thisMonth,
            total: total,
            lastUpdate: now,
          );
        }
        return Transaction.success(currentSummary.toMap());
      });

      return ApiResponse.success(null);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  Stream<List<GenerationLogEntry>> getRecentLogsStream({int limit = 7}) {
    final uid = currentUid ?? 'anonymous';
    return _dbRef
        .child('generation')
        .child('logs')
        .child(uid)
        .limitToLast(limit)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return [];

      final entries = data.entries.map((e) {
        return GenerationLogEntry.fromMap(e.key.toString(), e.value as Map);
      }).toList();

      // Sort by timestamp descending
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    });
  }

  /// Returns a larger window of log entries so the UI can group them by
  /// hour / day / week as needed (Today, Yesterday, This Month, Custom tabs).
  /// Default is the most recent 500 entries which comfortably covers a month.
  Stream<List<GenerationLogEntry>> getLogsStream({int limit = 500}) {
    final uid = currentUid ?? 'anonymous';
    final path = 'solar_app/generation/logs/$uid';
    dev.log('[GEN-FB] subscribing to $path (limitToLast=$limit)',
        name: 'FirebaseService');
    return _dbRef
        .child('generation')
        .child('logs')
        .child(uid)
        .limitToLast(limit)
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      dev.log(
        '[GEN-FB] snapshot @ $path '
        'exists=${event.snapshot.exists} '
        'type=${raw.runtimeType} '
        'value=${raw.toString().substring(0, raw.toString().length.clamp(0, 400))}',
        name: 'FirebaseService',
      );
      if (raw == null) {
        dev.log('[GEN-FB] no data at $path -> returning empty list',
            name: 'FirebaseService');
        return <GenerationLogEntry>[];
      }
      if (raw is! Map) {
        dev.log(
          '[GEN-FB] WARNING: data at $path is not a Map (was ${raw.runtimeType}); '
          'check Firebase schema',
          name: 'FirebaseService',
        );
        return <GenerationLogEntry>[];
      }

      final entries = raw.entries.map((e) {
        return GenerationLogEntry.fromMap(
            e.key.toString(), e.value as Map);
      }).toList();

      // Sort by timestamp ascending so callers can bucket chronologically.
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Concise summary log
      final first = entries.isNotEmpty ? entries.first.timestamp : null;
      final last = entries.isNotEmpty ? entries.last.timestamp : null;
      final totalUnits =
          entries.fold<double>(0, (acc, e) => acc + e.units);
      dev.log(
        '[GEN-FB] parsed ${entries.length} entries '
        'firstTs=$first lastTs=$last totalUnits=$totalUnits',
        name: 'FirebaseService',
      );
      return entries;
    });
  }

  Stream<Map<String, double>> getDailyGenerationStream() {
    final uid = currentUid ?? 'anonymous';
    final path = 'solar_app/generation/daily/$uid';
    dev.log('[GEN-FB] subscribing to daily generation path: $path',
        name: 'FirebaseService');
    return _dbRef
        .child('generation')
        .child('daily')
        .child(uid)
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        return <String, double>{};
      }
      if (raw is! Map) {
        dev.log('[GEN-FB] WARNING: daily path is not a Map: $raw',
            name: 'FirebaseService');
        return <String, double>{};
      }

      final Map<String, double> result = {};
      raw.forEach((key, value) {
        if (value is num) {
          result[key.toString()] = value.toDouble();
        } else if (value != null) {
          result[key.toString()] = double.tryParse(value.toString()) ?? 0.0;
        }
      });
      return result;
    });
  }

  // --- Real-time Energy Tracking ---

  Stream<EnergyData> getEnergyDataStream() {
    return _rootRef.child('energy').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return EnergyData(timestamp: DateTime.now());
      return EnergyData.fromMap(Map<dynamic, dynamic>.from(data as Map));
    });
  }

  Future<void> updateDailyReading(double units) async {
    final uid = currentUid;
    if (uid == null) return;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      await _dbRef.child('generation').child('daily').child(uid).child(dateStr).set(units);
    } catch (e) {
      dev.log('[GEN-FB] Error saving daily reading: $e', name: 'FirebaseService');
    }
  }

  // --- ROI Data ---
  
  Stream<Map<dynamic, dynamic>?> getRoiDataStream() {
    final uid = currentUid ?? 'anonymous';
    return _dbRef.child('roi').child(uid).onValue.map((event) {
      return event.snapshot.value as Map?;
    });
  }

  Future<ApiResponse<void>> saveRoiData(Map<String, dynamic> data) async {
    final uid = currentUid ?? 'anonymous';
    try {
      await _dbRef.child('roi').child(uid).set({
        ...data,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return ApiResponse.success(null);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<void>> submitQuery(Map<String, dynamic> queryData) async {
    final uid = currentUid ?? 'anonymous';
    try {
      await _dbRef.child('queries').child(uid).push().set({
        ...queryData,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return ApiResponse.success(null);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<void>> saveQuotation(Map<String, dynamic> quotationData) async {
    final uid = currentUid ?? 'anonymous';
    try {
      await _dbRef.child('quotations').child(uid).push().set({
        ...quotationData,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return ApiResponse.success(null);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // --- Notifications ---

  Stream<List<NotificationModel>> getNotificationsStream() {
    final uid = currentUid ?? 'anonymous';
    return _dbRef.child('notifications').child(uid).onValue.map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return [];

      final notifications = data.entries.map((e) {
        return NotificationModel.fromMap(e.key.toString(), e.value as Map);
      }).toList();

      // Sort by timestamp descending (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notifications;
    });
  }

  Future<void> addNotification(NotificationModel notification) async {
    final uid = currentUid ?? 'anonymous';
    try {
      await _dbRef.child('notifications').child(uid).push().set(notification.toMap());
    } catch (e) {
      print('Error adding notification: $e');
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    final uid = currentUid ?? 'anonymous';
    try {
      await _dbRef.child('notifications').child(uid).child(id).update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    final uid = currentUid ?? 'anonymous';
    try {
      final ref = _dbRef.child('notifications').child(uid);
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        final updates = <String, dynamic>{};
        for (final key in data.keys) {
          updates['$key/isRead'] = true;
        }
        await ref.update(updates);
      }
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  // --- Helper for Raw References (if needed for specialized UI) ---
  DatabaseReference getButtonRef(String buttonId) => _dbRef.child('buttons').child(buttonId);
  DatabaseReference getDigitalOutputRef(int pin) => _rootRef
      .child(AppConstants.board1Path)
      .child(AppConstants.outputsPath)
      .child(AppConstants.digitalPath)
      .child(pin.toString());

  // --- Settings ---

  Stream<double> getElectricityRateStream() {
    final uid = currentUid ?? 'anonymous';
    return _dbRef
        .child('settings')
        .child(uid)
        .child('electricity_rate')
        .onValue
        .map((event) {
      final val = event.snapshot.value;
      if (val == null) return 8.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 8.0;
    }).handleError((error) {
      dev.log('[GEN-FB] Electricity rate stream error: $error', name: 'FirebaseService');
      return 8.0;
    });
  }

  Future<ApiResponse<void>> saveElectricityRate(double rate) async {
    final uid = currentUid ?? 'anonymous';
    try {
      await _dbRef
          .child('settings')
          .child(uid)
          .child('electricity_rate')
          .set(rate);
      return ApiResponse.success(null);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
}
