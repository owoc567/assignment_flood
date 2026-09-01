import 'package:flutter/material.dart';
import 'flood_station.dart';
import 'saved_station_service.dart';

class StationDetailsPage extends StatefulWidget {
  final FloodStation station;

  const StationDetailsPage({
    super.key,
    required this.station,
  });

  @override
  State<StationDetailsPage> createState() => _StationDetailsPageState();
}

class _StationDetailsPageState extends State<StationDetailsPage> {
  final SavedStationService _savedService = SavedStationService();
  bool _isSaved = false;
  bool _isCheckingSaved = true;
  bool _isChangingSaved = false;

  FloodStation get station => widget.station;

  @override
  void initState() {
    super.initState();
    _checkSavedStatus();
  }

  Future<void> _checkSavedStatus() async {
    try {
      final saved = await _savedService.isSaved(station.id);
      if (!mounted) return;
      setState(() {
        _isSaved = saved;
        _isCheckingSaved = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingSaved = false;
      });
    }
  }

  Future<void> _toggleSaved() async {
    if (_isChangingSaved) return;

    setState(() {
      _isChangingSaved = true;
    });

    try {
      if (_isSaved) {
        await _savedService.removeStation(station.id);
      } else {
        await _savedService.saveStation(station.id);
      }

      if (!mounted) return;
      setState(() {
        _isSaved = !_isSaved;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSaved
                ? 'Station saved successfully.'
                : 'Station removed from saved rivers.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update saved station: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChangingSaved = false;
        });
      }
    }
  }

  Color _getStatusColor() {
    switch (station.status.toLowerCase()) {
      case 'danger':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'alert':
        return Colors.yellow.shade700;
      case 'normal':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _showLevel(double? level) {
    if (level == null) {
      return 'No data';
    }

    return '${level.toStringAsFixed(2)} m';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Station Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_isCheckingSaved || _isChangingSaved)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: _isSaved ? 'Remove saved station' : 'Save station',
              onPressed: _toggleSaved,
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _isSaved ? Colors.amber : const Color(0xFF514BD6),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station name and current status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.water,
                    size: 45,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    station.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Station ID: ${station.id}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      station.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Current water level',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.water_drop,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${station.waterLevel.toStringAsFixed(2)} m',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Last updated: ${station.lastUpdated}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Station information',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            _informationCard(
              icon: Icons.location_city,
              title: 'District',
              value: station.district,
            ),
            _informationCard(
              icon: Icons.map,
              title: 'State',
              value: station.state,
            ),
            _informationCard(
              icon: Icons.waves,
              title: 'River basin',
              value: station.river,
            ),

            const SizedBox(height: 18),

            const Text(
              'Water level thresholds',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            _thresholdCard(
              title: 'Normal',
              value: _showLevel(station.normalLevel),
              color: Colors.green,
            ),
            _thresholdCard(
              title: 'Alert',
              value: _showLevel(station.alertLevel),
              color: Colors.yellow.shade700,
            ),
            _thresholdCard(
              title: 'Warning',
              value: _showLevel(station.warningLevel),
              color: Colors.orange,
            ),
            _thresholdCard(
              title: 'Danger',
              value: _showLevel(station.dangerLevel),
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _informationCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF3F51F3),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? 'No data' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thresholdCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: color,
            width: 6,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
