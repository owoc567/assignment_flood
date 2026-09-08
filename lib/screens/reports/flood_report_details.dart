import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class FloodReportDetailsPage extends StatefulWidget {
  final Map<String, dynamic> report;
  final bool isAdmin;

  const FloodReportDetailsPage({
    super.key,
    required this.report,
    required this.isAdmin,
  });

  @override
  State<FloodReportDetailsPage> createState() =>
      _FloodReportDetailsPageState();
}

class _FloodReportDetailsPageState
    extends State<FloodReportDetailsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoadingProfile = false;
  bool _isUpdating = false;

  String? _phoneNumber;
  String? _address;
  late String _status;

  @override
  void initState() {
    super.initState();

    _status =
        widget.report['status']?.toString() ?? 'pending';

    if (widget.isAdmin) {
      _loadReporterProfile();
    }
  }

  Future<void> _loadReporterProfile() async {
    final userId =
    widget.report['user_id']?.toString();

    if (userId == null || userId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final profile = await _supabase
          .from('profiles')
          .select('phone_number, address')
          .eq('id', userId)
          .single();

      if (!mounted) return;

      setState(() {
        _phoneNumber =
            profile['phone_number']?.toString();

        _address = profile['address']?.toString();

        _isLoadingProfile = false;
      });
    } catch (error) {
      debugPrint(
        'Unable to load reporter profile: $error',
      );

      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  String? _getPhotoUrl() {
    final storedValue =
        widget.report['photo_url']?.toString().trim() ?? '';

    if (storedValue.isEmpty) {
      return null;
    }

    if (storedValue.startsWith('http://') ||
        storedValue.startsWith('https://')) {
      return storedValue;
    }

    return _supabase.storage
        .from('flood-photos')
        .getPublicUrl(storedValue);
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return 'Not available';
    }

    final date = DateTime.tryParse(
      value.toString(),
    )?.toLocal();

    if (date == null) {
      return 'Not available';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year}  $hour:$minute';
  }

  Color _statusColor() {
    switch (_status.toLowerCase()) {
      case 'verified':
        return Colors.green;

      case 'rejected':
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon() {
    switch (_status.toLowerCase()) {
      case 'verified':
        return Icons.verified_outlined;

      case 'rejected':
        return Icons.cancel_outlined;

      default:
        return Icons.access_time_rounded;
    }
  }

  String _statusTitle() {
    switch (_status.toLowerCase()) {
      case 'verified':
        return 'Verified';

      case 'rejected':
        return 'Rejected';

      default:
        return 'Pending';
    }
  }

  String _statusMessage() {
    switch (_status.toLowerCase()) {
      case 'verified':
        return 'The administrator confirmed this flood report.';

      case 'rejected':
        return 'The administrator could not verify this flood report.';

      default:
        return 'This report is waiting for administrator review.';
    }
  }

  Future<void> _openMap() async {
    final latitude = double.tryParse(
      widget.report['latitude']?.toString() ?? '',
    );

    final longitude = double.tryParse(
      widget.report['longitude']?.toString() ?? '',
    );

    if (latitude == null || longitude == null) {
      _showMessage('Location is unavailable.');
      return;
    }

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

  Future<void> _confirmStatusUpdate(
      String newStatus,
      ) async {
    final verifying = newStatus == 'verified';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            verifying
                ? 'Verify Flood Report?'
                : 'Reject Flood Report?',
          ),
          content: Text(
            verifying
                ? 'Confirm that the submitted flood information is valid.'
                : 'Confirm that this report should be rejected.',
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
                verifying ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                verifying ? 'Verify' : 'Reject',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _updateStatus(newStatus);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdating) return;

    final admin = _supabase.auth.currentUser;
    final reportId =
    widget.report['id']?.toString();

    if (admin == null ||
        reportId == null ||
        reportId.isEmpty) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await _supabase
          .from('flood_reports')
          .update({
        'status': newStatus,
        'verified_by': admin.id,
        'verified_at':
        DateTime.now().toUtc().toIso8601String(),
      })
          .eq('id', reportId);

      if (!mounted) return;

      setState(() {
        _status = newStatus;
        _isUpdating = false;
      });

      _showMessage(
        newStatus == 'verified'
            ? 'Report verified successfully.'
            : 'Report rejected.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
      });

      _showMessage(
        'Unable to update report: $error',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _informationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: const Color(0xFF4A45D6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE3E3E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _getPhotoUrl();

    final description =
        widget.report['description']
            ?.toString()
            .trim() ??
            '';

    final reporterName =
        widget.report['full_name']
            ?.toString()
            .trim() ??
            '';

    final latitude =
        widget.report['latitude']?.toString() ??
            'Unavailable';

    final longitude =
        widget.report['longitude']?.toString() ??
            'Unavailable';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3730A3),
        foregroundColor: Colors.white,
        title: const Text('Flood Report Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (photoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  photoUrl,
                  width: double.infinity,
                  height: 240,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 240,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Unable to load photo',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'No photo available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _statusColor()
                    .withValues(alpha: 0.10),
                borderRadius:
                BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusIcon(),
                    color: _statusColor(),
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusTitle(),
                          style: TextStyle(
                            color: _statusColor(),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _statusMessage(),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (widget.isAdmin) ...[
              const SizedBox(height: 16),
              _section(
                title: 'Reporter Information',
                children: [
                  _informationRow(
                    icon: Icons.person_outline,
                    label: 'Full name',
                    value: reporterName.isEmpty
                        ? 'Unknown user'
                        : reporterName,
                  ),
                  if (_isLoadingProfile)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child:
                        CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    _informationRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone number',
                      value: _phoneNumber
                          ?.trim()
                          .isNotEmpty ==
                          true
                          ? _phoneNumber!
                          : 'Not provided',
                    ),
                    _informationRow(
                      icon:
                      Icons.location_on_outlined,
                      label: 'Address',
                      value:
                      _address?.trim().isNotEmpty ==
                          true
                          ? _address!
                          : 'Not provided',
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 16),

            _section(
              title: 'Report Information',
              children: [
                _informationRow(
                  icon: Icons.description_outlined,
                  label: 'Description',
                  value: description.isEmpty
                      ? 'No description provided'
                      : description,
                ),
                _informationRow(
                  icon: Icons.my_location_outlined,
                  label: 'Coordinates',
                  value: '$latitude, $longitude',
                ),
                _informationRow(
                  icon: Icons.schedule_outlined,
                  label: 'Submitted',
                  value: _formatDate(
                    widget.report['created_at'],
                  ),
                ),
                if (widget.report['verified_at'] !=
                    null)
                  _informationRow(
                    icon: Icons.fact_check_outlined,
                    label: 'Reviewed',
                    value: _formatDate(
                      widget.report['verified_at'],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open Location'),
              ),
            ),

            if (widget.isAdmin &&
                _status == 'pending') ...[
              const SizedBox(height: 12),

              if (_isUpdating)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _confirmStatusUpdate(
                            'rejected',
                          );
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style:
                        OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _confirmStatusUpdate(
                            'verified',
                          );
                        },
                        icon:
                        const Icon(Icons.verified),
                        label: const Text('Verify'),
                        style:
                        ElevatedButton.styleFrom(
                          backgroundColor:
                          Colors.green,
                          foregroundColor:
                          Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}