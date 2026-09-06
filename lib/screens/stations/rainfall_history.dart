import 'package:flutter/material.dart';

import '../../models/rainfall_station.dart';

class RainfallHistoryPage extends StatelessWidget {
  const RainfallHistoryPage({super.key, required this.station});

  final RainfallStation station;

  Color _color(double value) {
    if (value > 60) return const Color(0xFFE53935);
    if (value >= 31) return const Color(0xFFF28C28);
    if (value >= 11) return const Color(0xFFE0C000);
    if (value >= 1) return const Color(0xFF159957);
    return Colors.grey;
  }

  Color _background(double value) => _color(value).withValues(alpha: 0.16);

  @override
  Widget build(BuildContext context) {
    final history = station.dailyRainfall.entries.toList();
    final total = history.fold<double>(0, (sum, item) => sum + item.value) +
        station.rainfall;
    final currentColor = _color(station.rainfall);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF171724),
        elevation: 0,
        title: Text(station.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('${station.district}, ${station.state}', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${station.rainfall.toStringAsFixed(1)} mm/hr', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  Text('${station.intensity} intensity', style: TextStyle(color: currentColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Updated ${station.lastUpdated}', style: const TextStyle(color: Colors.grey)),
                ]),
              ),
              Icon(Icons.thunderstorm_outlined, color: currentColor, size: 36),
            ],
          ),
          const SizedBox(height: 34),
          const Text('Previous 6 days', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ...history.map((entry) => _historyRow(entry.key, entry.value)),
                _historyRow('Today', station.rainfall, highlight: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              _summaryRow('6-day total', '${total.toStringAsFixed(1)} mm'),
              const Divider(height: 18),
              _summaryRow('Station type', 'Rainfall (JPS)'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(String date, double value, {bool highlight = false}) {
    final color = _color(value);
    return Container(
      color: highlight ? _background(value) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(date, style: TextStyle(fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
        Text('${value.toStringAsFixed(1)} mm', style: TextStyle(color: value > 0 ? color : Colors.grey, fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }

  Widget _summaryRow(String label, String value) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]);
}
