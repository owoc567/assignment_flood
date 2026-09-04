class NotificationModel {
  final int? id;
  final String title;
  final String message;
  final String time;
  final String level;
  final bool isRead;

  NotificationModel({
    this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.level,
    required this.isRead,
  });

  // Convert SQLite data into NotificationModel
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      time: json['time'],
      level: json['level'],
      isRead: json['is_read'] == 1,
    );
  }

  // Convert NotificationModel into data for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'time': time,
      'level': level,
      'is_read': isRead ? 1 : 0,
    };
  }
}