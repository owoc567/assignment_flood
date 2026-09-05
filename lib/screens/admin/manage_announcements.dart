import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageAnnouncementsPage extends StatefulWidget {
  const ManageAnnouncementsPage({super.key});

  @override
  State<ManageAnnouncementsPage> createState() =>
      _ManageAnnouncementsPageState();
}

class _ManageAnnouncementsPageState
    extends State<ManageAnnouncementsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _announcements =
        List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Failed to load announcements: $error',
        isError: true,
      );
    }
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _openAnnouncementForm({
    Map<String, dynamic>? announcement,
  }) async {
    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController(
      text: announcement?['title']?.toString() ?? '',
    );

    final locationController = TextEditingController(
      text: announcement?['location']?.toString() ?? '',
    );

    final messageController = TextEditingController(
      text: announcement?['message']?.toString() ?? '',
    );

    String selectedType =
        announcement?['announcement_type']?.toString() ??
            'General';

    bool isActive =
        announcement?['is_active'] as bool? ?? true;

    bool isSaving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> saveAnnouncement() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              final currentUser =
                  _supabase.auth.currentUser;

              if (currentUser == null) {
                _showMessage(
                  'Admin is not signed in',
                  isError: true,
                );
                return;
              }

              setSheetState(() {
                isSaving = true;
              });

              final data = {
                'title': titleController.text.trim(),
                'location':
                locationController.text.trim().isEmpty
                    ? null
                    : locationController.text.trim(),
                'message': messageController.text.trim(),
                'announcement_type': selectedType,
                'is_active': isActive,
              };

              try {
                if (announcement == null) {
                  await _supabase
                      .from('announcements')
                      .insert({
                    ...data,
                    'created_by': currentUser.id,
                  });
                } else {
                  await _supabase
                      .from('announcements')
                      .update(data)
                      .eq('id', announcement['id']);
                }

                if (!bottomSheetContext.mounted) return;

                Navigator.pop(bottomSheetContext, true);
              } catch (error) {
                setSheetState(() {
                  isSaving = false;
                });

                _showMessage(
                  'Unable to save announcement: $error',
                  isError: true,
                );
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          announcement == null
                              ? 'Create Announcement'
                              : 'Edit Announcement',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),

                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Announcement type',
                            border: OutlineInputBorder(),
                            prefixIcon:
                            Icon(Icons.warning_amber),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'General',
                              child: Text('General'),
                            ),
                            DropdownMenuItem(
                              value: 'Flood Warning',
                              child: Text('Flood Warning'),
                            ),
                            DropdownMenuItem(
                              value: 'Evacuation',
                              child: Text('Evacuation'),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) {
                            if (value != null) {
                              setSheetState(() {
                                selectedType = value;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: titleController,
                          enabled: !isSaving,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (value) {
                            final title = value?.trim() ?? '';

                            if (title.isEmpty) {
                              return 'Please enter a title';
                            }

                            if (title.length < 3) {
                              return 'Title must have at least 3 characters';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: locationController,
                          enabled: !isSaving,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Location (optional)',
                            hintText: 'Example: Setapak',
                            border: OutlineInputBorder(),
                            prefixIcon:
                            Icon(Icons.location_on_outlined),
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: messageController,
                          enabled: !isSaving,
                          minLines: 4,
                          maxLines: 7,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                            prefixIcon:
                            Icon(Icons.message_outlined),
                          ),
                          validator: (value) {
                            final message =
                                value?.trim() ?? '';

                            if (message.isEmpty) {
                              return 'Please enter a message';
                            }

                            if (message.length < 10) {
                              return 'Message must have at least 10 characters';
                            }

                            return null;
                          },
                        ),

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Active announcement',
                          ),
                          subtitle: Text(
                            isActive
                                ? 'Users can view this announcement'
                                : 'Hidden from normal users',
                          ),
                          value: isActive,
                          activeThumbColor:
                          const Color(0xFF3730A3),
                          onChanged: isSaving
                              ? null
                              : (value) {
                            setSheetState(() {
                              isActive = value;
                            });
                          },
                        ),

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                            isSaving ? null : saveAnnouncement,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xFF3730A3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            icon: isSaving
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              isSaving
                                  ? 'Saving...'
                                  : 'Save Announcement',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    locationController.dispose();
    messageController.dispose();

    if (saved == true) {
      _showMessage(
        announcement == null
            ? 'Announcement created'
            : 'Announcement updated',
      );

      await _loadAnnouncements();
    }
  }

  Future<void> _toggleActive(
      Map<String, dynamic> announcement,
      ) async {
    final currentStatus =
        announcement['is_active'] as bool? ?? false;

    try {
      await _supabase
          .from('announcements')
          .update({
        'is_active': !currentStatus,
      })
          .eq('id', announcement['id']);

      _showMessage(
        currentStatus
            ? 'Announcement deactivated'
            : 'Announcement activated',
      );

      await _loadAnnouncements();
    } catch (error) {
      _showMessage(
        'Unable to update announcement: $error',
        isError: true,
      );
    }
  }

  Future<void> _confirmDelete(
      Map<String, dynamic> announcement,
      ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Announcement'),
          content: Text(
            'Delete "${announcement['title']}" permanently?',
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _supabase
          .from('announcements')
          .delete()
          .eq('id', announcement['id']);

      _showMessage('Announcement deleted');
      await _loadAnnouncements();
    } catch (error) {
      _showMessage(
        'Unable to delete announcement: $error',
        isError: true,
      );
    }
  }

  Color _getTypeColor(String type) {
    if (type == 'Evacuation') {
      return Colors.red;
    }

    if (type == 'Flood Warning') {
      return Colors.orange;
    }

    return const Color(0xFF3730A3);
  }

  Widget _buildAnnouncementCard(
      Map<String, dynamic> announcement,
      ) {
    final type =
        announcement['announcement_type']?.toString() ??
            'General';

    final isActive =
        announcement['is_active'] as bool? ?? false;

    final typeColor = _getTypeColor(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(
          color: Color(0xFFE2E2E8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.shade50
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: isActive
                          ? Colors.green
                          : Colors.grey.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              announcement['title']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (announcement['location'] != null &&
                announcement['location']
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      announcement['location'].toString(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 9),

            Text(
              announcement['message']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const Divider(height: 25),

            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    _openAnnouncementForm(
                      announcement: announcement,
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () {
                    _toggleActive(announcement);
                  },
                  icon: Icon(
                    isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  label: Text(
                    isActive ? 'Deactivate' : 'Activate',
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () {
                    _confirmDelete(announcement);
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                ),
              ],
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
        title: const Text('Manage Announcements'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF3730A3),
        foregroundColor: Colors.white,
        onPressed: () {
          _openAnnouncementForm();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Announcement'),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _announcements.isEmpty
          ? RefreshIndicator(
        onRefresh: _loadAnnouncements,
        child: ListView(
          children: const [
            SizedBox(height: 170),
            Icon(
              Icons.campaign_outlined,
              size: 70,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Center(
              child: Text(
                'No announcements yet',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadAnnouncements,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            90,
          ),
          itemCount: _announcements.length,
          itemBuilder: (context, index) {
            return _buildAnnouncementCard(
              _announcements[index],
            );
          },
        ),
      ),
    );
  }
}