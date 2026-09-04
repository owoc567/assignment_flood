import 'package:flutter/material.dart';

import 'notification_database_service.dart';
import 'notification_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationDatabaseService _databaseService =
  NotificationDatabaseService();

  List<NotificationModel> _notifications = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // Retrieve notifications from SQLite
  Future<void> _loadNotifications() async {
    List<NotificationModel> notifications =
    await _databaseService.getNotifications();

    // Insert sample notifications when database is empty
    if (notifications.isEmpty) {
      await _insertSampleNotifications();

      notifications =
      await _databaseService.getNotifications();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  // Initial notification data for testing
  Future<void> _insertSampleNotifications() async {
    await _databaseService.insertNotification(
      NotificationModel(
        title: 'Water level alert',
        message:
        'The water level at Sungai Klang has reached Alert level.',
        time: '5 minutes ago',
        level: 'alert',
        isRead: false,
      ),
    );

    await _databaseService.insertNotification(
      NotificationModel(
        title: 'Heavy rainfall detected',
        message:
        'Heavy rainfall was recorded near your saved station.',
        time: '30 minutes ago',
        level: 'warning',
        isRead: false,
      ),
    );

    await _databaseService.insertNotification(
      NotificationModel(
        title: 'Water level returned to normal',
        message:
        'The water level at Sungai Gombak is now normal.',
        time: '2 hours ago',
        level: 'normal',
        isRead: true,
      ),
    );
  }

  IconData _getIcon(String level) {
    if (level == 'alert') {
      return Icons.warning_amber_rounded;
    } else if (level == 'warning') {
      return Icons.water_drop;
    } else {
      return Icons.check_circle_outline;
    }
  }

  Color _getColor(String level) {
    if (level == 'alert') {
      return Colors.red;
    } else if (level == 'warning') {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  // Mark one notification as read
  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead || notification.id == null) {
      return;
    }

    await _databaseService.markAsRead(notification.id!);
    await _loadNotifications();
  }

  // Mark all notifications as read
  Future<void> _markAllAsRead() async {
    await _databaseService.markAllAsRead();
    await _loadNotifications();
  }

  // Delete one notification
  Future<void> _deleteNotification(
      NotificationModel notification,
      ) async {
    if (notification.id == null) {
      return;
    }

    await _databaseService.deleteNotification(notification.id!);
    await _loadNotifications();
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 70,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Your water-level updates will appear here.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          final color = _getColor(notification.level);

          return Dismissible(
            key: ValueKey(notification.id),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              _deleteNotification(notification);
            },
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.only(right: 20),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: notification.isRead
                  ? Colors.white
                  : color.withOpacity(0.08),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
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
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(notification.message),
                      const SizedBox(height: 6),
                      Text(
                        notification.time,
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
                  decoration: const BoxDecoration(
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