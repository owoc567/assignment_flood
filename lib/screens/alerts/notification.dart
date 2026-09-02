import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Water level alert',
      'message': 'The water level at Sungai Klang has reached Alert level.',
      'time': '5 minutes ago',
      'level': 'alert',
      'isRead': false,
    },
    {
      'title': 'Heavy rainfall detected',
      'message': 'Heavy rainfall was recorded near your saved station.',
      'time': '30 minutes ago',
      'level': 'warning',
      'isRead': false,
    },
    {
      'title': 'Water level returned to normal',
      'message': 'The water level at Sungai Gombak is now normal.',
      'time': '2 hours ago',
      'level': 'normal',
      'isRead': true,
    },
  ];

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

  void _markAllAsRead() {
    setState(() {
      for (final notification in _notifications) {
        notification['isRead'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((notification) => notification['isRead'] == false)
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
      body: _notifications.isEmpty
          ? const Center(
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
            Text('Your water-level updates will appear here.'),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          final level = notification['level'] as String;
          final isRead = notification['isRead'] as bool;
          final color = _getColor(level);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isRead ? Colors.white : color.withOpacity(0.08),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(
                  _getIcon(level),
                  color: color,
                ),
              ),
              title: Text(
                notification['title'],
                style: TextStyle(
                  fontWeight:
                  isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification['message']),
                    const SizedBox(height: 6),
                    Text(
                      notification['time'],
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: isRead
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
                setState(() {
                  notification['isRead'] = true;
                });
              },
            ),
          );
        },
      ),
    );
  }
}