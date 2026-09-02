import 'package:flutter/material.dart';

import '../../services/flood_service.dart';
import '../../models/flood_station.dart';
import '../../services/saved_station_service.dart';
import '../stations/station_details.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final FloodService _floodService = FloodService();
  final SavedStationService _savedService = SavedStationService();

  bool _isLoading = true;
  String? _error;
  List<FloodStation> _allActiveAlerts = [];
  List<FloodStation> _myNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _floodService.fetchStations(),
        _savedService.fetchSavedStations(),
      ]);

      final stations = results[0] as List<FloodStation>;
      final savedRecords = results[1] as List<SavedStationRecord>;
      final enabledSavedIds = savedRecords
          .where((record) => record.notificationsEnabled)
          .map((record) => record.stationId)
          .toSet();

      final active = stations.where(_isRiskStatus).toList()
        ..sort(_compareSeverity);
      final personal = active
          .where((station) => enabledSavedIds.contains(station.id))
          .toList();

      if (!mounted) return;
      setState(() {
        _allActiveAlerts = active;
        _myNotifications = personal;
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

  bool _isRiskStatus(FloodStation station) {
    final status = station.status.toLowerCase();
    return status == 'alert' || status == 'warning' || status == 'danger';
  }

  int _severity(String status) {
    switch (status.toLowerCase()) {
      case 'danger':
        return 3;
      case 'warning':
        return 2;
      case 'alert':
        return 1;
      default:
        return 0;
    }
  }

  int _compareSeverity(FloodStation a, FloodStation b) {
    final severity = _severity(b.status).compareTo(_severity(a.status));
    if (severity != 0) return severity;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'danger':
        return const Color(0xFFF31646);
      case 'warning':
        return const Color(0xFFFF8A00);
      case 'alert':
        return const Color(0xFFF0B429);
      default:
        return Colors.grey;
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
        title: const Text('Alerts'),
        actions: [
          IconButton(
            tooltip: 'Refresh alerts',
            onPressed: _isLoading ? null : _loadAlerts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 44),
              const SizedBox(height: 12),
              const Text(
                'Unable to load alerts',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _loadAlerts, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _summaryCard()),
          SliverToBoxAdapter(child: _sectionTitle('My notifications')),
          if (_myNotifications.isEmpty)
            SliverToBoxAdapter(child: _emptyPersonalNotifications())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _alertTile(_myNotifications[index]),
                childCount: _myNotifications.length,
              ),
            ),
          SliverToBoxAdapter(child: _sectionTitle('All active alerts')),
          if (_allActiveAlerts.isEmpty)
            SliverToBoxAdapter(child: _safeState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _alertTile(_allActiveAlerts[index]),
                childCount: _allActiveAlerts.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final danger = _allActiveAlerts.where((s) => s.status == 'Danger').length;
    final warning = _allActiveAlerts.where((s) => s.status == 'Warning').length;
    final alert = _allActiveAlerts.where((s) => s.status == 'Alert').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFEDF1),
            child: Icon(Icons.notifications_active, color: Color(0xFFF31646)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_allActiveAlerts.length} active water-level alerts',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '$danger Danger  •  $warning Warning  •  $alert Alert',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 9),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  static Widget _emptyPersonalNotifications() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.notifications_none, color: Colors.grey),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No saved station needs attention. Turn on its bell in Saved rivers to monitor it here.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _safeState() {
    return const Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, color: Color(0xFF16B86D), size: 58),
          SizedBox(height: 10),
          Text('No active alerts', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('All monitored water levels are currently safe.'),
        ],
      ),
    );
  }

  Widget _alertTile(FloodStation station) {
    final color = _statusColor(station.status);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 9),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(Icons.water, color: color),
        ),
        title: Text(
          station.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${station.river} • ${station.district}\n'
              '${station.waterLevel.toStringAsFixed(2)} m • Updated ${station.lastUpdated}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              station.status,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StationDetailsPage(station: station),
            ),
          ).then((_) => _loadAlerts());
        },
      ),
    );
  }
}
