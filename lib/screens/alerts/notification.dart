import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/flood_station.dart';
import '../../services/flood_service.dart';
import '../../services/saved_station_service.dart';
import 'notification_database_service.dart';
import 'notification_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationDatabaseService _databaseService =
  NotificationDatabaseService();

  final FloodService _floodService = FloodService();
  final SavedStationService _savedService =
  SavedStationService();

  List<NotificationModel> _notifications = [];

  bool _isLoading = true;
  bool _isCheckingLiveData = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // Show existing genuine notification history first.
    final existingNotifications =
    await _databaseService.getNotifications();

    if (!mounted) return;

    setState(() {
      _notifications = existingNotifications;
      _isLoading = false;
    });

    // Then compare saved rivers with current live readings.
    await _syncRealNotifications();

    final updatedNotifications =
    await _databaseService.getNotifications();

    if (!mounted) return;

    setState(() {
      _notifications = updatedNotifications;
    });
  }

  Future<void> _syncRealNotifications() async {
    if (_isCheckingLiveData) return;

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    _isCheckingLiveData = true;

    try {
      final results = await Future.wait([
        _savedService.fetchSavedStations(),
        _floodService.fetchStations(),
      ]);

      final savedRecords =
      results[0] as List<SavedStationRecord>;

      final stations =
      results[1] as List<FloodStation>;

      final enabledStationIds = savedRecords
          .where((record) => record.notificationsEnabled)
          .map((record) => record.stationId)
          .toSet();

      if (enabledStationIds.isEmpty) {
        return;
      }

      final stationById = <String, FloodStation>{
        for (final station in stations)
          station.id: station,
      };

      final preferences =
      await SharedPreferences.getInstance();

      for (final stationId in enabledStationIds) {
        final station = stationById[stationId];

        // The saved station might temporarily be unavailable
        // from the live government source.
        if (station == null) {
          continue;
        }

        final currentStatus =
        station.status.trim().toLowerCase();

        if (currentStatus == 'unknown') {
          continue;
        }

        final statusKey =
            'last_water_status_${user.id}_$stationId';

        final previousStatus =
        preferences.getString(statusKey);

        // First live check:
        // Save Normal as the baseline without creating noise.
        // If it is already dangerous, create a genuine alert.
        if (previousStatus == null) {
          await preferences.setString(
            statusKey,
            currentStatus,
          );

          if (_isRiskStatus(currentStatus)) {
            await _insertStationNotification(
              station: station,
              previousStatus: null,
            );
          }

          continue;
        }

        // Do not create duplicate notifications when the
        // live status has not changed.
        if (previousStatus == currentStatus) {
          continue;
        }

        await _insertStationNotification(
          station: station,
          previousStatus: previousStatus,
        );

        await preferences.setString(
          statusKey,
          currentStatus,
        );
      }
    } catch (error) {
      // Previously stored real notifications can still be
      // displayed when the Internet/API is unavailable.
      debugPrint(
        'Unable to check live saved-river notifications: '
            '$error',
      );
    } finally {
      _isCheckingLiveData = false;
    }
  }

  bool _isRiskStatus(String status) {
    return status == 'alert' ||
        status == 'warning' ||
        status == 'danger';
  }

  Future<void> _insertStationNotification({
    required FloodStation station,
    required String? previousStatus,
  }) async {
    final currentStatus =
    station.status.trim().toLowerCase();

    final returnedToNormal =
        currentStatus == 'normal';

    final title = returnedToNormal
        ? 'Water level returned to normal'
        : '${station.status} water-level alert';

    final message = returnedToNormal
        ? '${station.name} has returned to Normal level. '
        'Current water level: '
        '${station.waterLevel.toStringAsFixed(2)} m.'
        : '${station.name} is currently at '
        '${station.status} level. '
        'Current water level: '
        '${station.waterLevel.toStringAsFixed(2)} m.';

    await _databaseService.insertNotification(
      NotificationModel(
        title: title,
        message: message,
        time: DateTime.now().toUtc().toIso8601String(),
        level: currentStatus,
        isRead: false,
      ),
    );
  }

  IconData _getIcon(String level) {
    switch (level.toLowerCase()) {
      case 'danger':
        return Icons.crisis_alert_rounded;

      case 'warning':
        return Icons.warning_amber_rounded;

      case 'alert':
        return Icons.water_drop_outlined;

      default:
        return Icons.check_circle_outline;
    }
  }

  Color _getColor(String level) {
    switch (level.toLowerCase()) {
      case 'danger':
        return Colors.red;

      case 'warning':
        return Colors.orange;

      case 'alert':
        return Colors.amber.shade700;

      default:
        return Colors.green;
    }
  }

  String _formatTime(String value) {
    final date = DateTime.tryParse(value)?.toLocal();

    // Support any older record that does not use ISO format.
    if (date == null) {
      return value;
    }

    final day =
    date.day.toString().padLeft(2, '0');

    final month =
    date.month.toString().padLeft(2, '0');

    final hour =
    date.hour.toString().padLeft(2, '0');

    final minute =
    date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year}  $hour:$minute';
  }

  Future<void> _markAsRead(
      NotificationModel notification,
      ) async {
    if (notification.isRead ||
        notification.id == null) {
      return;
    }

    await _databaseService.markAsRead(
      notification.id!,
    );

    await _refreshFromDatabase();
  }

  Future<void> _markAllAsRead() async {
    await _databaseService.markAllAsRead();
    await _refreshFromDatabase();
  }

  Future<void> _deleteNotification(
      NotificationModel notification,
      ) async {
    if (notification.id == null) {
      return;
    }

    await _databaseService.deleteNotification(
      notification.id!,
    );

    await _refreshFromDatabase();
  }

  Future<void> _refreshFromDatabase() async {
    final notifications =
    await _databaseService.getNotifications();

    if (!mounted) return;

    setState(() {
      _notifications = notifications;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((notification) => !notification.isRead)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_isCheckingLiveData)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Icon(
              Icons.notifications_none,
              size: 70,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Center(
              child: Text(
                'No notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 6),
            Center(
              child: Padding(
                padding:
                EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'Alerts for your saved rivers will '
                      'appear here when their live '
                      'water-level status changes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification =
          _notifications[index];

          final color =
          _getColor(notification.level);

          return Dismissible(
            key: ValueKey(notification.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) {
              _deleteNotification(notification);
            },
            background: Container(
              margin:
              const EdgeInsets.only(bottom: 12),
              padding:
              const EdgeInsets.only(right: 20),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            child: Card(
              margin:
              const EdgeInsets.only(bottom: 12),
              color: notification.isRead
                  ? Colors.white
                  : color.withValues(alpha: 0.08),
              child: ListTile(
                contentPadding:
                const EdgeInsets.all(14),
                leading: CircleAvatar(
                  backgroundColor:
                  color.withValues(alpha: 0.15),
                  child: Icon(
                    _getIcon(notification.level),
                    color: color,
                  ),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.isRead
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                subtitle: Padding(
                  padding:
                  const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(notification.message),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(
                          notification.time,
                        ),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: notification.isRead
                    ? null
                    : Container(
                  width: 9,
                  height: 9,
                  decoration:
                  const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () {
                  _markAsRead(notification);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}