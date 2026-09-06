import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manage_announcements.dart';
import 'manageUsers.dart';
import 'manageReports.dart';
import 'manageSos.dart';
import 'manageCommunity.dart';
import 'adminProfile.dart';


class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _adminName = 'Administrator';
  String? _adminProfileImageUrl;

  bool _isLoadingProfile = true;
  bool _isLoadingDashboard = true;

  int _totalUsers = 0;
  int _totalReports = 0;
  int _pendingReports = 0;
  int _activeSos = 0;
  int _communityPosts = 0;
  int _activeAnnouncements = 0;


  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoadingDashboard = true;
    });

    try {
      await _loadAdminProfile();

      final results = await Future.wait([
        _supabase.from('profiles').select('id'),
        _supabase.from('flood_reports').select('id, status'),
        _supabase.from('sos_alerts').select('id, status'),
        _supabase.from('community_posts').select('id'),
        _supabase.from('announcements').select('id, is_active'),
      ]);

      final users = results[0] as List;
      final reports = results[1] as List;
      final sosAlerts = results[2] as List;
      final communityPosts = results[3] as List;
      final announcements = results[4] as List;

      if (!mounted) return;

      setState(() {
        _totalUsers = users.length;
        _totalReports = reports.length;

        _pendingReports = reports.where((report) {
          return report['status'] == 'pending';
        }).length;

        _activeSos = sosAlerts.where((alert) {
          return alert['status'] == 'active';
        }).length;

        _communityPosts = communityPosts.length;

        _activeAnnouncements = announcements.where((announcement) {
          return announcement['is_active'] == true;
        }).length;

        _isLoadingDashboard = false;
      });
    } catch (error) {
      debugPrint('Dashboard loading error: $error');

      if (!mounted) return;

      setState(() {
        _isLoadingDashboard = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load dashboard: $error'),
        ),
      );
    }
  }

  Future<void> _loadAdminProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
      });
      return;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select(
        'full_name, role, profile_image_url',
      )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _adminName =
            profile?['full_name']?.toString() ??
                'Administrator';

        _adminProfileImageUrl =
            profile?['profile_image_url']?.toString();

        _isLoadingProfile = false;
      });
    } catch (error) {
      debugPrint('Admin profile error: $error');

      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  void _showComingSoon(String functionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$functionName page will be connected next',
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text(
            'Are you sure you want to sign out?',
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) {
      return;
    }

    await _supabase.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
          (route) => false,
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFFE6E6EC),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminFunctionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFFE6E6EC),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF3730A3),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'MyFlood Malaysia',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Admin Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminProfilePage(),
                ),
              ).then((_) {
                _loadDashboard();
              });
            },
          ),
          IconButton(
            tooltip: 'Sign Out',
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF3730A3),
                    Color(0xFF625BD9),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    backgroundImage: _adminProfileImageUrl != null &&
                        _adminProfileImageUrl!.isNotEmpty
                        ? NetworkImage(_adminProfileImageUrl!)
                        : null,
                    child: _adminProfileImageUrl == null ||
                        _adminProfileImageUrl!.isEmpty
                        ? const Icon(
                      Icons.admin_panel_settings,
                      size: 32,
                      color: Color(0xFF3730A3),
                    )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isLoadingProfile
                              ? 'Loading...'
                              : _adminName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'System Administrator',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'System Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                _buildSummaryCard(
                  title: 'Pending reports',
                  value: _isLoadingDashboard
                      ? '...'
                      : _pendingReports.toString(),
                  icon: Icons.assignment_late_outlined,
                  color: Colors.orange,
                ),
                const SizedBox(width: 10),
                _buildSummaryCard(
                  title: 'Active announcements',
                  value: _isLoadingDashboard
                      ? '...'
                      : _activeAnnouncements.toString(),
                  icon: Icons.campaign_outlined,
                  color: Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 22),


            Row(
              children: [
                _buildSummaryCard(
                  title: 'Total users',
                  value: _isLoadingDashboard
                      ? '...'
                      : _totalUsers.toString(),
                  icon: Icons.people_outline,
                  color: Colors.purple,
                ),
                const SizedBox(width: 10),
                _buildSummaryCard(
                  title: 'Active SOS',
                  value: _isLoadingDashboard
                      ? '...'
                      : _activeSos.toString(),
                  icon: Icons.sos,
                  color: Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 22),

            const Text(
              'Administration',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),



            _buildAdminFunctionCard(
              title: 'Manage Flood Reports',
              subtitle: 'Verify or reject reports submitted by users',
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF159957),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageReportsPage(),
                  ),
                ).then((_) {
                  _loadDashboard();
                });
              },
            ),

            _buildAdminFunctionCard(
              title: 'Manage Community Posts',
              subtitle: 'Verify posts and remove spam content',
              icon: Icons.forum_outlined,
              color: const Color(0xFF1976D2),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageCommunityPage(),
                  ),
                ).then((_) {
                  _loadDashboard();
                });
              },
            ),

            _buildAdminFunctionCard(
              title: 'Manage SOS Records',
              subtitle: 'View emergency requests and mark them as resolved',
              icon: Icons.sos,
              color: Colors.red,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageSosPage(),
                  ),
                ).then((_) {
                  _loadDashboard();
                });
              },
            ),

            _buildAdminFunctionCard(
              title: 'Manage Announcements',
              subtitle:
              'Send evacuation and warning announcements',
              icon: Icons.campaign_outlined,
              color: const Color(0xFFE53935),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const ManageAnnouncementsPage(),
                    ),
                );
              },
            ),

            _buildAdminFunctionCard(
              title: 'Manage Users',
              subtitle:
              'View, suspend and reactivate user accounts',
              icon: Icons.people_outline,
              color: const Color(0xFF7B2CBF),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageUsersPage(),
                  ),
                ).then((_) {
                  _loadDashboard();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}