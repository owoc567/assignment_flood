import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
      final data = await _supabase
          .from('sos_alerts')
          .select(
            'id, user_id, full_name, phone_number, '
                'latitude, longitude, message, status, created_at, '
                'responded_by, responded_at, resolved_by, resolved_at',
          )
              .order('created_at', ascending: false);

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
        SnackBar(content: Text('Failed to load SOS records: $error')),
      );
    }
  }

  List<Map<String, dynamic>> get _displayedAlerts {
    if (_filter == 'all') return _alerts;

    return _alerts.where((alert) {
      return alert['status'] == _filter;
    }).toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return 'Time unavailable';
    }

    final date = DateTime.tryParse(
      value.toString(),
    )?.toLocal();

    if (date == null) {
      return 'Time unavailable';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year}  $hour:$minute';
  }

  Future<void> _callUser(String phoneNumber) async {
    final phone = phoneNumber.trim();

    if (phone.isEmpty) {
      _showMessage('This user did not provide a phone number.');
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: phone,
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      _showMessage('Unable to open the phone application.');
    }
  }

  Future<void> _openLocation({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://maps.google.com/?q=$latitude,$longitude',
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      _showMessage('Unable to open the location.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmStatusUpdate({
    required String id,
    required String newStatus,
  }) async {
    final isStarting = newStatus == 'responding';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isStarting
                ? 'Start Responding?'
                : 'Resolve SOS Case?',
          ),
          content: Text(
            isStarting
                ? 'Confirm that you are starting to handle this emergency case.'
                : 'Confirm that this emergency case has been handled.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                isStarting ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                isStarting
                    ? 'Start Responding'
                    : 'Mark Resolved',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _updateStatus(
        id: id,
        newStatus: newStatus,
      );
    }
  }

  Future<void> _updateStatus({
    required String id,
    required String newStatus,
  }) async {
    final admin = _supabase.auth.currentUser;

    if (admin == null) {
      _showMessage('Please sign in again.');
      return;
    }

    setState(() {
      _updatingId = id;
    });

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final Map<String, dynamic> changes;

      if (newStatus == 'responding') {
        changes = {
          'status': 'responding',
          'responded_by': admin.id,
          'responded_at': now,
        };
      } else {
        changes = {
          'status': 'resolved',
          'resolved_by': admin.id,
          'resolved_at': now,
        };
      }

      await _supabase
          .from('sos_alerts')
          .update(changes)
          .eq('id', id);

      await _loadAlerts();

      if (!mounted) return;

      _showMessage(
        newStatus == 'responding'
            ? 'SOS case is now being handled.'
            : 'SOS case marked as resolved.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to update SOS case: $error');
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
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
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
    final isResponding = status == 'responding';
    final isResolved = status == 'resolved';
    final isUpdating = _updatingId == id;

    final phoneNumber =
        alert['phone_number']?.toString().trim() ?? '';

    final latitude = double.tryParse(
      alert['latitude']?.toString() ?? '',
    );

    final longitude = double.tryParse(
      alert['longitude']?.toString() ?? '',
    );

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
                  backgroundColor:
                  _statusColor(status).withValues(alpha: 0.12),
                  child: Icon(
                    _statusIcon(status),
                    color: _statusColor(status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alert['full_name']?.toString() ?? 'Unknown user',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            Text(
              alert['message']?.toString() ?? 'Emergency assistance requested',
              style: const TextStyle(height: 1.4),
            ),

            const SizedBox(height: 10),

            // Location
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

            const SizedBox(height: 8),

            // Phone number
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    phoneNumber.isEmpty
                        ? 'Phone number unavailable'
                        : phoneNumber,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Submission date and time
            Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _formatDate(alert['created_at']),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            if (alert['responded_at'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Response started: '
                          '${_formatDate(alert['responded_at'])}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (alert['resolved_at'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Resolved: '
                          '${_formatDate(alert['resolved_at'])}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Contact and map buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: phoneNumber.isEmpty
                        ? null
                        : () {
                      _callUser(phoneNumber);
                    },
                    icon: const Icon(Icons.phone_outlined),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                    latitude == null || longitude == null
                        ? null
                        : () {
                      _openLocation(
                        latitude: latitude,
                        longitude: longitude,
                      );
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open Map'),
                  ),
                ),
              ],
            ),

            if (!isResolved) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isUpdating
                      ? null
                      : () {
                    _confirmStatusUpdate(
                      id: id,
                      newStatus: isActive
                          ? 'responding'
                          : 'resolved',
                    );
                  },
                  icon: isUpdating
                      ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Icon(
                    isActive
                        ? Icons.support_agent
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    isUpdating
                        ? 'Updating...'
                        : isActive
                        ? 'Start Responding'
                        : 'Mark as Resolved',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    isResponding ? Colors.green : Colors.orange,
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

  Color _statusColor(String status) {
    switch (status) {
      case 'responding':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'responding':
        return Icons.support_agent;
      case 'resolved':
        return Icons.check_circle;
      default:
        return Icons.sos;
    }
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
              runSpacing: 8,
              children: [
                _filterChip('all', 'All'),
                _filterChip('active', 'Active'),
                _filterChip('responding', 'Responding'),
                _filterChip('resolved', 'Resolved'),
              ],
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (displayedAlerts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: Text('No SOS records found')),
              )
            else
              ...displayedAlerts.map(_alertCard),
          ],
        ),
      ),
    );
  }
}
