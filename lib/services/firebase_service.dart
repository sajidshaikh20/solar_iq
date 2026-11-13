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

  Stream<GenerationSummary>? _cachedSummaryStream;
  String? _cachedSummaryUid;

  Stream<Map<String, double>>? _cachedDailyStream;
  String? _cachedDailyUid;

  Stream<double>? _cachedRateStream;
  String? _cachedRateUid;

  FirebaseService._internal() {
    _initEnergySync();
  }

  void _initEnergySync() {
    void handleEnergyData(dynamic data) {
      if (data == null) return;
      try {
        final energy = EnergyData.fromMap(Map<dynamic, dynamic>.from(data as Map));
        if (energy.units > 0) {
          updateDailyReading(energy.units);
        }
      } catch (e) {
        dev.log('[GEN-FB] Error in energy sync: $e', name: 'FirebaseService');
      }
    }

    _rootRef.child('energy').onValue.listen((event) {
      handleEnergyData(event.snapshot.value);
    });

    // Also trigger on auth state change so when user logs in, we sync current energy reading
    _auth.authStateChanges().listen((user) {
      _cachedSummaryStream = null;
      _cachedSummaryUid = null;
      _cachedDailyStream = null;
      _cachedDailyUid = null;
      _cachedRateStream = null;
      _cachedRateUid = null;

      if (user != null) {
        _rootRef.child('energy').get().then((snapshot) {
          if (snapshot.exists) {
            handleEnergyData(snapshot.value);
          }
        }).catchError((e) {
          dev.log('[GEN-FB] Error fetching energy on auth change: $e', name: 'FirebaseService');
        });
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
    if (_cachedSummaryStream != null && _cachedSummaryUid == uid) {
      return _cachedSummaryStream!;
    }
    _cachedSummaryUid = uid;
    _cachedSummaryStream = _buildGenerationSummaryStream(uid).asBroadcastStream();
    return _cachedSummaryStream!;
  }

  Stream<GenerationSummary> _buildGenerationSummaryStream(String uid) {
    return _dbRef.child('generation').child('summaries').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null || raw is! Map) return GenerationSummary();

      Map? targetData;
      if (raw.containsKey('today') || raw.containsKey('total')) {
        targetData = raw;
      } else if (raw.containsKey(uid) && raw[uid] is Map) {
        targetData = raw[uid] as Map;
      } else {
        // Fallback to whichever node has summary data
        for (final val in raw.values) {
          if (val is Map && (val.containsKey('today') || val.containsKey('total'))) {
            targetData = val;
            break;
          }
        }
      }

      if (targetData == null) return GenerationSummary();
      GenerationSummary summary = GenerationSummary.fromMap(targetData);

      // --- Virtual & Database Rollover ---
      if (summary.lastUpdate == null) {
        return summary;
      }

      final now = DateTime.now();
      final last = summary.lastUpdate!;

      final bool isNewDay = now.year != last.year ||
          now.month != last.month ||
          now.day != last.day;

      if (!isNewDay) {
        // If stored summary.today contains cumulative meter reading (e.g. 253.94), normalize it
        double normalizedToday = summary.today;
        if (summary.total > 35.0 && (summary.today >= summary.total || summary.today > 35.0)) {
          normalizedToday = 0.0;
        } else if (summary.yesterday > 0 && summary.today >= summary.yesterday) {
          normalizedToday = summary.today - summary.yesterday;
        }
        double normalizedMonth = summary.thisMonth;
        if (summary.total > 35.0 && summary.thisMonth >= summary.total && normalizedToday <= 0) {
          normalizedMonth = 0.0;
        }
        return GenerationSummary(
          today: normalizedToday,
          yesterday: summary.yesterday,
          thisMonth: normalizedMonth,
          total: summary.total,
          lastUpdate: summary.lastUpdate,
        );
      }

      // It's a new day relative to the last DB write.
      final DateTime yesterdayDate = now.subtract(const Duration(days: 1));
      final bool wasLastUpdateYesterday =
          last.year == yesterdayDate.year &&
              last.month == yesterdayDate.month &&
              last.day == yesterdayDate.day;

      final double rawYesterday = wasLastUpdateYesterday ? summary.today : summary.yesterday;
      final double yesterdayVal = (summary.total > 35.0 && rawYesterday >= summary.total) ? 0.0 : rawYesterday;

      final bool isSameMonth =
          now.year == last.year && now.month == last.month;
      final double rawMonth = isSameMonth ? summary.thisMonth : 0.0;
      final double thisMonthVal = (summary.total > 35.0 && rawMonth >= summary.total) ? 0.0 : rawMonth;

      final updatedSummary = GenerationSummary(
        today: 0.0,
        yesterday: yesterdayVal,
        thisMonth: thisMonthVal,
        total: summary.total,
        lastUpdate: now,
      );

      // Sync rollover state to Firebase Realtime Database
      if (uid != 'anonymous') {
        _dbRef
            .child('generation')
            .child('summaries')
            .child(uid)
            .set(updatedSummary.toMap())
            .catchError((e) {
          dev.log('[GEN-FB] Rollover summary save error: $e', name: 'FirebaseService');
        });
      }

      return updatedSummary;
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
              
              yesterday = wasLastUpdateYesterday ? today : yesterday;
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
    const path = 'solar_app/generation/logs';
    dev.log('[GEN-FB] subscribing to $path (limitToLast=$limit)',
        name: 'FirebaseService');
    return _dbRef
        .child('generation')
        .child('logs')
        .limitToLast(limit)
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      if (raw == null || raw is! Map) {
        return <GenerationLogEntry>[];
      }

      Map logsMap = raw;
      if (raw.containsKey(uid) && raw[uid] is Map) {
        logsMap = raw[uid] as Map;
      } else if (!raw.values.any((v) => v is Map && (v.containsKey('units') || v.containsKey('timestamp')))) {
        for (final val in raw.values) {
          if (val is Map && val.values.any((item) => item is Map && (item.containsKey('units') || item.containsKey('timestamp')))) {
            logsMap = val;
            break;
          }
        }
      }

      final entries = <GenerationLogEntry>[];
      logsMap.forEach((key, val) {
        if (val is Map) {
          entries.add(GenerationLogEntry.fromMap(key.toString(), val));
        }
      });

      // Sort by timestamp ascending so callers can bucket chronologically.
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return entries;
    });
  }

  Stream<Map<String, double>> getDailyGenerationStream() {
    final uid = currentUid ?? 'anonymous';
    if (_cachedDailyStream != null && _cachedDailyUid == uid) {
      return _cachedDailyStream!;
    }
    _cachedDailyUid = uid;
    _cachedDailyStream = _buildDailyGenerationStream(uid).asBroadcastStream();
    return _cachedDailyStream!;
  }

  Stream<Map<String, double>> _buildDailyGenerationStream(String uid) {
    const path = 'solar_app/generation/daily';
    dev.log('[GEN-FB] subscribing to daily generation path: $path',
        name: 'FirebaseService');
    return _dbRef
        .child('generation')
        .child('daily')
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      if (raw == null || raw is! Map) {
        return <String, double>{};
      }

      final Map<String, double> result = {};
      bool hasDirectDateKeys = false;

      // 1. Check if dates are directly under daily (single box shared)
      raw.forEach((key, value) {
        if (key.toString().contains('-') && value is! Map) {
          hasDirectDateKeys = true;
          if (value is num) {
            result[key.toString()] = value.toDouble();
          } else if (value != null) {
            result[key.toString()] = double.tryParse(value.toString()) ?? 0.0;
          }
        }
      });

      // 2. If dates are nested under UID nodes, extract from current UID or primary node
      if (!hasDirectDateKeys) {
        Map? userNode;
        if (raw.containsKey(uid) && raw[uid] is Map) {
          userNode = raw[uid] as Map;
        } else {
          int maxEntries = 0;
          raw.forEach((k, v) {
            if (v is Map && v.length > maxEntries) {
              maxEntries = v.length;
              userNode = v;
            }
          });
        }

        if (userNode is Map) {
          (userNode as Map).forEach((key, value) {
            if (value is num) {
              result[key.toString()] = value.toDouble();
            } else if (value != null) {
              result[key.toString()] = double.tryParse(value.toString()) ?? 0.0;
            }
          });
        }
      }

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

  Future<void> updateDailyReading(double rawUnits) async {
    final uid = currentUid;
    if (rawUnits <= 0) return;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    try {
      // 1. Fetch current daily data to calculate deltas
      final dailySnapshot = await _dbRef.child('generation').child('daily').get();
      Map<String, double> dailyMap = {};
      if (dailySnapshot.exists && dailySnapshot.value is Map) {
        final rawDaily = dailySnapshot.value as Map;
        rawDaily.forEach((k, v) {
          if (k.toString().contains('-') && v is! Map) {
            final d = double.tryParse(v.toString());
            if (d != null && d > 0) dailyMap[k.toString()] = d;
          } else if (v is Map) {
            v.forEach((dk, dv) {
              if (dk.toString().contains('-')) {
                final d = double.tryParse(dv.toString());
                if (d != null && d > 0) dailyMap[dk.toString()] = d;
              }
            });
          }
        });
      }


      // Store current meter reading for today
      dailyMap[dateStr] = rawUnits;
      await _dbRef.child('generation').child('daily').child(dateStr).set(rawUnits);
      if (uid != null && uid != 'anonymous') {
        await _dbRef.child('generation').child('daily').child(uid).child(dateStr).set(rawUnits);
      }

      final sortedDates = dailyMap.keys.toList()..sort();
      double todayUnits = 0.0;
      double yesterdayUnits = 0.0;
      double thisMonthUnits = 0.0;

      // FORMULA 1: Today's Generation = Current Meter - Yesterday's End Meter
      if (dailyMap.containsKey(yesterdayStr)) {
        final yVal = dailyMap[yesterdayStr] ?? 0.0;
        if (rawUnits >= yVal && yVal > 0) {
          todayUnits = rawUnits - yVal;
        }
      } else {
        final todayIndex = sortedDates.indexOf(dateStr);
        if (todayIndex > 0) {
          final prevDate = sortedDates[todayIndex - 1];
          final prevVal = dailyMap[prevDate] ?? 0.0;
          if (rawUnits >= prevVal && prevVal > 0) {
            todayUnits = rawUnits - prevVal;
          }
        }
      }
      if (todayUnits <= 0 && rawUnits <= 35.0) {
        todayUnits = rawUnits;
      }

      // FORMULA 2: Yesterday's Generation = Yesterday's Meter - Day Before Yesterday's Meter
      if (dailyMap.containsKey(yesterdayStr)) {
        final yIndex = sortedDates.indexOf(yesterdayStr);
        if (yIndex > 0) {
          final beforeYesterday = sortedDates[yIndex - 1];
          final beforeVal = dailyMap[beforeYesterday] ?? 0.0;
          final yVal = dailyMap[yesterdayStr] ?? 0.0;
          if (yVal >= beforeVal && beforeVal > 0) {
            yesterdayUnits = yVal - beforeVal;
          }
        }
      }

      // FORMULA 3: This Month Generation = Current Meter - Meter Reading at End of Last Month
      double lastMonthEndVal = 0.0;
      for (final d in sortedDates.reversed) {
        final parts = d.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final day = int.tryParse(parts[2]) ?? 0;
          final dt = DateTime(y, m, day);
          if (dt.isBefore(DateTime(now.year, now.month, 1))) {
            lastMonthEndVal = dailyMap[d] ?? 0.0;
            break;
          }
        }
      }
      if (lastMonthEndVal > 0 && rawUnits >= lastMonthEndVal) {
        thisMonthUnits = rawUnits - lastMonthEndVal;
      } else {
        // Sum of all daily generation in current month
        double monthSum = 0.0;
        for (int i = 1; i < sortedDates.length; i++) {
          final d = sortedDates[i];
          final parts = d.split('-');
          if (parts.length == 3) {
            final y = int.tryParse(parts[0]) ?? 0;
            final m = int.tryParse(parts[1]) ?? 0;
            if (y == now.year && m == now.month) {
              final prevVal = dailyMap[sortedDates[i - 1]] ?? 0.0;
              final currVal = dailyMap[d] ?? 0.0;
              if (currVal >= prevVal) monthSum += (currVal - prevVal);
            }
          }
        }
        thisMonthUnits = monthSum > 0 ? monthSum : todayUnits;
      }

      final summaryMap = GenerationSummary(
        today: todayUnits,
        yesterday: yesterdayUnits,
        thisMonth: thisMonthUnits,
        total: rawUnits,
        lastUpdate: now,
      ).toMap();

      // Save summary at root summaries AND summaries/$uid
      await _dbRef.child('generation').child('summaries').set(summaryMap);
      if (uid != null && uid != 'anonymous') {
        await _dbRef.child('generation').child('summaries').child(uid).set(summaryMap);
      }

      // 3. Automatically log hourly bucket for graphs (root AND $uid)
      final hourKey = '${dateStr}_H${now.hour.toString().padLeft(2, '0')}';
      final logData = {
        'units': todayUnits,
        'timestamp': now.toIso8601String(),
      };
      await _dbRef.child('generation').child('logs').child(hourKey).set(logData);
      if (uid != null && uid != 'anonymous') {
        await _dbRef.child('generation').child('logs').child(uid).child(hourKey).set(logData);
      }
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
    if (_cachedRateStream != null && _cachedRateUid == uid) {
      return _cachedRateStream!;
    }
    _cachedRateUid = uid;
    _cachedRateStream = _buildElectricityRateStream(uid).asBroadcastStream();
    return _cachedRateStream!;
  }

  Stream<double> _buildElectricityRateStream(String uid) async* {
    yield 8.0; // Emit default rate immediately
    try {
      final stream = _dbRef
          .child('settings')
          .child('electricity_rate')
          .onValue
          .map((event) {
        final val = event.snapshot.value;
        if (val == null) return 8.0;
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString()) ?? 8.0;
      }).handleError((error) {
        return 8.0;
      });
      yield* stream;
    } catch (_) {
      yield 8.0;
    }
  }

  Future<ApiResponse<void>> saveElectricityRate(double rate) async {
    final uid = currentUid ?? 'anonymous';
    try {
      await _dbRef
          .child('settings')
          .child('electricity_rate')
          .set(rate);
      if (uid != 'anonymous') {
        await _dbRef
            .child('settings')
            .child(uid)
            .child('electricity_rate')
            .set(rate);
      }
      return ApiResponse.success(null);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
}
