import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MySubmissionsPage extends StatefulWidget {
  const MySubmissionsPage({super.key});

  @override
  State<MySubmissionsPage> createState() =>
      _MySubmissionsPageState();
}

class _MySubmissionsPageState
    extends State<MySubmissionsPage> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _sosRecords = [];
  List<Map<String, dynamic>> _floodReports = [];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please sign in again.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _supabase
            .from('sos_alerts')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false),

        _supabase
            .from('flood_reports')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false),
      ]);

      if (!mounted) return;

      setState(() {
        _sosRecords =
        List<Map<String, dynamic>>.from(results[0]);

        _floodReports =
        List<Map<String, dynamic>>.from(results[1]);

        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Submission loading error: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
        'Unable to load your submissions.\n$error';
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'resolved':
        return Colors.green;

      case 'rejected':
        return Colors.red;

      case 'active':
        return Colors.orange;

      case 'pending':
        return Colors.blueGrey;

      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'resolved':
        return Icons.check_circle_outline;

      case 'rejected':
        return Icons.cancel_outlined;

      case 'active':
        return Icons.crisis_alert_rounded;

      case 'pending':
        return Icons.access_time_rounded;

      default:
        return Icons.help_outline;
    }
  }

  String _formatStatus(dynamic value) {
    final status = value?.toString() ?? 'pending';

    if (status.isEmpty) {
      return 'Pending';
    }

    return status[0].toUpperCase() +
        status.substring(1).toLowerCase();
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return 'Date unavailable';
    }

    try {
      final dateTime =
      DateTime.parse(value.toString()).toLocal();

      final day = dateTime.day.toString().padLeft(2, '0');
      final month =
      dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();

      final hour =
      dateTime.hour.toString().padLeft(2, '0');
      final minute =
      dateTime.minute.toString().padLeft(2, '0');

      return '$day/$month/$year  $hour:$minute';
    } catch (_) {
      return value.toString();
    }
  }

  Widget _buildStatusChip(dynamic value) {
    final status =
        value?.toString().toLowerCase() ?? 'pending';

    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            _formatStatus(status),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSosCard(Map<String, dynamic> sos) {
    final message =
        sos['message']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sos_rounded,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency SOS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Submitted to the response team',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(sos['status']),
              ],
            ),

            if (message.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDate(sos['created_at']),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
      Map<String, dynamic> report,
      ) {
    final description =
        report['description']?.toString().trim() ?? '';

    final photoUrl =
        report['photo_url']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoUrl.isNotEmpty)
            Image.network(
              photoUrl,
              width: double.infinity,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (
                  context,
                  error,
                  stackTrace,
                  ) {
                return const SizedBox.shrink();
              },
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A45D6)
                            .withOpacity(0.10),
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.flood_rounded,
                        color: Color(0xFF4A45D6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Flood Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Submitted for admin verification',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(report['status']),
                  ],
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatDate(
                          report['created_at'],
                        ),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 90),
        Icon(
          icon,
          size: 70,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSosList() {
    if (_sosRecords.isEmpty) {
      return _buildEmptyState(
        icon: Icons.sos_outlined,
        title: 'No SOS records',
        message:
        'Your submitted emergency SOS records will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSubmissions,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _sosRecords.length,
        itemBuilder: (context, index) {
          return _buildSosCard(_sosRecords[index]);
        },
      ),
    );
  }

  Widget _buildReportsList() {
    if (_floodReports.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No flood reports',
        message:
        'Your submitted flood reports will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSubmissions,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _floodReports.length,
        itemBuilder: (context, index) {
          return _buildReportCard(
            _floodReports[index],
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadSubmissions,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            'My Submissions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF4A45D6),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF4A45D6),
            tabs: [
              Tab(
                icon: Icon(Icons.sos_outlined),
                text: 'My SOS',
              ),
              Tab(
                icon: Icon(Icons.assignment_outlined),
                text: 'My Reports',
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4A45D6),
          ),
        )
            : _errorMessage != null
            ? _buildErrorState()
            : TabBarView(
          children: [
            _buildSosList(),
            _buildReportsList(),
          ],
        ),
      ),
    );
  }
}