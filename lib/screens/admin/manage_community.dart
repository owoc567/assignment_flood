import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageCommunityPage extends StatefulWidget {
  const ManageCommunityPage({super.key});

  @override
  State<ManageCommunityPage> createState() => _ManageCommunityPageState();
}

class _ManageCommunityPageState extends State<ManageCommunityPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _filter = 'all';
  int? _updatingPostId;

  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _supabase
          .from('community_posts')
          .select(
            'id, user_id, title, content, location, '
                'post_type, is_verified, moderation_status, '
                'moderated_by, moderated_at, created_at',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _posts = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load posts: $error')));
    }
  }

  List<Map<String, dynamic>> get _displayedPosts {
    if (_filter == 'all') {
      return _posts;
    }

    return _posts.where((post) {
      final status =
          post['moderation_status']?.toString() ?? 'pending';

      return status == _filter;
    }).toList();
  }

  Future<void> _confirmModeration(
      int postId,
      String newStatus,
      ) async {
    final isVerifying = newStatus == 'verified';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isVerifying
                ? 'Verify Community Post?'
                : 'Reject Community Post?',
          ),
          content: Text(
            isVerifying
                ? 'Confirm that this community information is valid.'
                : 'The post will be marked as rejected and hidden from other users.',
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
                isVerifying ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                isVerifying ? 'Verify' : 'Reject',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _updateModerationStatus(postId, newStatus);
    }
  }

  Future<void> _updateModerationStatus(
      int postId,
      String newStatus,
      ) async {
    final admin = _supabase.auth.currentUser;

    if (admin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again')),
      );
      return;
    }

    setState(() {
      _updatingPostId = postId;
    });

    try {
      await _supabase
          .from('community_posts')
          .update({
        'moderation_status': newStatus,
        'is_verified': newStatus == 'verified',
        'moderated_by': admin.id,
        'moderated_at':
        DateTime.now().toUtc().toIso8601String(),
      })
          .eq('id', postId);

      await _loadPosts();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'verified'
                ? 'Post verified successfully'
                : 'Post rejected successfully',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update post: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPostId = null;
        });
      }
    }
  }

  Future<void> _deletePost(int postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Post?'),
          content: const Text(
            'Delete this post because it is spam or unrelated?',
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

    if (confirmed != true) return;

    setState(() {
      _updatingPostId = postId;
    });

    try {
      await _supabase.from('community_posts').delete().eq('id', postId);

      await _loadPosts();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Spam post removed')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete post: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _updatingPostId = null;
        });
      }
    }
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF3730A3),
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
      onSelected: (_) {
        setState(() {
          _filter = value;
        });
      },
    );
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'verified':
        return Icons.verified;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.pending_outlined;
    }
  }

  Widget _postCard(Map<String, dynamic> post) {
    final postId = post['id'] as int;

    final status =
        post['moderation_status']?.toString() ?? 'pending';

    final isUpdating = _updatingPostId == postId;

    final title =
        post['title']?.toString() ?? 'Untitled post';

    final content =
        post['content']?.toString() ?? 'No content';

    final postType =
        post['post_type']?.toString() ?? 'General';

    final location =
        post['location']?.toString().trim() ?? '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 13),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon(status),
                        size: 14,
                        color: _statusColor(status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _statusColor(status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              postType,
              style: const TextStyle(
                color: Color(0xFF3730A3),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              content,
              style: const TextStyle(height: 1.4),
            ),

            if (location.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 13),
            const Divider(),

            if (isUpdating)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _deletePost(postId);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  if (status != 'rejected')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _confirmModeration(
                            postId,
                            'rejected',
                          );
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),

                  if (status != 'rejected' &&
                      status != 'verified')
                    const SizedBox(width: 10),

                  if (status != 'verified')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _confirmModeration(
                            postId,
                            'verified',
                          );
                        },
                        icon: const Icon(
                          Icons.verified_outlined,
                        ),
                        label: Text(
                          status == 'rejected'
                              ? 'Restore & Verify'
                              : 'Verify',
                        ),
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
    final displayedPosts = _displayedPosts;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3730A3),
        foregroundColor: Colors.white,
        title: const Text('Manage Community Posts'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip('all', 'All'),
                _filterChip('pending', 'Pending'),
                _filterChip('verified', 'Verified'),
                _filterChip('rejected', 'Rejected'),
              ],
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (displayedPosts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: Text('No community posts found')),
              )
            else
              ...displayedPosts.map(_postCard),
          ],
        ),
      ),
    );
  }
}
