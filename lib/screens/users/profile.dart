import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:assignment_flood/screens/users/signIn.dart';
import 'package:assignment_flood/screens/users/editProfile.dart';
import 'package:assignment_flood/screens/users/changePassword.dart';
import 'package:assignment_flood/screens/emergency/sos.dart';
import 'package:assignment_flood/screens/users/mySubmissions.dart';
import 'package:assignment_flood/services/offline_profile_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  bool _isLoggingOut = false;
  bool _isDeletingAccount = false;

  String? _fullName;
  String? _profileImageUrl;
  String _role = 'user';
  String? _email;
  String? _phoneNumber;
  String? _address;
  DateTime? _createdAt;

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
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignIn()),
        );
        return;
      }

      final data = await supabase
          .from('profiles')
          .select(
            'full_name, phone_number, profile_image_url, '
            'role, email, address, created_at',
          )
          .eq('id', user.id)
          .single();

      await OfflineProfileService.saveProfile(
        userId: user.id,
        fullName: data['full_name']?.toString() ?? '',
        email: data['email']?.toString() ?? user.email ?? '',
        phoneNumber: data['phone_number']?.toString() ?? '',
        address: data['address']?.toString() ?? '',
        role: data['role']?.toString() ?? 'user',
        profileImageUrl: data['profile_image_url']?.toString(),
        createdAt: data['created_at']?.toString(),
      );

      if (!mounted) return;

      setState(() {
        _fullName = data['full_name']?.toString();
        _phoneNumber = data['phone_number']?.toString();
        _profileImageUrl = data['profile_image_url']?.toString();
        _role = data['role']?.toString() ?? 'user';
        _email = data['email']?.toString();
        _address = data['address']?.toString();

        _createdAt = data['created_at'] == null
            ? null
            : DateTime.tryParse(data['created_at'].toString());

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Unable to load online profile: $e');

      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      final cachedProfile =
      await OfflineProfileService.loadProfile(user.id);

      if (!mounted) return;

      final cachedImage =
          cachedProfile['profile_image_url']?.trim() ?? '';

      final cachedDate =
          cachedProfile['created_at']?.trim() ?? '';

      setState(() {
        _fullName = cachedProfile['full_name'];
        _email = cachedProfile['email'];
        _phoneNumber = cachedProfile['phone_number'];
        _address = cachedProfile['address'];
        _role = cachedProfile['role'] ?? 'user';

        _profileImageUrl =
        cachedImage.isEmpty ? null : cachedImage;

        _createdAt = cachedDate.isEmpty
            ? null
            : DateTime.tryParse(cachedDate);

        _isLoading = false;
      });
    }
  }



  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade900,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && !_isLoggingOut) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignIn()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      setState(() {
        _isLoggingOut = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;

    setState(() {
      _isDeletingAccount = true;
    });

    final supabase = Supabase.instance.client;

    try {
      await supabase.rpc('delete_my_account');

      // Clear the login session saved on the phone.
      try {
        await supabase.auth.signOut();
      } catch (_) {
        // The Authentication account has already been deleted.
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SignIn()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  Color _roleColor() {
    return _role == 'admin' ? const Color(0xFFFF174F) : const Color(0xFF4A45D6);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16.0),

                    // Profile image
                    ClipOval(
                      child: _profileImageUrl != null
                          ? Image.network(
                              _profileImageUrl!,
                              width: 130,
                              height: 130,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/images/profileImageDefault.jpg',
                                  width: 130,
                                  height: 130,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(
                              'assets/images/profileImageDefault.jpg',
                              width: 130,
                              height: 130,
                              fit: BoxFit.cover,
                            ),
                    ),

                    const SizedBox(height: 14.0),

                    // Name
                    Text(
                      _fullName?.isNotEmpty == true
                          ? _fullName!
                          : 'No name set',
                      style: const TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8.0),

                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _roleColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _role == 'admin' ? 'Admin' : 'User',
                        style: TextStyle(
                          color: _roleColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // SOS button - prominent
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SosPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.sos),
                        label: const Text('Emergency SOS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // Account options
                    _profileMenuTile(
                      icon: Icons.edit_outlined,
                      title: 'Edit Profile',
                      onTap: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfilePage(),
                          ),
                        );
                        if (updated == true) {
                          _loadProfile();
                        }
                      },
                    ),_profileMenuTile(
                      icon: Icons.person_outline,
                      title: 'Personal Information',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PersonalInformationPage(
                              fullName: _fullName,
                              email: _email,
                              phoneNumber: _phoneNumber,
                              address: _address,
                              role: _role,
                              createdAt: _createdAt,
                            ),
                          ),
                        );
                      },
                    ),
                    _profileMenuTile(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'My Submissions',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MySubmissionsPage(),
                          ),
                        );
                      },
                    ),

                    _profileMenuTile(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChangePasswordPage(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24.0),

                    _profileMenuTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Delete Account',
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              title: const Text('Delete Account?'),
                              content: const Text(
                                'This will permanently delete your account and all related data. '
                                'This action cannot be undone.',
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
                                  child: const Text('Delete Account'),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmed == true && !_isDeletingAccount) {
                          await _deleteAccount();
                        }
                      },
                    ),

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoggingOut ? null : _confirmLogout,
                        icon: _isLoggingOut
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _profileMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4A45D6)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class PersonalInformationPage extends StatelessWidget {
  final String? fullName;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final String role;
  final DateTime? createdAt;

  const PersonalInformationPage({
    super.key,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.role,
    required this.createdAt,
  });

  String _formatPhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not provided';
    }

    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('60')) {
      digits = '0${digits.substring(2)}';
    }

    if (RegExp(r'^011\d{8}$').hasMatch(digits)) {
      return '+60 ${digits.substring(1, 3)}-'
          '${digits.substring(3, 7)} '
          '${digits.substring(7)}';
    }

    if (RegExp(r'^01[02-9]\d{7}$').hasMatch(digits)) {
      return '+60 ${digits.substring(1, 3)}-'
          '${digits.substring(3, 6)} '
          '${digits.substring(6)}';
    }

    return 'Invalid phone number';
  }

  String _formatDate() {
    if (createdAt == null) {
      return 'Not available';
    }

    final date = createdAt!.toLocal();
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF4A45D6), size: 23),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
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
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Personal Information'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E6)),
          ),
          child: Column(
            children: [
              _detailRow(
                icon: Icons.person_outline,
                label: 'Full name',
                value: fullName?.isNotEmpty == true
                    ? fullName!
                    : 'Not provided',
              ),
              const Divider(height: 1),
              _detailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: email?.isNotEmpty == true ? email! : 'Not provided',
              ),
              const Divider(height: 1),
              _detailRow(
                icon: Icons.phone_outlined,
                label: 'Phone number',
                value: _formatPhoneNumber(phoneNumber),
              ),
              const Divider(height: 1),
              _detailRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: address?.trim().isNotEmpty == true
                    ? address!.trim()
                    : 'Not provided',
              ),
              const Divider(height: 1),
              _detailRow(
                icon: Icons.badge_outlined,
                label: 'Account role',
                value: role == 'admin' ? 'Admin' : 'User',
              ),
              const Divider(height: 1),
              _detailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Member since',
                value: _formatDate(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
