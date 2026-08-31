import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  File? _newProfileImage;
  String? _existingImageUrl;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('profiles')
          .select('full_name, phone_number, profile_image_url')
          .eq('id', user.id)
          .single();

      setState(() {
        _usernameController.text = data['full_name'] as String? ?? '';
        _phoneNumberController.text = data['phone_number'] as String? ?? '';
        _existingImageUrl = data['profile_image_url'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile for edit: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _newProfileImage = File(pickedFile.path);
      });
    }
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) {
      return 'Please enter your name';
    }
    if (username.length < 3) {
      return 'Username must have at least 3 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_ ]+$').hasMatch(username)) {
      return 'Use letters, numbers, spaces, and underscore only';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('You must be signed in to edit your profile.');
      }

      String? profileImageUrl = _existingImageUrl;

      if (_newProfileImage != null) {
        final String imagePath = _newProfileImage!.path.toLowerCase();
        final bool isPng = imagePath.endsWith('.png');
        final String extension = isPng ? 'png' : 'jpg';
        final String contentType = isPng ? 'image/png' : 'image/jpeg';
        final String storagePath =
            '${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';

        await supabase.storage.from('profile-images').upload(
          storagePath,
          _newProfileImage!,
          fileOptions: FileOptions(contentType: contentType),
        );

        profileImageUrl =
            supabase.storage.from('profile-images').getPublicUrl(storagePath);
      }

      await supabase.from('profiles').update({
        'full_name': _usernameController.text.trim(),
        'phone_number': _phoneNumberController.text.trim().isEmpty
            ? null
            : _phoneNumberController.text.trim(),
        'profile_image_url': profileImageUrl,
      }).eq('id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      Navigator.pop(context, true); // Return true so caller can refresh.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _isSaving ? null : _pickImage,
                    child: Stack(
                      children: [
                        ClipOval(
                          child: _newProfileImage != null
                              ? Image.file(
                            _newProfileImage!,
                            width: 130,
                            height: 130,
                            fit: BoxFit.cover,
                          )
                              : (_existingImageUrl != null
                              ? Image.network(
                            _existingImageUrl!,
                            width: 130,
                            height: 130,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/profileImageDefault.jpg',
                                width: 130,
                                height: 130,
                                fit: BoxFit.cover,
                              );
                            },
                          )
                              : Image.asset(
                            'assets/images/profileImageDefault.jpg',
                            width: 130,
                            height: 130,
                            fit: BoxFit.cover,
                          )),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.indigo,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Username',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _usernameController,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateUsername,
                  decoration: InputDecoration(
                    hintText: 'enter your username',
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                const Text(
                  'Phone',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneNumberController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'enter your phone number',
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}