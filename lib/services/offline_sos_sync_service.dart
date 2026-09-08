import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline_sos_database.dart';

class OfflineSosSyncService {
  OfflineSosSyncService._internal();

  static final OfflineSosSyncService instance =
  OfflineSosSyncService._internal();

  final Connectivity _connectivity = Connectivity();
  final SupabaseClient _supabase = Supabase.instance.client;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isSyncing = false;
  bool _hasStarted = false;

  void start() {
    if (_hasStarted) return;

    _hasStarted = true;

    // Try once when the service starts.
    syncPendingSos();

    // Try again whenever an Internet connection becomes available.
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any(
            (result) => result != ConnectivityResult.none,
      );

      if (hasConnection) {
        syncPendingSos();
      }
    });
  }

  Future<int> syncPendingSos() async {
    if (_isSyncing) {
      return 0;
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      return 0;
    }

    _isSyncing = true;
    int synchronizedCount = 0;

    try {
      final pendingRecords =
      await OfflineSosDatabase.instance.getPendingSos();

      for (final record in pendingRecords) {
        // Do not upload another user's locally stored SOS.
        if (record['user_id']?.toString() != user.id) {
          continue;
        }

        final localId = record['id'] as int?;

        if (localId == null) {
          continue;
        }

        try {
          await _supabase.from('sos_alerts').insert({
            'user_id': record['user_id'],
            'full_name': record['full_name'],
            'phone_number': record['phone_number'],
            'latitude': record['latitude'],
            'longitude': record['longitude'],
            'message': record['message'],
            'status': 'active',
            'created_at': record['created_at'],
          });

          // Delete only after Supabase accepts the record.
          await OfflineSosDatabase.instance.deleteSos(localId);

          synchronizedCount++;
        } catch (error) {
          debugPrint(
            'Unable to synchronize offline SOS $localId: $error',
          );

          // Stop because the Internet or Supabase may still be unavailable.
          break;
        }
      }
    } finally {
      _isSyncing = false;
    }

    return synchronizedCount;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _hasStarted = false;
  }
}