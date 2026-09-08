import 'package:shared_preferences/shared_preferences.dart';

class OfflineProfileService {
  static String _key(String userId, String field) {
    return 'profile_${userId}_$field';
  }

  static Future<void> saveProfile({
    required String userId,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String address,
    required String role,
    String? profileImageUrl,
    String? createdAt,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _key(userId, 'full_name'),
      fullName,
    );

    await preferences.setString(
      _key(userId, 'email'),
      email,
    );

    await preferences.setString(
      _key(userId, 'phone_number'),
      phoneNumber,
    );

    await preferences.setString(
      _key(userId, 'address'),
      address,
    );

    await preferences.setString(
      _key(userId, 'role'),
      role,
    );

    if (profileImageUrl != null) {
      await preferences.setString(
        _key(userId, 'profile_image_url'),
        profileImageUrl,
      );
    }

    if (createdAt != null) {
      await preferences.setString(
        _key(userId, 'created_at'),
        createdAt,
      );
    }
  }

  static Future<Map<String, String>> loadProfile(
      String userId,
      ) async {
    final preferences = await SharedPreferences.getInstance();

    return {
      'full_name':
      preferences.getString(_key(userId, 'full_name')) ?? '',
      'email':
      preferences.getString(_key(userId, 'email')) ?? '',
      'phone_number':
      preferences.getString(_key(userId, 'phone_number')) ?? '',
      'address':
      preferences.getString(_key(userId, 'address')) ?? '',
      'role':
      preferences.getString(_key(userId, 'role')) ?? 'user',
      'profile_image_url':
      preferences.getString(_key(userId, 'profile_image_url')) ?? '',
      'created_at':
      preferences.getString(_key(userId, 'created_at')) ?? '',
    };
  }
}