import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportFloodPage extends StatefulWidget {
  const ReportFloodPage({super.key});

  @override
  State<ReportFloodPage> createState() => _ReportFloodPageState();
}

class _ReportFloodPageState extends State<ReportFloodPage> {
  final _descriptionController = TextEditingController();
  final Location _location = Location();
  final ImagePicker _picker = ImagePicker();

  File? _photo;
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() {
      _photo = File(picked.path);
    });
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<bool> _ensureLocationReady() async {
    bool permissionGranted = await handler.Permission.locationWhenInUse.isGranted;
    if (!permissionGranted) {
      final status = await handler.Permission.locationWhenInUse.request();
      permissionGranted = status == handler.PermissionStatus.granted;
    }
    if (!permissionGranted) {
      _showError('Location permission is required to submit a report.');
      return false;
    }

    bool gpsEnabled = await handler.Permission.location.serviceStatus.isEnabled;
    if (!gpsEnabled) {
      gpsEnabled = await _location.requestService();
    }
    if (!gpsEnabled) {
      _showError('Please enable GPS to submit a report.');
      return false;
    }

    return true;
  }

  Future<void> _submitReport() async {
    if (_photo == null) {
      _showError('Please attach a photo of the flooding.');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Please describe the flood situation.');
      return;
    }

    final ready = await _ensureLocationReady();
    if (!ready) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be signed in to submit a report.');
      }

      final locationData = await _location.getLocation();
      final latitude = locationData.latitude;
      final longitude = locationData.longitude;
      if (latitude == null || longitude == null) {
        throw Exception('Unable to get your current location.');
      }

      // Upload photo to Supabase Storage under the user's own folder.
      final fileExt = _photo!.path.split('.').last;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final storagePath = '${user.id}/$fileName';

      await supabase.storage
          .from('flood-photos')
          .upload(storagePath, _photo!);

      // Fetch full name from profile, non-critical if it fails.
      String? fullName;
      try {
        final profile = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .single();
        fullName = profile['full_name'] as String?;
      } catch (_) {}

      await supabase.from('flood_reports').insert({
        'user_id': user.id,
        'full_name': fullName,
        'latitude': latitude,
        'longitude': longitude,
        'description': _descriptionController.text.trim(),
        'photo_url': storagePath,
        'status': 'pending',
      });

      if (!mounted) return;
      setState(() {
        _submitted = true;
      });
    } catch (e) {
      _showError('Failed to submit report: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Flood')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _submitted ? _buildSubmittedState() : _buildFormState(),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report Flooding in Your Area',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your report will be reviewed by flood response authorities '
              'and used to alert nearby residents.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),

        GestureDetector(
          onTap: _showPhotoSourceSheet,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _photo == null
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Add Photo (required)'),
                ],
              ),
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_photo!, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Describe the situation',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'e.g. Water rising fast on Jalan Besar, knee-deep',
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
            onPressed: _isSubmitting ? null : _submitReport,
            icon: _isSubmitting
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.send),
            label: Text(_isSubmitting ? 'Submitting...' : 'Submit Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmittedState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle, color: Colors.green, size: 72),
        const SizedBox(height: 16),
        const Text('Report Submitted', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Thank you. Authorities will review your report shortly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
        ),
      ],
    );
  }
}