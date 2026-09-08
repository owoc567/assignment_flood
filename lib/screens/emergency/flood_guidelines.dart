import 'package:flutter/material.dart';

import 'sos.dart';

class FloodGuidelinesPage extends StatelessWidget {
  const FloodGuidelinesPage({super.key});

  static const List<Map<String, dynamic>> _sections = [
    {
      'title': 'Stay Calm',
      'icon': Icons.self_improvement_rounded,
      'color': Color(0xFF4A45D6),
      'items': [
        'Take slow breaths and focus on your immediate safety.',
        'Move to higher ground or a higher floor if water is rising.',
        'Keep your phone dry and conserve its battery.',
        'Contact family members and tell them your location.',
        'Follow official evacuation instructions when available.',
      ],
    },
    {
      'title': 'Before a Flood',
      'icon': Icons.inventory_2_outlined,
      'color': Color(0xFF1976D2),
      'items': [
        'Prepare drinking water, food, medicine and a first-aid kit.',
        'Charge your phone and power bank.',
        'Keep identity documents inside a waterproof bag.',
        'Know the safest route to higher ground or an evacuation centre.',
        'Move important items and electrical devices to a higher place.',
      ],
    },
    {
      'title': 'During a Flood',
      'icon': Icons.flood_rounded,
      'color': Color(0xFFE65100),
      'items': [
        'Move to higher ground immediately when water is rising.',
        'Never walk, swim or drive through moving floodwater.',
        'Stay away from drains, rivers and damaged bridges.',
        'Do not touch electrical equipment while standing in water.',
        'Turn off electricity only when it is safe to do so.',
        'Keep children and pets away from floodwater.',
      ],
    },
    {
      'title': 'If You Are Trapped',
      'icon': Icons.sos_rounded,
      'color': Color(0xFFD32F2F),
      'items': [
        'Move to the highest safe and visible location.',
        'Use the SOS feature to share your GPS location.',
        'Send an SMS or call an emergency contact if Internet is unavailable.',
        'Use a flashlight, bright cloth or loud sound to attract attention.',
        'Do not enter fast-moving water to escape.',
        'Conserve phone battery while waiting for assistance.',
      ],
    },
    {
      'title': 'After a Flood',
      'icon': Icons.health_and_safety_outlined,
      'color': Color(0xFF388E3C),
      'items': [
        'Return home only after authorities say that it is safe.',
        'Stay away from fallen power lines and damaged electrical equipment.',
        'Avoid direct contact with floodwater because it may be contaminated.',
        'Wash your hands after touching floodwater or contaminated objects.',
        'Do not consume food or water that may have been contaminated.',
        'Photograph property damage only when the area is safe.',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Flood Safety Guide',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          _buildOfflineBanner(),
          const SizedBox(height: 16),

          const Text(
            'Emergency Guidelines',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          const Text(
            'Read these steps before, during and after a flood.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),

          ..._sections.map(_buildSection),

          const SizedBox(height: 12),
          _buildImportantWarning(),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SosPage()),
                );
              },
              icon: const Icon(Icons.sos_rounded),
              label: const Text(
                'Open Emergency SOS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'This guide is stored inside the application '
            'and remains available without Internet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3730A3), Color(0xFF625BD9)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.offline_bolt_rounded, color: Colors.white, size: 34),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Offline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'You can access this safety guide even '
                  'without an Internet connection.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(Map<String, dynamic> section) {
    final color = section['color'] as Color;
    final items = section['items'] as List<String>;

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(section['icon'] as IconData, color: color),
        ),
        title: Text(
          section['title'].toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImportantWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Never risk your life to retrieve personal '
              'belongings. Move to safety and request '
              'assistance immediately.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
