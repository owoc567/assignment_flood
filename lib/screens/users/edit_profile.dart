import 'dart:io';
import 'package:flutter/services.dart';
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
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();

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
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _toLocalPhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('60')) {
      return '0${digits.substring(2)}';
    }

    return digits;
  }

  String _toInternationalPhoneNumber(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('0')) {
      return '+60${digits.substring(1)}';
    }

    return '+$digits';
  }

  Future<void> _loadExistingProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      _emailController.text = user?.email ?? '';
      if (user == null) return;

      final data = await supabase
          .from('profiles')
          .select('full_name, phone_number, address, profile_image_url')
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      setState(() {
        _usernameController.text = data['full_name']?.toString() ?? '';

        _phoneNumberController.text = _toLocalPhoneNumber(
          data['phone_number']?.toString(),
        );

        _addressController.text = data['address']?.toString() ?? '';

        _existingImageUrl = data['profile_image_url']?.toString();

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

  String? _validatePhoneNumber(String? value) {
    final phone = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';

    if (phone.isEmpty) {
      return 'Please enter your phone number';
    }

    final normalMobile = RegExp(r'^01[02-9]\d{7}$');
    final elevenDigitMobile = RegExp(r'^011\d{8}$');

    if (!normalMobile.hasMatch(phone) && !elevenDigitMobile.hasMatch(phone)) {
      return 'Enter 01X-XXX XXXX or 011-XXXX XXXX';
    }

    return null;
  }

  String? _validateAddress(String? value) {
    final address = value?.trim() ?? '';

    if (address.isEmpty) {
      return 'Please enter your address';
    }

    if (address.length < 5) {
      return 'Address must have at least 5 characters';
    }

    if (address.length > 200) {
      return 'Address cannot exceed 200 characters';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Please enter your email';
    }

    if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email)) {
      return 'Please enter a valid email address';
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

      final newEmail =
      _emailController.text.trim().toLowerCase();

      final currentEmail =
          user.email?.trim().toLowerCase() ?? '';

      final bool emailChangeRequested =
          newEmail != currentEmail;

      if (emailChangeRequested) {
        await supabase.auth.updateUser(
          UserAttributes(email: newEmail),
          emailRedirectTo:
          'io.supabase.flutter://email-change-callback/',
        );
      }

      String? profileImageUrl = _existingImageUrl;

      if (_newProfileImage != null) {
        final String imagePath = _newProfileImage!.path.toLowerCase();
        final bool isPng = imagePath.endsWith('.png');
        final String extension = isPng ? 'png' : 'jpg';
        final String contentType = isPng ? 'image/png' : 'image/jpeg';
        final String storagePath =
            '${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';

        await supabase.storage
            .from('profile-images')
            .upload(
              storagePath,
              _newProfileImage!,
              fileOptions: FileOptions(contentType: contentType),
            );

        profileImageUrl = supabase.storage
            .from('profile-images')
            .getPublicUrl(storagePath);
      }

      final formattedPhone = _toInternationalPhoneNumber(
        _phoneNumberController.text,
      );

      final confirmedAuthEmail =
          Supabase.instance.client.auth.currentUser?.email ??
              currentEmail;

      await supabase
          .from('profiles')
          .update({
        'email': confirmedAuthEmail.trim().toLowerCase(),
        'full_name': _usernameController.text.trim(),
        'phone_number': formattedPhone,
        'address': _addressController.text.trim(),
        'profile_image_url': profileImageUrl,
      })
          .eq('id', user.id);

      if (!mounted) return;

      final message = emailChangeRequested
          ? 'Profile saved. Please check your new email and confirm the email change.'
          : 'Profile updated successfully.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      Navigator.pop(context, true); // Return true so caller can refresh.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
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
      appBar: AppBar(title: const Text('Edit Profile')),
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
                        'Email',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: _validateEmail,
                        decoration: InputDecoration(
                          hintText: 'enter your email',
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          prefixIcon: const Icon(Icons.email_outlined),
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
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: _validatePhoneNumber,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: InputDecoration(
                          hintText: 'e.g. 0123456789 or 01112345678',
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
                        'Address',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),

                      TextFormField(
                        controller: _addressController,
                        keyboardType: TextInputType.streetAddress,
                        textInputAction: TextInputAction.newline,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: _validateAddress,
                        maxLines: 3,
                        maxLength: 200,
                        decoration: InputDecoration(
                          hintText: 'Enter your home address',
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

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
