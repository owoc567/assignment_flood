import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:assignment_flood/screens/users/editProfile.dart';
import 'package:assignment_flood/screens/users/changePassword.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;

  String _fullName = 'Administrator';
  String _email = '';
  String _phoneNumber = '';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('No logged-in admin found');
      }

      final profile = await _supabase
          .from('profiles')
          .select(
            'full_name, email, phone_number, '
            'profile_image_url, role',
          )
          .eq('id', currentUser.id)
          .single();

      if (!mounted) return;

      setState(() {
        _fullName = profile['full_name']?.toString() ?? 'Administrator';

        _email = profile['email']?.toString() ?? currentUser.email ?? '';

        _phoneNumber = profile['phone_number']?.toString() ?? '';

        _profileImageUrl = profile['profile_image_url']?.toString();

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $error')));
    }
  }

  Widget _informationTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE4E4EA)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF3730A3)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? 'Not provided' : value,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3730A3),
        foregroundColor: Colors.white,
        title: const Text('Admin Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 10),

                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 65,
                          backgroundColor: const Color(0xFFE8E7FF),
                          backgroundImage:
                              _profileImageUrl != null &&
                                  _profileImageUrl!.isNotEmpty
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child:
                              _profileImageUrl == null ||
                                  _profileImageUrl!.isEmpty
                              ? const Icon(
                                  Icons.admin_panel_settings,
                                  size: 65,
                                  color: Color(0xFF3730A3),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3730A3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 17),

                  Text(
                    _fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'System Administrator',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF3730A3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 28),

                  _informationTile(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: _email,
                  ),

                  _informationTile(
                    icon: Icons.phone_outlined,
                    title: 'Phone Number',
                    value: _phoneNumber,
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfilePage(),
                          ),
                        );

                        if (updated == true) {
                          await _loadProfile();
                        }
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3730A3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 11),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChangePasswordPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Change Password'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3730A3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
