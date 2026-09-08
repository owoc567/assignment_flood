import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _supabase
          .from('profiles')
          .select(
            'id, full_name, email, phone_number, '
            'profile_image_url, role, created_at',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
        _filteredUsers = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _searchUsers(String value) {
    final keyword = value.trim().toLowerCase();

    setState(() {
      if (keyword.isEmpty) {
        _filteredUsers = List<Map<String, dynamic>>.from(_users);
      } else {
        _filteredUsers = _users.where((user) {
          final name = user['full_name']?.toString().toLowerCase() ?? '';

          final email = user['email']?.toString().toLowerCase() ?? '';

          final role = user['role']?.toString().toLowerCase() ?? '';

          return name.contains(keyword) ||
              email.contains(keyword) ||
              role.contains(keyword);
        }).toList();
      }
    });
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Unknown';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return 'Unknown';

    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final fullName = user['full_name']?.toString().trim() ?? '';

    final email = user['email']?.toString() ?? 'No email';
    final phone = user['phone_number']?.toString();
    final imageUrl = user['profile_image_url']?.toString();
    final role = user['role']?.toString() ?? 'user';

    final isAdmin = role == 'admin';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color(0xFFE4E4EA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: const Color(0xFFE8E7FF),
              backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl)
                  : null,
              child: imageUrl == null || imageUrl.isEmpty
                  ? const Icon(Icons.person, color: Color(0xFF3730A3))
                  : null,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fullName.isEmpty ? 'No name' : fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? const Color(0xFFFFE5E5)
                              : const Color(0xFFE8E7FF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          isAdmin ? 'Admin' : 'User',
                          style: TextStyle(
                            color: isAdmin
                                ? Colors.red
                                : const Color(0xFF3730A3),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    email,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),

                  if (phone != null && phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],

                  const SizedBox(height: 6),

                  Text(
                    'Joined: ${_formatDate(user['created_at'])}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        title: const Text('Manage Users'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Search name, email or role',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load users\n$_errorMessage',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadUsers,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
            else if (_filteredUsers.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: Text('No users found')),
              )
            else ...[
              Text(
                '${_filteredUsers.length} account(s)',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ..._filteredUsers.map(_buildUserCard),
            ],
          ],
        ),
      ),
    );
  }
}
