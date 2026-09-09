import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'package:url_launcher/url_launcher.dart';
import 'package:assignment_flood/services/offline_sos_database.dart';
import 'package:assignment_flood/services/offline_profile_service.dart';
import 'package:assignment_flood/services/offline_sos_sync_service.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final Location _location = Location();

  bool _permissionGranted = false;
  bool _gpsEnabled = false;
  bool _isSending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permission/GPS status when returning from system settings.
    if (state == AppLifecycleState.resumed) {
      checkStatus();
      OfflineSosSyncService.instance.syncPendingSos();
    }
  }

  Future<void> _checkOfflineSosRecords() async {
    final records =
    await OfflineSosDatabase.instance.getAllOfflineSos();

    debugPrint('SQLite SOS record count: ${records.length}');

    for (final record in records) {
      debugPrint('SQLite SOS: $record');
    }
  }

  // Check is location permission granted.
  Future<bool> isPermissionGranted() async {
    return await handler.Permission.locationWhenInUse.isGranted;
  }

  // Check is GPS enabled.
  Future<bool> isGpsEnabled() async {
    return await handler.Permission.location.serviceStatus.isEnabled;
  }

  // Check both permission and GPS status, update UI.
  void checkStatus() async {
    bool permissionGranted = await isPermissionGranted();
    bool gpsEnabled = await isGpsEnabled();
    if (!mounted) return;
    setState(() {
      _permissionGranted = permissionGranted;
      _gpsEnabled = gpsEnabled;
    });
  }

  // Request user to enable GPS location service.
  Future<void> requestEnableGps() async {
    if (_gpsEnabled) return;

    bool isGpsActive = await _location.requestService();
    log("requestService returned: $isGpsActive");
    if (!mounted) return;
    setState(() {
      _gpsEnabled = isGpsActive;
    });
  }

  // Request permission to access user's location.
  Future<void> requestLocationPermission() async {
    var permissionStatus = await handler.Permission.locationWhenInUse.request();
    log("permission status: $permissionStatus");
    if (!mounted) return;

    setState(() {
      _permissionGranted = permissionStatus == handler.PermissionStatus.granted;
    });

    if (permissionStatus == handler.PermissionStatus.permanentlyDenied) {
      // Android won't show the system dialog again once permanently denied.
      // The only way to grant it now is through the app's system settings.
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Needed'),
          content: const Text(
            'Location permission was previously denied. Please enable it '
            'manually in your device settings to use the SOS feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (goToSettings == true) {
        await handler.openAppSettings();
      }
    } else if (permissionStatus != handler.PermissionStatus.granted) {
      _showError('Location permission was not granted.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _confirmAndSendSos() async {
    final message = _messageController.text.trim();

    if (message.length > 300) {
      _showError(
        'SOS message cannot exceed 300 characters.',
      );
      return;
    }
    // Make sure GPS and permission are ready before asking for confirmation.
    if (!_gpsEnabled) {
      await requestEnableGps();
    }
    if (!_permissionGranted) {
      await requestLocationPermission();
    }

    if (!_gpsEnabled) {
      _showError('Please enable GPS to send an SOS.');
      return;
    }
    if (!_permissionGranted) {
      _showError('Location permission is required to send an SOS.');
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm SOS'),
        content: const Text(
          'This will send your current location and message to flood '
          'response authorities as an emergency alert. Only use this if '
          'you are in genuine danger. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Send SOS',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _sendSos();
  }

  Future<bool> _openSmsFallback({
    required String emergencyContactPhone,
    required String fullName,
    required String phoneNumber,
    required double latitude,
    required double longitude,
    required String message,
  }) async {
    final cleanedContactPhone =
    emergencyContactPhone.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );

    if (cleanedContactPhone.isEmpty) {
      return false;
    }

    final sosMessage = '''
    EMERGENCY FLOOD SOS
    
    Name: $fullName
    Phone: ${phoneNumber.isEmpty ? 'Not provided' : phoneNumber}
    Situation: ${message.isEmpty ? 'Emergency assistance required' : message}
    Latitude: $latitude
    Longitude: $longitude
    Map: https://maps.google.com/?q=$latitude,$longitude
    Time: ${DateTime.now().toLocal()}
    
    Please provide emergency assistance.
    ''';

    final encodedMessage =
    Uri.encodeComponent(sosMessage);

    final smsUri = Uri.parse(
      'sms:$cleanedContactPhone?body=$encodedMessage',
    );

    try {
      return await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint('Unable to open SMS: $error');
      return false;
    }
  }

  Future<void> _sendSos() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    try {
      if (user == null) {
        throw Exception('You must be signed in to send an SOS.');
      }

      // Get the current GPS location.
      final LocationData locationData = await _location.getLocation();

      final latitude = locationData.latitude;
      final longitude = locationData.longitude;

      if (latitude == null || longitude == null) {
        throw Exception('Unable to get your current location.');
      }

      String fullName = 'Unknown user';
      String phoneNumber = '';
      String emergencyContactPhone = '';

      // Try to obtain profile information.
      try {
        final profile = await supabase
            .from('profiles')
            .select(
          'full_name, phone_number, '
              'emergency_contact_phone',
        )
            .eq('id', user.id)
            .single();

        fullName = profile['full_name']?.toString() ?? 'Unknown user';

        phoneNumber = profile['phone_number']?.toString() ?? '';
        emergencyContactPhone =
            profile['emergency_contact_phone']
                ?.toString()
                .trim() ??
                '';
      } catch (error) {
        debugPrint(
          'Could not load online profile for SOS: $error',
        );

        final cachedProfile =
        await OfflineProfileService.loadProfile(user.id);

        final cachedName =
            cachedProfile['full_name']?.trim() ?? '';

        final cachedPhone =
            cachedProfile['phone_number']?.trim() ?? '';

        final cachedEmergencyPhone =
            cachedProfile['emergency_contact_phone']
                ?.trim() ??
                '';

        fullName = cachedName.isNotEmpty
            ? cachedName
            : user.email ?? 'Unknown user';

        phoneNumber = cachedPhone;
        emergencyContactPhone = cachedEmergencyPhone;
      }

      final situation = _messageController.text.trim();

      try {
        // First attempt: send to Supabase.
        await supabase.from('sos_alerts').insert({
          'user_id': user.id,
          'full_name': fullName,
          'phone_number': phoneNumber,
          'latitude': latitude,
          'longitude': longitude,
          'message': situation.isEmpty ? null : situation,
          'status': 'active',
        });

        if (!mounted) return;

        setState(() {
          _sent = true;
        });
      } catch (supabaseError) {
        debugPrint('Online SOS failed: $supabaseError');

        // Second attempt: save the SOS in SQLite.
        final localId =
        await OfflineSosDatabase.instance.saveOfflineSos(
          userId: user.id,
          fullName: fullName,
          phoneNumber: phoneNumber,
          latitude: latitude,
          longitude: longitude,
          message: situation.isEmpty ? null : situation,
        );

        debugPrint('SOS saved into SQLite. Local ID: $localId');

        await _checkOfflineSosRecords();

        if (!mounted) return;

        if (emergencyContactPhone.isEmpty) {
          if (!mounted) return;

          await showDialog<void>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                icon: const Icon(
                  Icons.contact_phone_outlined,
                  color: Colors.orange,
                  size: 45,
                ),
                title: const Text('SOS Saved Offline'),
                content: const Text(
                  'Your SOS has been saved on this device '
                      'and will upload automatically when the '
                      'Internet returns.\n\n'
                      'No personal emergency contact is available '
                      'for the SMS backup. Call 999 if you are in '
                      'immediate danger.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('OK'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      Navigator.pop(dialogContext);

                      final emergencyUri = Uri(
                        scheme: 'tel',
                        path: '999',
                      );

                      try {
                        await launchUrl(
                          emergencyUri,
                          mode:
                          LaunchMode.externalApplication,
                        );
                      } catch (error) {
                        debugPrint(
                          'Unable to open dialer: $error',
                        );
                      }
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Call 999'),
                  ),
                ],
              );
            },
          );
        } else {
          if (!mounted) return;

          final openSms = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return AlertDialog(
                icon: const Icon(
                  Icons.signal_wifi_off,
                  color: Colors.orange,
                  size: 45,
                ),
                title: const Text('No Internet Connection'),
                content: const Text(
                  'Your SOS could not be sent to the admin '
                      'dashboard. It has been saved on this device '
                      'and will upload automatically later.\n\n'
                      'Open SMS now to send your location to your '
                      'personal emergency contact?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, false);
                    },
                    child: const Text('Not Now'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext, true);
                    },
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('Open SMS'),
                  ),
                ],
              );
            },
          );

          if (openSms == true) {
            final smsOpened = await _openSmsFallback(
              emergencyContactPhone:
              emergencyContactPhone,
              fullName: fullName,
              phoneNumber: phoneNumber,
              latitude: latitude,
              longitude: longitude,
              message: situation,
            );

            if (!mounted) return;

            if (!smsOpened) {
              _showError(
                'Unable to open the SMS application. '
                    'Please call your personal emergency '
                    'contact directly.',
              );
            }
          }
        }
      }
    } catch (error) {
      _showError('Unable to prepare SOS: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _sent ? _buildSentState() : _buildFormState(),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Trapped in a flood area?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sending an SOS shares your current location with flood '
          'response authorities so they can locate and assist you.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // GPS / permission status row, matching Practical 13 pattern.
        _statusTile(
          title: 'GPS',
          enabled: _gpsEnabled,
          onEnable: requestEnableGps,
        ),
        _statusTile(
          title: 'Location Permission',
          enabled: _permissionGranted,
          onEnable: requestLocationPermission,
        ),

        const SizedBox(height: 20),

        const Text(
          'Describe your situation (optional)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _messageController,
          maxLines: 4,
          maxLength: 300,
          decoration: InputDecoration(
            hintText: 'e.g. Stuck on rooftop, water rising, 2 adults 1 child',
            filled: true,
            fillColor: Colors.grey.shade200,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : _confirmAndSendSos,
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sos),
            label: Text(_isSending ? 'Sending...' : 'Send SOS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusTile({
    required String title,
    required bool enabled,
    required VoidCallback onEnable,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          enabled
              ? const Text('Enabled', style: TextStyle(color: Colors.green))
              : ElevatedButton(
                  onPressed: onEnable,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Enable'),
                ),
        ],
      ),
    );
  }

  Widget _buildSentState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle, color: Colors.green, size: 72),
        const SizedBox(height: 16),
        const Text(
          'SOS Sent',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your location and message have been sent to flood response '
          'authorities. Please stay safe and wait for assistance.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Profile'),
          ),
        ),
      ],
    );
  }
}
