import 'package:flutter/material.dart';

import 'flood_service.dart';
import 'flood_station.dart';
import 'saved_station_service.dart';
import 'station_details.dart';

class SavedRiversPage extends StatefulWidget {
  const SavedRiversPage({super.key});

  @override
  State<SavedRiversPage> createState() => _SavedRiversPageState();
}

class _SavedRiversPageState extends State<SavedRiversPage> {
  final SavedStationService _savedService = SavedStationService();
  final FloodService _floodService = FloodService();

  bool _isLoading = true;
  String? _error;
  List<FloodStation> _stations = [];
  final Map<String, bool> _notifications = {};

  @override
  void initState() {
    super.initState();
    _loadSavedStations();
  }

  Future<void> _loadSavedStations() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final savedRecords = await _savedService.fetchSavedStations();

      if (savedRecords.isEmpty) {
        if (!mounted) return;
        setState(() {
          _stations = [];
          _notifications.clear();
          _isLoading = false;
        });
        return;
      }

      final allStations = await _floodService.fetchStations();
      final stationById = {
        for (final station in allStations) station.id: station,
      };

      final savedStations = savedRecords
          .map((record) => stationById[record.stationId])
          .whereType<FloodStation>()
          .toList();

      savedStations.sort(
            (a, b) => _severity(b.status).compareTo(_severity(a.status)),
      );

      if (!mounted) return;
      setState(() {
        _stations = savedStations;
        _notifications
          ..clear()
          ..addEntries(
            savedRecords.map(
                  (record) => MapEntry(
                record.stationId,
                record.notificationsEnabled,
              ),
            ),
          );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  int _severity(String status) {
    switch (status.toLowerCase()) {
      case 'danger':
        return 4;
      case 'warning':
        return 3;
      case 'alert':
        return 2;
      case 'normal':
        return 1;
      default:
        return 0;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'danger':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'alert':
        return Colors.amber.shade700;
      case 'normal':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _toggleNotifications(FloodStation station) async {
    final previous = _notifications[station.id] ?? true;
    final updated = !previous;

    setState(() {
      _notifications[station.id] = updated;
    });

    try {
      await _savedService.updateNotifications(station.id, updated);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notifications[station.id] = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update notification: $error')),
      );
    }
  }

  Future<void> _removeStation(FloodStation station) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove saved station?'),
        content: Text(
          'Remove ${station.name} from your saved rivers?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _savedService.removeStation(station.id);
      if (!mounted) return;
      setState(() {
        _stations.removeWhere((item) => item.id == station.id);
        _notifications.remove(station.id);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to remove station: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Saved rivers'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_stations.length} saved',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadSavedStations,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_stations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border,
                size: 65,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 14),
              const Text(
                'No saved rivers yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Open a station and press the bookmark icon to save it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavedStations,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _stations.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          return _savedStationTile(_stations[index]);
        },
      ),
    );
  }

  Widget _savedStationTile(FloodStation station) {
    final color = _statusColor(station.status);
    final notificationsEnabled = _notifications[station.id] ?? true;

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(
        station.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${station.river}\n${station.waterLevel.toStringAsFixed(2)} m · '
            'Updated ${station.lastUpdated}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: SizedBox(
        width: 112,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              station.status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              tooltip: notificationsEnabled
                  ? 'Disable notifications'
                  : 'Enable notifications',
              onPressed: () => _toggleNotifications(station),
              icon: Icon(
                notificationsEnabled
                    ? Icons.notifications
                    : Icons.notifications_none,
                color: notificationsEnabled
                    ? const Color(0xFF514BD6)
                    : Colors.grey,
                size: 20,
              ),
            ),
            IconButton(
              tooltip: 'Remove saved station',
              onPressed: () => _removeStation(station),
              icon: const Icon(
                Icons.bookmark,
                color: Colors.amber,
                size: 20,
              ),
            ),
          ],
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StationDetailsPage(station: station),
          ),
        ).then((_) => _loadSavedStations());
      },
    );
  }
}
