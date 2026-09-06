import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageSosPage extends StatefulWidget {
  const ManageSosPage({super.key});

  @override
  State<ManageSosPage> createState() => _ManageSosPageState();
}

class _ManageSosPageState extends State<ManageSosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _filter = 'active';
  String? _updatingId;

  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _supabase.from('sos_alerts').select(
        'id, user_id, full_name, latitude, longitude, '
            'message, status',
      );

      if (!mounted) return;

      setState(() {
        _alerts = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load SOS records: $error'),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _displayedAlerts {
    if (_filter == 'all') return _alerts;

    return _alerts.where((alert) {
      return alert['status'] == _filter;
    }).toList();
  }

  Future<void> _markResolved(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Resolve SOS Case?'),
          content: const Text(
            'Confirm that this emergency case has been handled.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Mark Resolved'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _updatingId = id;
    });

    try {
      await _supabase
          .from('sos_alerts')
          .update({'status': 'resolved'})
          .eq('id', id);

      await _loadAlerts();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS case marked as resolved'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update SOS case: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingId = null;
        });
      }
    }
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF3730A3),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
      ),
      onSelected: (_) {
        setState(() {
          _filter = value;
        });
      },
    );
  }

  Widget _alertCard(Map<String, dynamic> alert) {
    final id = alert['id'].toString();
    final status = alert['status']?.toString() ?? 'active';
    final isActive = status == 'active';
    final isUpdating = _updatingId == id;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE4E4EA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive
                      ? const Color(0xFFFFE5E5)
                      : const Color(0xFFE6F7EC),
                  child: Icon(
                    isActive ? Icons.sos : Icons.check,
                    color: isActive ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alert['full_name']?.toString() ??
                        'Unknown user',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: isActive ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            Text(
              alert['message']?.toString() ??
                  'Emergency assistance requested',
              style: const TextStyle(height: 1.4),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${alert['latitude']}, ${alert['longitude']}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            if (isActive) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isUpdating
                      ? null
                      : () {
                    _markResolved(id);
                  },
                  icon: isUpdating
                      ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    isUpdating
                        ? 'Updating...'
                        : 'Mark as Resolved',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedAlerts = _displayedAlerts;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3730A3),
        foregroundColor: Colors.white,
        title: const Text('Manage SOS Records'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                _filterChip('all', 'All'),
                _filterChip('active', 'Active'),
                _filterChip('resolved', 'Resolved'),
              ],
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (displayedAlerts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: Text('No SOS records found'),
                ),
              )
            else
              ...displayedAlerts.map(_alertCard),
          ],
        ),
      ),
    );
  }
}