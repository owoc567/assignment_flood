import 'package:supabase_flutter/supabase_flutter.dart';

class SavedStationRecord {
  final String stationId;
  final bool notificationsEnabled;

  const SavedStationRecord({
    required this.stationId,
    required this.notificationsEnabled,
  });

  factory SavedStationRecord.fromJson(Map<String, dynamic> json) {
    return SavedStationRecord(
      stationId: json['station_id'] as String,
      notificationsEnabled:
      json['notifications_enabled'] as bool? ?? true,
    );
  }
}

class SavedStationService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in before saving a station.');
    }
    return user.id;
  }

  Future<List<SavedStationRecord>> fetchSavedStations() async {
    final data = await _client
        .from('saved_stations')
        .select('station_id, notifications_enabled')
        .eq('user_id', _userId)
        .order('created_at');

    return (data as List)
        .map(
          (row) => SavedStationRecord.fromJson(
        Map<String, dynamic>.from(row as Map),
      ),
    )
        .toList();
  }

  Future<bool> isSaved(String stationId) async {
    final data = await _client
        .from('saved_stations')
        .select('station_id')
        .eq('user_id', _userId)
        .eq('station_id', stationId)
        .maybeSingle();

    return data != null;
  }

  Future<void> saveStation(String stationId) async {
    await _client.from('saved_stations').upsert(
      {
        'user_id': _userId,
        'station_id': stationId,
        'notifications_enabled': true,
      },
      onConflict: 'user_id,station_id',
    );
  }

  Future<void> removeStation(String stationId) async {
    await _client
        .from('saved_stations')
        .delete()
        .eq('user_id', _userId)
        .eq('station_id', stationId);
  }

  Future<void> updateNotifications(
      String stationId,
      bool enabled,
      ) async {
    await _client
        .from('saved_stations')
        .update({'notifications_enabled': enabled})
        .eq('user_id', _userId)
        .eq('station_id', stationId);
  }
}
