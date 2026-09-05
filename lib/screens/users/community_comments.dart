import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityCommentsPage extends StatefulWidget {
  final dynamic postId;
  final String postTitle;

  const CommunityCommentsPage({
    super.key,
    required this.postId,
    required this.postTitle,
  });

  @override
  State<CommunityCommentsPage> createState() =>
      _CommunityCommentsPageState();
}

class _CommunityCommentsPageState
    extends State<CommunityCommentsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _commentController =
  TextEditingController();

  List<Map<String, dynamic>> _comments = [];
  final Map<String, Map<String, dynamic>> _profiles = {};

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await _supabase
          .from('community_comments')
          .select()
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      final comments =
      List<Map<String, dynamic>>.from(response);

      final userIds = comments
          .map((comment) => comment['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      _profiles.clear();

      if (userIds.isNotEmpty) {
        final profileResponse = await _supabase
            .from('profiles')
            .select('id, full_name, profile_image_url')
            .inFilter('id', userIds);

        final profiles =
        List<Map<String, dynamic>>.from(profileResponse);

        for (final profile in profiles) {
          final id = profile['id']?.toString();

          if (id != null) {
            _profiles[id] = profile;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load comments: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitComment() async {
    final commentText = _commentController.text.trim();
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

    if (commentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (commentText.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Comment cannot contain more than 500 characters',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _supabase.from('community_comments').insert({
        'post_id': widget.postId,
        'user_id': user.id,
        'comment_text': commentText,
      });

      _commentController.clear();

      if (!mounted) return;

      FocusScope.of(context).unfocus();

      await _loadComments();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add comment: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteComment(dynamic commentId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Comment'),
          content: const Text(
            'Are you sure you want to delete this comment?',
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
      await _deleteComment(commentId);
    }
  }

  Future<void> _deleteComment(dynamic commentId) async {
    try {
      await _supabase
          .from('community_comments')
          .delete()
          .eq('id', commentId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment deleted'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadComments();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete comment: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _timeAgo(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(
      value.toString(),
    )?.toLocal();

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
      return '${difference.inDays} day'
          '${difference.inDays == 1 ? '' : 's'} ago';
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

    return '${words.first[0]}${words.last[0]}'
        .toUpperCase();
  }

  Widget _buildAvatar({
    required String name,
    required String? imageUrl,
  }) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFF3730A3),
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 20,
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

  Widget _buildComment(Map<String, dynamic> comment) {
    final userId = comment['user_id']?.toString() ?? '';
    final profile = _profiles[userId];

    final profileName =
        profile?['full_name']?.toString().trim() ?? '';

    final authorName =
    profileName.isEmpty ? 'Community User' : profileName;

    final imageUrl =
    profile?['profile_image_url']?.toString();

    final currentUserId =
        _supabase.auth.currentUser?.id;

    final isOwner = currentUserId == userId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(
            name: authorName,
            imageUrl: imageUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          authorName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(comment['created_at']),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                      if (isOwner)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (value) {
                            if (value == 'delete') {
                              _confirmDeleteComment(
                                comment['id'],
                              );
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
                  const SizedBox(height: 5),
                  Text(
                    comment['comment_text']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3730A3),
        ),
      );
    }

    if (_comments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadComments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 130),
            Icon(
              Icons.chat_bubble_outline,
              size: 65,
              color: Colors.grey,
            ),
            SizedBox(height: 14),
            Center(
              child: Text(
                'No comments yet',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 5),
            Center(
              child: Text(
                'Be the first person to comment.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadComments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _comments.length,
        itemBuilder: (context, index) {
          return _buildComment(_comments[index]);
        },
      ),
    );
  }

  Widget _buildCommentInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(0xFFE3E3E8),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                enabled: !_isSubmitting,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                textCapitalization:
                TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF3F3F7),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF3730A3),
                foregroundColor: Colors.white,
              ),
              onPressed:
              _isSubmitting ? null : _submitComment,
              icon: _isSubmitting
                  ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF3730A3),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comments',
              style: TextStyle(
                color: Color(0xFF171724),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.postTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildCommentsList(),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }
}