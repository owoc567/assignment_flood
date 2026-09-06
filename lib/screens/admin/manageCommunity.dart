import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageCommunityPage extends StatefulWidget {
  const ManageCommunityPage({super.key});

  @override
  State<ManageCommunityPage> createState() =>
      _ManageCommunityPageState();
}

class _ManageCommunityPageState
    extends State<ManageCommunityPage> {
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
            'post_type, is_verified, created_at',
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load posts: $error'),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _displayedPosts {
    if (_filter == 'verified') {
      return _posts.where((post) {
        return post['is_verified'] == true;
      }).toList();
    }

    if (_filter == 'unverified') {
      return _posts.where((post) {
        return post['is_verified'] != true;
      }).toList();
    }

    return _posts;
  }

  Future<void> _verifyPost(int postId) async {
    setState(() {
      _updatingPostId = postId;
    });

    try {
      await _supabase
          .from('community_posts')
          .update({'is_verified': true})
          .eq('id', postId);

      await _loadPosts();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post verified successfully'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to verify post: $error'),
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
      await _supabase
          .from('community_posts')
          .delete()
          .eq('id', postId);

      await _loadPosts();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spam post removed'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete post: $error'),
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

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF3730A3),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
      ),
      onSelected: (_) {
        setState(() {
          _filter = value;
        });
      },
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final postId = post['id'] as int;
    final verified = post['is_verified'] == true;
    final isUpdating = _updatingPostId == postId;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE4E4EA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    post['title']?.toString() ?? 'Untitled post',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  verified
                      ? Icons.verified
                      : Icons.pending_outlined,
                  color: verified ? Colors.green : Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 5),

            Text(
              post['post_type']?.toString() ?? 'General',
              style: const TextStyle(
                color: Color(0xFF3730A3),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              post['content']?.toString() ?? 'No content',
              style: const TextStyle(height: 1.4),
            ),

            if (post['location'] != null) ...[
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
                      post['location'].toString(),
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
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _deletePost(postId);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove Spam'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                  if (!verified) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _verifyPost(postId);
                        },
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Verify'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFF3730A3),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
              children: [
                _filterChip('all', 'All'),
                _filterChip('unverified', 'Unverified'),
                _filterChip('verified', 'Verified'),
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
            else if (displayedPosts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: Text('No community posts found'),
                ),
              )
            else
              ...displayedPosts.map(_postCard),
          ],
        ),
      ),
    );
  }
}