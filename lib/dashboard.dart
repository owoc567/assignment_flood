import 'package:flutter/material.dart';
import 'signOut.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF4A45D6)),
          onPressed: () {},
        ),
        title: const Column(
          children: [
            Text(
              'MyFlood Malaysia',
              style: TextStyle(
                color: Color(0xFF222222),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Real-time Flood & Weather Info',
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none,
                  color: Color(0xFF4A45D6),
                ),
                onPressed: () {},
              ),
              const Positioned(
                right: 10,
                top: 9,
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFFFF174F),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _warningCard(),
              const SizedBox(height: 14),
              _searchBar(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      number: '336',
                      title: 'Flood Stations',
                      subtitle: 'Active monitoring',
                      numberColor: const Color(0xFF4142C7),
                      backgroundColor: const Color(0xFFF1F2FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      number: '514',
                      title: 'Water Level Stations',
                      subtitle: 'Monitoring now',
                      numberColor: const Color(0xFF16B86D),
                      backgroundColor: const Color(0xFFEEFBF5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _normalStationsCard(),
              const SizedBox(height: 20),
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      icon: Icons.cloud_outlined,
                      iconColor: const Color(0xFF514BD6),
                      title: 'Weather',
                      subtitle: 'Forecast by area',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionCard(
                      icon: Icons.bookmark_border,
                      iconColor: const Color(0xFF16B86D),
                      title: 'Saved rivers',
                      subtitle: 'Your watchlist',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _reportFloodCard(),
            ],
          ),
        ),
      ),
      // Bottom menu built using widgets taught in the practical manual.
      bottomNavigationBar: Container(
        height: 70,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.home, color: Color(0xFF4A45D6)),
                  onPressed: () {},
                ),
                const Text(
                  'Home',
                  style: TextStyle(
                    color: Color(0xFF4A45D6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_none,
                        color: Colors.grey,
                      ),
                      onPressed: () {},
                    ),
                    const Positioned(
                      right: 5,
                      top: 2,
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: Colors.red,
                        child: Text(
                          '2',
                          style: TextStyle(color: Colors.white, fontSize: 9),
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Alerts',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.person_outline, color: Colors.grey),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignOut(),
                      ),
                    );
                  },
                ),
                const Text(
                  'Profile',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF31646),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x33F31646), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Flood Warning', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(height: 3),
                Text('Sungai Golak', style: TextStyle(color: Colors.white, fontSize: 13)),
                Text('Kelantan River Basin', style: TextStyle(color: Color(0xFFFFD5DF), fontSize: 12)),
                Text('Updated: 20 May 2025, 10:30 AM', style: TextStyle(color: Color(0xFFFFD5DF), fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search a river or station',
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  Widget _statCard({
    required String number,
    required String title,
    required String subtitle,
    required Color numberColor,
    required Color backgroundColor,
  }) {
    return Container(
      height: 105,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(number, style: TextStyle(color: numberColor, fontSize: 25, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: numberColor, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _normalStationsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFEEFBF5), borderRadius: BorderRadius.circular(16)),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('482', style: TextStyle(color: Color(0xFF16B86D), fontSize: 25, fontWeight: FontWeight.bold)),
              Text('Normal Stations', style: TextStyle(color: Color(0xFF16B86D), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Last Updated', style: TextStyle(color: Colors.grey, fontSize: 10)),
              Text('10:30 AM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard({required IconData icon, required Color iconColor, required String title, required String subtitle}) {
    return Container(
      height: 95,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 25),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _reportFloodCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: const Row(
        children: [
          Icon(Icons.outlined_flag, color: Color(0xFFFF174F), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report Flood', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text('Notify authorities', style: TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          CircleAvatar(radius: 4, backgroundColor: Color(0xFFFF174F)),
        ],
      ),
    );
  }
}
