import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:assignment_flood/services/offline_profile_service.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  String? _contactName;
  String? _contactPhone;
  String? _contactRelationship;

  @override
  void initState() {
    super.initState();
    _loadPersonalContact();
  }

  Future<void> _loadPersonalContact() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select(
            'emergency_contact_name, '
            'emergency_contact_phone, '
            'emergency_contact_relationship',
          )
          .eq('id', user.id)
          .maybeSingle();

      final loadedName =
          profile?['emergency_contact_name']?.toString() ?? '';

      final loadedPhone =
          profile?['emergency_contact_phone']?.toString() ?? '';

      final loadedRelationship =
          profile?['emergency_contact_relationship']?.toString() ?? '';

      if (loadedPhone.isNotEmpty) {
        await OfflineProfileService.saveEmergencyContact(
          userId: user.id,
          contactName: loadedName,
          contactPhone: loadedPhone,
          relationship: loadedRelationship,
        );
      }

      if (!mounted) return;

      setState(() {
        _contactName = loadedName;
        _contactPhone = loadedPhone;
        _contactRelationship = loadedRelationship;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Unable to load emergency contact: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to load your emergency contact.');
    }
  }

  Future<void> _confirmCall({
    required String name,
    required String phoneNumber,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Call $name?'),
          content: Text('Your phone dialer will open with $phoneNumber.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.call),
              label: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _makeCall(phoneNumber);
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

    final uri = Uri(scheme: 'tel', path: cleanedNumber);

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened) {
        _showMessage(
          'Unable to open the phone dialer. '
          'Please call $phoneNumber manually.',
        );
      }
    } catch (error) {
      debugPrint('Unable to make phone call: $error');

      _showMessage(
        'Calling is unavailable on this device. '
        'Please call $phoneNumber manually.',
      );
    }
  }

  Future<void> _showContactForm() async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: _contactName ?? '');

    final phoneController = TextEditingController(text: _contactPhone ?? '');

    final relationshipController = TextEditingController(
      text: _contactRelationship ?? '',
    );

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                _contactPhone == null
                    ? 'Add Emergency Contact'
                    : 'Edit Emergency Contact',
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Contact name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the contact name';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: relationshipController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Relationship',
                          hintText: 'Example: Mother',
                          prefixIcon: Icon(Icons.people_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the relationship';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          hintText: 'Example: 0123456789',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final phone = value?.trim() ?? '';

                          if (phone.isEmpty) {
                            return 'Please enter the phone number';
                          }

                          final cleanedPhone = phone.replaceAll(
                            RegExp(r'[\s-]'),
                            '',
                          );

                          if (!RegExp(
                            r'^\+?[0-9]{8,15}$',
                          ).hasMatch(cleanedPhone)) {
                            return 'Please enter a valid phone number';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext, false);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() {
                            _isSaving = true;
                          });

                          final saved = await _savePersonalContact(
                            name: nameController.text.trim(),
                            relationship: relationshipController.text.trim(),
                            phoneNumber: phoneController.text.trim(),
                          );

                          if (!dialogContext.mounted) return;

                          setDialogState(() {
                            _isSaving = false;
                          });

                          if (saved) {
                            Navigator.pop(dialogContext, true);
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );


    if (submitted == true) {
      _showMessage('Emergency contact saved successfully.');
    }
  }

  Future<bool> _savePersonalContact({
    required String name,
    required String phoneNumber,
    required String relationship,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage('Please sign in again.');
      return false;
    }

    try {
      await _supabase
          .from('profiles')
          .update({
            'emergency_contact_name': name,
            'emergency_contact_phone': phoneNumber,
            'emergency_contact_relationship': relationship,
          })
          .eq('id', user.id);

      await OfflineProfileService.saveEmergencyContact(
        userId: user.id,
        contactName: name,
        contactPhone: phoneNumber,
        relationship: relationship,
      );

      if (!mounted) return false;

      setState(() {
        _contactName = name;
        _contactPhone = phoneNumber;
        _contactRelationship = relationship;
      });

      return true;
    } catch (error) {
      debugPrint('Unable to save emergency contact: $error');

      _showMessage('Unable to save emergency contact: $error');
      return false;
    }
  }

  Future<void> _confirmDeleteContact() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Emergency Contact?'),
          content: const Text(
            'This contact will also be removed from '
                'your offline SOS SMS backup.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deletePersonalContact();
    }
  }

  Future<void> _deletePersonalContact() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage('Please sign in again.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Clear the contact from Supabase.
      await _supabase
          .from('profiles')
          .update({
        'emergency_contact_name': null,
        'emergency_contact_phone': null,
        'emergency_contact_relationship': null,
      })
          .eq('id', user.id);

      // Clear the offline cached contact.
      await OfflineProfileService.deleteEmergencyContact(
        user.id,
      );

      if (!mounted) return;

      setState(() {
        _contactName = null;
        _contactPhone = null;
        _contactRelationship = null;
        _isSaving = false;
      });

      _showMessage(
        'Emergency contact deleted successfully.',
      );
    } catch (error) {
      debugPrint(
        'Unable to delete emergency contact: $error',
      );

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage(
        'Unable to delete emergency contact: $error',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _officialContactCard({
    required String title,
    required String subtitle,
    required String phoneNumber,
    required IconData icon,
    required Color color,
    bool isPrimary = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary
              ? color.withValues(alpha: 0.35)
              : const Color(0xFFE2E2E8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  phoneNumber,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            tooltip: 'Call $title',
            onPressed: () {
              _confirmCall(name: title, phoneNumber: phoneNumber);
            },
            icon: const Icon(Icons.call),
          ),
        ],
      ),
    );
  }

  Widget _personalContactCard() {
    final hasContact =
        _contactPhone != null && _contactPhone!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E2E8)),
      ),
      child: hasContact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      backgroundColor: Color(0xFFE8E7FF),
                      child: Icon(Icons.person, color: Color(0xFF3730A3)),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _contactName ?? 'Emergency Contact',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _contactRelationship ?? 'Relationship not provided',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _contactPhone!,
                            style: const TextStyle(
                              color: Color(0xFF3730A3),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit contact',
                      onPressed: _showContactForm,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete contact',
                      onPressed:
                      _isSaving ? null : _confirmDeleteContact,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3730A3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () {
                      _confirmCall(
                        name: _contactName ?? 'Emergency Contact',
                        phoneNumber: _contactPhone!,
                      );
                    },
                    icon: const Icon(Icons.call),
                    label: Text('Call ${_contactName ?? 'Emergency Contact'}'),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                const Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 46,
                  color: Color(0xFF4A45D6),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No personal contact added',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Add a trusted family member or friend whom '
                  'you can contact during an emergency.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _showContactForm,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Contact'),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3730A3),
        foregroundColor: Colors.white,
        title: const Text('Emergency Contacts'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPersonalContact,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'If you are in immediate danger, move to a '
                      'safe place and call 999.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Official Emergency Services',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _officialContactCard(
              title: 'Emergency Services',
              subtitle: 'Police, ambulance and fire services',
              phoneNumber: '999',
              icon: Icons.emergency,
              color: Colors.red,
              isPrimary: true,
            ),
            _officialContactCard(
              title: 'NADMA / NDCC',
              subtitle: '24-hour disaster operations centre',
              phoneNumber: '03-8064 2400',
              icon: Icons.flood_outlined,
              color: Colors.deepOrange,
            ),
            const SizedBox(height: 8),
            const Text(
              'My Emergency Contact',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _personalContactCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
