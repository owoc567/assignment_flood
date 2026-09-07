import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() =>
      _AnnouncementsPageState();
}

class _AnnouncementsPageState
    extends State<AnnouncementsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _supabase
          .from('announcements')
          .select(
        'id, title, message, area, announcement_type, '
            'created_at, expires_at',
      )
          .eq('is_active', true)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _announcements =
        List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load announcements: $error'),
        ),
      );
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Evacuation':
        return Colors.red;
      case 'Flood Warning':
        return Colors.orange;
      default:
        return const Color(0xFF4A45D6);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Evacuation':
        return Icons.warning_amber_rounded;
      case 'Flood Warning':
        return Icons.flood_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return '';

    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _announcementCard(
      Map<String, dynamic> announcement,
      ) {
    final type =
        announcement['announcement_type']?.toString() ??
            'General';

    final color = _typeColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE0E0E6),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              _typeIcon(type),
              color: color,
              size: 24,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        announcement['title']?.toString() ??
                            'Announcement',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                Text(
                  announcement['message']?.toString() ?? '',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                if (announcement['area'] != null &&
                    announcement['area']
                        .toString()
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        announcement['area'].toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 7),

                Text(
                  _formatDate(announcement['created_at']),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Announcements'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnnouncements,
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : _announcements.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 180),
            Icon(
              Icons.campaign_outlined,
              size: 65,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Center(
              child: Text(
                'No announcements available',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        )
            : ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            14,
            16,
            20,
          ),
          children: [
            const Text(
              'Official updates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Important flood and safety information',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 15),
            ..._announcements.map(
              _announcementCard,
            ),
          ],
        ),
      ),
    );
  }
}