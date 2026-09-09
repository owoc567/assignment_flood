import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:assignment_flood/screens/reports/flood_report_details.dart';

class ManageReportsPage extends StatefulWidget {
  const ManageReportsPage({super.key});

  @override
  State<ManageReportsPage> createState() => _ManageReportsPageState();
}

class _ManageReportsPageState extends State<ManageReportsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _selectedFilter = 'all';

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
      final data = await _supabase
          .from('flood_reports')
          .select(
              'id, user_id, full_name, latitude, longitude, '
                  'description, photo_url, status, created_at, '
                  'verified_by, verified_at',
            )
          .order('created_at', ascending: false);

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load reports: $error')));
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
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return 'Date unavailable';
    }

    final date = DateTime.tryParse(
      value.toString(),
    )?.toLocal();

    if (date == null) {
      return 'Date unavailable';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year}  $hour:$minute';
  }

  Future<void> _openReportDetails(
      Map<String, dynamic> report,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FloodReportDetailsPage(
          report: report,
          isAdmin: true,
        ),
      ),
    );

    // Refresh because the admin may have verified or rejected it.
    await _loadReports();
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final status =
        report['status']?.toString() ?? 'pending';

    final description =
        report['description']?.toString().trim() ?? '';

    final fullName =
        report['full_name']?.toString().trim() ?? '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFFE4E4EA),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _openReportDetails(report);
        },
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
                      fullName.isEmpty
                          ? 'Unknown user'
                          : fullName,
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
                      borderRadius:
                      BorderRadius.circular(15),
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

              const SizedBox(height: 13),

              Text(
                description.isEmpty
                    ? 'No description provided'
                    : description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 17,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatDate(report['created_at']),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _openReportDetails(report);
                    },
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 18,
                    ),
                    label: const Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
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
                child: Center(child: CircularProgressIndicator()),
              )
            else if (displayedReports.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: Text('No reports found')),
              )
            else
              ...displayedReports.map(_buildReportCard),
          ],
        ),
      ),
    );
  }
}
