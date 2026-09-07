import 'package:flutter/material.dart';

import '../../models/rainfall_station.dart';
import '../../services/rainfall_service.dart';
import 'rainfall_history.dart';

class HeavyRainStationsPage extends StatefulWidget {
  const HeavyRainStationsPage({super.key});

  @override
  State<HeavyRainStationsPage> createState() =>
      _HeavyRainStationsPageState();
}

class _HeavyRainStationsPageState
    extends State<HeavyRainStationsPage> {
  final RainfallService _rainfallService = RainfallService();

  bool _isLoading = true;
  String? _error;
  List<RainfallStation> _stations = [];
  String _selectedIntensity = 'All';
  String _selectedState = 'All';
  String _selectedDistrict = 'All';

  final List<String> _intensities = const [
    'All',
    'No Rainfall',
    'Light',
    'Moderate',
    'Heavy',
    'Very Heavy',
  ];

  List<String> get _states {
    final values = _stations.map((station) => station.state).toSet().toList()
      ..sort();
    return ['All', ...values];
  }

  List<String> get _districts {
    final values = _stations
        .where((station) =>
    _selectedState == 'All' || station.state == _selectedState)
        .map((station) => station.district)
        .where((district) => district.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<RainfallStation> get _filteredStations {
    final result = _stations.where((station) {
      final matchesState =
          _selectedState == 'All' || station.state == _selectedState;
      final matchesDistrict = _selectedDistrict == 'All' ||
          station.district == _selectedDistrict;
      final matchesIntensity = _selectedIntensity == 'All' ||
          station.intensity == _selectedIntensity;
      return matchesState && matchesDistrict && matchesIntensity;
    }).toList();

    result.sort((a, b) => b.rainfall.compareTo(a.rainfall));
    return result;
  }

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final stations =await _rainfallService.fetchRainfallStations();

      if (!mounted) {
        return;
      }

      setState(() {
        _stations = stations;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Color _intensityColor(String intensity) {
    switch (intensity) {
      case 'Very Heavy':
        return const Color(0xFFE53935);
      case 'Heavy':
        return const Color(0xFFF28C28);
      case 'Moderate':
        return const Color(0xFFB59B00);
      case 'Light':
        return const Color(0xFF159957);
      default:
        return Colors.grey;
    }
  }

  Color _intensityBackground(String intensity) {
    switch (intensity) {
      case 'Very Heavy':
        return const Color(0xFFFFE8E8);
      case 'Heavy':
        return const Color(0xFFFFF0DC);
      case 'Moderate':
        return const Color(0xFFFFF9CC);
      case 'Light':
        return const Color(0xFFE3F8EA);
      default:
        return const Color(0xFFF0F0F3);
    }
  }


  Widget _buildStationCard(RainfallStation station) {
    final intensityColor =
    _intensityColor(station.intensity);

    final intensityBackground =
    _intensityBackground(station.intensity);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RainfallHistoryPage(station: station),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE3E3EA),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: intensityBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.water_drop_outlined,
                color: intensityColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF20202C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${station.district}, ${station.state}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${station.state} · ${station.rainfall.toStringAsFixed(1)} mm/hr',
                    style: TextStyle(
                      color: intensityColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: intensityBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                station.intensity,
                style: TextStyle(
                  color: intensityColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _intensities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final value = _intensities[index];
              final selected = _selectedIntensity == value;
              return ChoiceChip(
                label: Text(value),
                selected: selected,
                showCheckmark: value == 'All',
                selectedColor: const Color(0xFFEDEBFF),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF4B43D6)
                      : const Color(0xFFDADAE2),
                ),
                onSelected: (_) {
                  setState(() => _selectedIntensity = value);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedState,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'State',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
                items: _states
                    .map((value) => DropdownMenuItem(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedState = value;
                    _selectedDistrict = 'All';
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('$_selectedState-$_selectedDistrict'),
                initialValue: _selectedDistrict,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'District',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
                items: _districts
                    .map((value) => DropdownMenuItem(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDistrict = value);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3730A3),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 50,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load rainfall stations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _loadStations,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final shownStations = _filteredStations;

    return RefreshIndicator(
      onRefresh: _loadStations,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildFilters(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.thunderstorm_outlined,
                  color: Color(0xFFF28C28),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${shownStations.length} rainfall '
                        '${shownStations.length == 1 ? 'station' : 'stations'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Current one-hour reading and previous 6 daily totals',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          if (shownStations.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_outlined,
                    color: Color(0xFF16B86D),
                    size: 65,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No rainfall stations found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Try selecting another state, district or intensity.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...shownStations.map(_buildStationCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF171724),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rainfall Stations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Current and recent rainfall',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadStations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}