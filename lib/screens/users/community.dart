import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await _supabase
          .from('community_posts')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _posts = List<Map<String, dynamic>>.from(response);
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
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCreatePostDialog() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final locationController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    String selectedPostType = 'Discussion';
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Community Post'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedPostType,
                          decoration: const InputDecoration(
                            labelText: 'Post Type',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Discussion',
                              child: Text('Discussion'),
                            ),
                            DropdownMenuItem(
                              value: 'Flood Warning',
                              child: Text('Flood Warning'),
                            ),
                            DropdownMenuItem(
                              value: 'Help Request',
                              child: Text('Help Request'),
                            ),
                          ],
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedPostType = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: titleController,
                          enabled: !isSubmitting,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            hintText: 'Enter the post title',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a title';
                            }

                            if (value.trim().length < 3) {
                              return 'Title must contain at least 3 characters';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: locationController,
                          enabled: !isSubmitting,
                          decoration: const InputDecoration(
                            labelText: 'Location (optional)',
                            hintText: 'For example: Setapak, Kuala Lumpur',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: contentController,
                          enabled: !isSubmitting,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Write your flood information here',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a description';
                            }

                            if (value.trim().length < 10) {
                              return 'Description must contain at least 10 characters';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    setDialogState(() {
                      isSubmitting = true;
                    });

                    final success = await _createPost(
                      title: titleController.text.trim(),
                      content: contentController.text.trim(),
                      location: locationController.text.trim(),
                      postType: selectedPostType,
                    );

                    if (!dialogContext.mounted) return;

                    if (success) {
                      Navigator.pop(dialogContext);
                    } else {
                      setDialogState(() {
                        isSubmitting = false;
                      });
                    }
                  },
                  icon: isSubmitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send),
                  label: Text(
                    isSubmitting ? 'Posting...' : 'Post',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    contentController.dispose();
    locationController.dispose();
  }

  Future<bool> _createPost({
    required String title,
    required String content,
    required String location,
    required String postType,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in before creating a post'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    }

    try {
      await _supabase.from('community_posts').insert({
        'user_id': user.id,
        'title': title,
        'content': content,
        'location': location.isEmpty ? null : location,
        'post_type': postType,
      });

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadPosts();
      return true;
    } catch (error) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create post: $error'),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    }
  }

  Future<void> _confirmDeletePost(int postId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text(
            'Are you sure you want to delete this post?',
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

    if (shouldDelete == true) {
      await _deletePost(postId);
    }
  }

  Future<void> _deletePost(int postId) async {
    try {
      await _supabase
          .from('community_posts')
          .delete()
          .eq('id', postId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadPosts();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete post: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(value.toString())?.toLocal();

    if (date == null) {
      return '';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  Color _getPostTypeColor(String postType) {
    switch (postType) {
      case 'Flood Warning':
        return Colors.red;
      case 'Help Request':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getPostTypeIcon(String postType) {
    switch (postType) {
      case 'Flood Warning':
        return Icons.warning_amber_rounded;
      case 'Help Request':
        return Icons.volunteer_activism_outlined;
      default:
        return Icons.forum_outlined;
    }
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final userId = post['user_id']?.toString();
    final isOwner = currentUserId == userId;

    final postType = post['post_type']?.toString() ?? 'Discussion';
    final isVerified = post['is_verified'] == true;
    final location = post['location']?.toString();

    final postColor = _getPostTypeColor(postType);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: postColor.withValues(alpha: 0.12),
                  child: Icon(
                    _getPostTypeIcon(postType),
                    color: postColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        postType,
                        style: TextStyle(
                          color: postColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(post['created_at']),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isVerified)
                  const Chip(
                    avatar: Icon(
                      Icons.verified,
                      color: Colors.green,
                      size: 18,
                    ),
                    label: Text('Verified'),
                  )
                else
                  const Chip(
                    avatar: Icon(
                      Icons.schedule,
                      color: Colors.orange,
                      size: 18,
                    ),
                    label: Text('Unverified'),
                  ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDeletePost(post['id'] as int);
                      }
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              post['title']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post['content']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (location != null && location.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        color: Colors.grey.shade700,
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPosts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Icon(
              Icons.forum_outlined,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'No community posts yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Be the first person to share information.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          return _buildPostCard(_posts[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadPosts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Post'),
      ),
    );
  }
}