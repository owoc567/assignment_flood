import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageReportsPage extends StatefulWidget {
  const ManageReportsPage({super.key});

  @override
  State<ManageReportsPage> createState() =>
      _ManageReportsPageState();
}

class _ManageReportsPageState
    extends State<ManageReportsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _selectedFilter = 'all';
  String? _updatingReportId;

  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _supabase.from('flood_reports').select(
        'id, user_id, full_name, latitude, longitude, '
            'description, photo_url, status, verified_by, verified_at',
      );

      if (!mounted) return;

      setState(() {
        _reports = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load reports: $error'),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    if (_selectedFilter == 'all') {
      return _reports;
    }

    return _reports.where((report) {
      return report['status'] == _selectedFilter;
    }).toList();
  }

  Future<void> _updateStatus(
      String reportId,
      String newStatus,
      ) async {
    final admin = _supabase.auth.currentUser;

    if (admin == null) return;

    setState(() {
      _updatingReportId = reportId;
    });

    try {
      await _supabase
          .from('flood_reports')
          .update({
        'status': newStatus,
        'verified_by': admin.id,
        'verified_at': DateTime.now().toIso8601String(),
      })
          .eq('id', reportId);

      await _loadReports();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'verified'
                ? 'Report verified successfully'
                : 'Report rejected',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update report: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingReportId = null;
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _buildFilterButton(String value, String label) {
    final selected = _selectedFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: const Color(0xFF3730A3),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final id = report['id'].toString();
    final status = report['status']?.toString() ?? 'pending';
    final imageUrl = report['photo_url']?.toString();
    final isUpdating = _updatingReportId == id;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFFE4E4EA),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE8E7FF),
                  child: Icon(
                    Icons.flood,
                    color: Color(0xFF3730A3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    report['full_name']?.toString() ??
                        'Unknown user',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const SizedBox.shrink();
                  },
                ),
              ),

            if (imageUrl != null && imageUrl.isNotEmpty)
              const SizedBox(height: 12),

            Text(
              report['description']?.toString() ??
                  'No description',
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
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
                    '${report['latitude']}, '
                        '${report['longitude']}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            if (status == 'pending') ...[
              const SizedBox(height: 15),
              const Divider(),
              const SizedBox(height: 8),

              if (isUpdating)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _updateStatus(id, 'rejected');
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _updateStatus(id, 'verified');
                        },
                        icon: const Icon(Icons.verified),
                        label: const Text('Verify'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFF3730A3),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedReports = _filteredReports;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3730A3),
        foregroundColor: Colors.white,
        title: const Text('Manage Flood Reports'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterButton('all', 'All'),
                _buildFilterButton('pending', 'Pending'),
                _buildFilterButton('verified', 'Verified'),
                _buildFilterButton('rejected', 'Rejected'),
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
            else if (displayedReports.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: Text('No reports found'),
                ),
              )
            else
              ...displayedReports.map(_buildReportCard),
          ],
        ),
      ),
    );
  }
}