import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementCarousel extends StatefulWidget {
  const AnnouncementCarousel({super.key});

  @override
  State<AnnouncementCarousel> createState() =>
      _AnnouncementCarouselState();
}

class _AnnouncementCarouselState extends State<AnnouncementCarousel> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PageController _pageController = PageController();

  // Inner timer: rotates between the announcements already loaded.
  Timer? _slideTimer;

  // Outer timer: re-fetches from Supabase every 5 minutes.
  Timer? _refreshTimer;

  bool _isLoading = true;
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements(); // initial fetch
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
          (_) => _loadAnnouncements(),
    );
  }

  Future<void> _loadAnnouncements() async {
    try {
      final data = await _supabase
          .from('announcements')
          .select(
        'id, title, message, area, announcement_type, '
            'created_at, expires_at',
      )
          .eq('is_active', true)
          .order('created_at', ascending: false);

      if (!mounted) return;

      final newAnnouncements = List<Map<String, dynamic>>.from(data);

      setState(() {
        _announcements = newAnnouncements;
        _isLoading = false;
      });

      // Always cancel the old slideshow timer before deciding whether
      // to start a new one, otherwise refetching stacks timers.
      _slideTimer?.cancel();
      _slideTimer = null;

      // If the page controller is attached to a list that just shrank,
      // jumping back to page 0 avoids animateToPage crashing on an
      // index that no longer exists.
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      if (_announcements.length > 1) {
        _slideTimer = Timer.periodic(
          const Duration(seconds: 5),
              (_) {
            if (!_pageController.hasClients) return;

            final currentPage = _pageController.page?.round() ?? 0;
            final nextPage = (currentPage + 1) % _announcements.length;

            _pageController.animateToPage(
              nextPage,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          },
        );
      }
    } catch (error) {
      debugPrint('Announcement error: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _refreshTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 78,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_announcements.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 90,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.horizontal,
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final announcement = _announcements[index];

          return Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 6,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3730A3),
                  Color(0xFF625BD9),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement['title']?.toString() ??
                            'Announcement',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        announcement['message']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}