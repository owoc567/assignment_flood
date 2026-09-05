import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../users/community_comments.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final List<String> _filters = [
    'All',
    'Flood Report',
    'Safety Tip',
    'Help Needed',
  ];

  List<Map<String, dynamic>> _posts = [];
  final Map<String, Map<String, dynamic>> _profiles = {};
  final Map<dynamic, int> _likeCounts = {};
  final Map<dynamic, int> _dislikeCounts = {};
  final Map<dynamic, String> _myReactions = {};

  bool _isUpdatingReaction = false;
  final Set<dynamic> _expandedCommentPosts = {};
  final Set<dynamic> _loadingCommentPosts = {};

  final Map<dynamic, List<Map<String, dynamic>>>
  _inlineComments = {};
  String _selectedFilter = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  List<Map<String, dynamic>> get _filteredPosts {
    if (_selectedFilter == 'All') {
      return _posts;
    }

    return _posts.where((post) {
      return post['post_type'] == _selectedFilter;
    }).toList();
  }

  Future<void> _loadPosts() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final postResponse = await _supabase
          .from('community_posts')
          .select()
          .order('created_at', ascending: false);

      final posts = List<Map<String, dynamic>>.from(postResponse);

      final userIds = posts
          .map((post) => post['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      _profiles.clear();
      final postIds = posts
          .map((post) => post['id'])
          .where((id) => id != null)
          .toList();

      _likeCounts.clear();
      _dislikeCounts.clear();
      _myReactions.clear();

      if (postIds.isNotEmpty) {
        final reactionResponse = await _supabase
            .from('community_reactions')
            .select('post_id, user_id, reaction_type')
            .inFilter('post_id', postIds);

        final reactions =
        List<Map<String, dynamic>>.from(reactionResponse);

        final currentUserId = _supabase.auth.currentUser?.id;

        for (final reaction in reactions) {
          final postId = reaction['post_id'];
          final userId = reaction['user_id']?.toString();
          final reactionType =
          reaction['reaction_type']?.toString();

          if (reactionType == 'like') {
            _likeCounts[postId] =
                (_likeCounts[postId] ?? 0) + 1;
          }

          if (reactionType == 'dislike') {
            _dislikeCounts[postId] =
                (_dislikeCounts[postId] ?? 0) + 1;
          }

          if (userId == currentUserId &&
              reactionType != null) {
            _myReactions[postId] = reactionType;
          }
        }
      }

      if (userIds.isNotEmpty) {
        final profileResponse = await _supabase
            .from('profiles')
            .select('id, full_name, profile_image_url')
            .inFilter('id', userIds);

        final profiles =
        List<Map<String, dynamic>>.from(profileResponse);

        for (final profile in profiles) {
          final profileId = profile['id']?.toString();

          if (profileId != null) {
            _profiles[profileId] = profile;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _posts = posts;
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
    final locationController = TextEditingController();
    final contentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String selectedType = 'Flood Report';
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF3730A3),
                  ),
                  SizedBox(width: 10),
                  Text('Create Post'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: InputDecoration(
                            labelText: 'Post Type',
                            prefixIcon:
                            const Icon(Icons.category_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Flood Report',
                              child: Text('Flood Report'),
                            ),
                            DropdownMenuItem(
                              value: 'Safety Tip',
                              child: Text('Safety Tip'),
                            ),
                            DropdownMenuItem(
                              value: 'Help Needed',
                              child: Text('Help Needed'),
                            ),
                          ],
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedType = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: titleController,
                          enabled: !isSubmitting,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            hintText: 'Enter post title',
                            prefixIcon: const Icon(Icons.title),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter a title';
                            }

                            if (value.trim().length < 3) {
                              return 'Title must have at least 3 characters';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: locationController,
                          enabled: !isSubmitting,
                          decoration: InputDecoration(
                            labelText: 'Location (optional)',
                            hintText: 'Example: Setapak, Kuala Lumpur',
                            prefixIcon:
                            const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: contentController,
                          enabled: !isSubmitting,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'Write your information here',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter a description';
                            }

                            if (value.trim().length < 10) {
                              return 'Description must have at least 10 characters';
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3730A3),
                    foregroundColor: Colors.white,
                  ),
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
                      location:
                      locationController.text.trim(),
                      content: contentController.text.trim(),
                      postType: selectedType,
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
                  child: isSubmitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Publish'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    locationController.dispose();
    contentController.dispose();
  }

  Future<bool> _createPost({
    required String title,
    required String location,
    required String content,
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
        'location': location.isEmpty ? null : location,
        'content': content,
        'post_type': postType,
        'is_verified': false,
      });

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post published successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadPosts();
      return true;
    } catch (error) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to publish post: $error'),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    }
  }

  Future<void> _confirmDeletePost(dynamic postId) async {
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

  Future<void> _deletePost(dynamic postId) async {
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

  Future<void> _changeReaction(
      dynamic postId,
      String selectedReaction,
      ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isUpdatingReaction) {
      return;
    }

    _isUpdatingReaction = true;

    try {
      final currentReaction = _myReactions[postId];

      if (currentReaction == selectedReaction) {
        // Pressing the same button removes the reaction.
        await _supabase
            .from('community_reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);
      } else if (currentReaction == null) {
        // The user has not reacted yet.
        await _supabase.from('community_reactions').insert({
          'post_id': postId,
          'user_id': user.id,
          'reaction_type': selectedReaction,
        });
      } else {
        // Change Like to Dislike or Dislike to Like.
        await _supabase
            .from('community_reactions')
            .update({
          'reaction_type': selectedReaction,
        })
            .eq('post_id', postId)
            .eq('user_id', user.id);
      }

      await _loadPosts();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update reaction: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _isUpdatingReaction = false;
    }
  }

  Future<void> _toggleComments(dynamic postId) async {
    if (_expandedCommentPosts.contains(postId)) {
      setState(() {
        _expandedCommentPosts.remove(postId);
      });

      return;
    }

    setState(() {
      _expandedCommentPosts.add(postId);
    });

    await _loadInlineComments(postId);
  }

  Future<void> _loadInlineComments(dynamic postId) async {
    if (_loadingCommentPosts.contains(postId)) {
      return;
    }

    setState(() {
      _loadingCommentPosts.add(postId);
    });

    try {
      final response = await _supabase
          .from('community_comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final comments =
      List<Map<String, dynamic>>.from(response);

      final commentUserIds = comments
          .map((comment) => comment['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      if (commentUserIds.isNotEmpty) {
        final profileResponse = await _supabase
            .from('profiles')
            .select('id, full_name, profile_image_url')
            .inFilter('id', commentUserIds);

        final profiles =
        List<Map<String, dynamic>>.from(profileResponse);

        for (final profile in profiles) {
          final profileId = profile['id']?.toString();

          if (profileId != null) {
            _profiles[profileId] = profile;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _inlineComments[postId] = comments;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load comments: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingCommentPosts.remove(postId);
        });
      }
    }
  }

  String _timeAgo(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(value.toString())?.toLocal();

    if (date == null) {
      return '';
    }

    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) {
      return 'just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  String _getInitials(String name) {
    final words = name
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return 'U';
    }

    if (words.length == 1) {
      return words.first[0].toUpperCase();
    }

    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  Color _typeColor(String postType) {
    switch (postType) {
      case 'Flood Report':
        return const Color(0xFFE53935);
      case 'Safety Tip':
        return const Color(0xFF159957);
      case 'Help Needed':
        return const Color(0xFFF28C28);
      default:
        return const Color(0xFF3730A3);
    }
  }

  Color _typeBackgroundColor(String postType) {
    switch (postType) {
      case 'Flood Report':
        return const Color(0xFFFFE8E8);
      case 'Safety Tip':
        return const Color(0xFFE3F8EA);
      case 'Help Needed':
        return const Color(0xFFFFF0DC);
      default:
        return const Color(0xFFECEBFF);
    }
  }

  Widget _buildProfileAvatar({
    required String name,
    required String? imageUrl,
  }) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 19,
        backgroundColor: const Color(0xFF3730A3),
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 19,
      backgroundColor: const Color(0xFF3730A3),
      child: Text(
        _getInitials(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final userId = post['user_id']?.toString() ?? '';
    final profile = _profiles[userId];

    final fullName =
        profile?['full_name']?.toString().trim() ?? '';

    final authorName =
    fullName.isEmpty ? 'Community User' : fullName;

    final imageUrl = profile?['profile_image_url']?.toString();
    final postType =
        post['post_type']?.toString() ?? 'Flood Report';
    final location = post['location']?.toString().trim() ?? '';
    final title = post['title']?.toString() ?? '';
    final content = post['content']?.toString() ?? '';
    final isVerified = post['is_verified'] == true;

    final currentUserId = _supabase.auth.currentUser?.id;
    final isOwner = currentUserId == userId;

    final typeColor = _typeColor(postType);
    final typeBackground = _typeBackgroundColor(postType);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE1E1E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileAvatar(
                  name: authorName,
                  imageUrl: imageUrl,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        crossAxisAlignment:
                        WrapCrossAlignment.center,
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: typeBackground,
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: Text(
                              postType,
                              style: TextStyle(
                                color: typeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Only Flood Reports can receive an admin verified badge.
                          if (postType == 'Flood Report' && isVerified)
                            const Icon(
                              Icons.verified,
                              color: Color(0xFF159957),
                              size: 17,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (location.isNotEmpty) ...[
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: Colors.grey,
                            ),
                            Flexible(
                              child: Text(
                                location,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const Text(
                              ' · ',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          Text(
                            _timeAgo(post['created_at']),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDeletePost(post['id']);
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF252532),
                  ),
                ),
                 if (postType == 'Flood Report' && !isVerified)  ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Waiting for admin verification',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildReactionBar(
              post['id'],
              title,
          ),
          _buildInlineComments(
            post['id'],
            title,
          ),
        ],
      ),
    );
  }

  Widget _buildReactionBar(
      dynamic postId,
      String postTitle,
      ) {
    final likeCount = _likeCounts[postId] ?? 0;
    final dislikeCount = _dislikeCounts[postId] ?? 0;
    final myReaction = _myReactions[postId];

    final hasLiked = myReaction == 'like';
    final hasDisliked = myReaction == 'dislike';

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color(0xFFE8E8EE),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () {
              _changeReaction(postId, 'like');
            },
            style: TextButton.styleFrom(
              foregroundColor: hasLiked
                  ? const Color(0xFF3730A3)
                  : Colors.grey.shade600,
              backgroundColor: hasLiked
                  ? const Color(0xFFEDEBFF)
                  : Colors.transparent,
            ),
            icon: Icon(
              hasLiked
                  ? Icons.thumb_up
                  : Icons.thumb_up_outlined,
              size: 18,
            ),
            label: Text('$likeCount'),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () {
              _changeReaction(postId, 'dislike');
            },
            style: TextButton.styleFrom(
              foregroundColor: hasDisliked
                  ? Colors.red
                  : Colors.grey.shade600,
              backgroundColor: hasDisliked
                  ? const Color(0xFFFFE8E8)
                  : Colors.transparent,
            ),
            icon: Icon(
              hasDisliked
                  ? Icons.thumb_down
                  : Icons.thumb_down_outlined,
              size: 18,
            ),
            label: Text('$dislikeCount'),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: ()  {
              _toggleComments(postId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
            icon: const Icon(
              Icons.chat_bubble_outline,
              size: 18,
            ),
            label: Text(
              _expandedCommentPosts.contains(postId)
                  ? 'Hide'
                  : 'Comments',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallAvatar({
    required String name,
    required String? imageUrl,
  }) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 15,
        backgroundColor: const Color(0xFF3730A3),
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 15,
      backgroundColor: const Color(0xFF3730A3),
      child: Text(
        _getInitials(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInlineComments(
      dynamic postId,
      String postTitle,
      ) {
    if (!_expandedCommentPosts.contains(postId)) {
      return const SizedBox.shrink();
    }

    final isLoading =
    _loadingCommentPosts.contains(postId);

    final comments =
        _inlineComments[postId] ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFC),
        border: Border(
          top: BorderSide(
            color: Color(0xFFE8E8EE),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _toggleComments(postId);
                },
                child: const Text(
                  'Hide',
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF3730A3),
                ),
              ),
            )
          else if (comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'No comments yet',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            ...comments.map((comment) {
              final userId =
                  comment['user_id']?.toString() ?? '';

              final profile = _profiles[userId];

              final savedName =
                  profile?['full_name']?.toString().trim() ?? '';

              final authorName = savedName.isEmpty
                  ? 'Community User'
                  : savedName;

              final imageUrl =
              profile?['profile_image_url']?.toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    _buildSmallAvatar(
                      name: authorName,
                      imageUrl: imageUrl,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F5),
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    authorName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  _timeAgo(
                                    comment['created_at'],
                                  ),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              comment['comment_text']
                                  ?.toString() ??
                                  '',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CommunityCommentsPage(
                          postId: postId,
                          postTitle: postTitle,
                        ),
                  ),
                );

                await _loadInlineComments(postId);
              },
              icon: const Icon(
                Icons.edit_outlined,
                size: 17,
              ),
              label: const Text('Write a Comment'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String filter) {
    final isSelected = _selectedFilter == filter;

    String displayName = filter;

    if (filter == 'Flood Report') {
      displayName = 'Flood Reports';
    } else if (filter == 'Safety Tip') {
      displayName = 'Safety Tips';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(displayName),
        selected: isSelected,
        showCheckmark: false,
        selectedColor: const Color(0xFFEDEBFF),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF3730A3)
              : const Color(0xFFE1E1E8),
        ),
        labelStyle: TextStyle(
          color: isSelected
              ? const Color(0xFF3730A3)
              : const Color(0xFF555563),
          fontSize: 12,
          fontWeight:
          isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) {
          setState(() {
            _selectedFilter = filter;
          });
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3730A3),
        ),
      );
    }

    final posts = _filteredPosts;

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        children: [
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                return _buildFilterButton(_filters[index]);
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${posts.length} post${posts.length == 1 ? '' : 's'} · sorted by latest',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          if (posts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 100),
              child: Column(
                children: [
                  Icon(
                    Icons.forum_outlined,
                    color: Colors.grey,
                    size: 65,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'No community posts found',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            ...posts.map(_buildPostCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF3730A3),
        elevation: 0,
        centerTitle: true,
        title: const Column(
          children: [
            Text(
              'Community',
              style: TextStyle(
                color: Color(0xFF171724),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Flood Reports & Safety',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF3730A3),
                foregroundColor: Colors.white,
              ),
              onPressed: _showCreatePostDialog,
              icon: const Icon(
                Icons.edit_outlined,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}