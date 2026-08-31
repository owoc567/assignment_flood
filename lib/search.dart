import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'flood_service.dart';
import 'flood_station.dart';

/// Filter options shown as chips at the top of the search page.
enum StationFilter { all, danger, alert, normal }

extension StationFilterLabel on StationFilter {
  String get label {
    switch (this) {
      case StationFilter.all:
        return 'All';
      case StationFilter.danger:
        return 'Danger';
      case StationFilter.alert:
        return 'Alert';
      case StationFilter.normal:
        return 'Normal';
    }
  }
}

class SearchPage extends StatefulWidget {
  /// Optional: pass the user's current position (e.g. from the
  /// `geolocator` package) to enable "distance" sorting/display,
  /// exactly like the design (e.g. "0.8 km"). If omitted, the list
  /// falls back to sorting alphabetically by station name.
  final double? userLat;
  final double? userLng;

  const SearchPage({
    super.key,
    this.userLat,
    this.userLng,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // JPS telemetry stations transmit new readings roughly every 15 minutes,
  // so there's no point polling more often than that — it would just
  // re-fetch the same numbers. Adjust this if you confirm a different
  // cadence from the API itself.
  static const Duration _autoRefreshInterval = Duration(minutes: 15);

  final FloodService _floodService = FloodService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  Timer? _autoRefreshTimer;

  bool _isLoading = true;
  String? _error;
  DateTime? _lastFetchedAt;

  List<FloodStation> _allStations = [];
  List<FloodStation> _filteredStations = [];

  StationFilter _selectedFilter = StationFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadStations();
    _searchController.addListener(_onSearchChanged);
    _autoRefreshTimer = Timer.periodic(
      _autoRefreshInterval,
          (_) => _loadStations(silent: true),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _autoRefreshTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  /// [silent] is true for background auto-refresh ticks — it swaps the
  /// data in place without flashing the full-page loading spinner, so a
  /// station status can visibly flip from Alert to Normal (or vice versa)
  /// without disrupting whatever the user is doing.
  Future<void> _loadStations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final stations = await _floodService.fetchStations();

      final withDistance = stations.map((s) {
        final distance = _calculateDistanceKm(s);
        return distance == null ? s : s.copyWith(distance: distance);
      }).toList();

      if (!mounted) return;

      setState(() {
        _allStations = withDistance;
        _isLoading = false;
        _error = null;
        _lastFetchedAt = DateTime.now();
      });

      _applyFilters();
    } catch (e) {
      if (!mounted) return;

      // On a silent background refresh, don't clobber a previously good
      // list with an error state — just leave the last-known data showing
      // and try again on the next tick.
      if (silent && _allStations.isNotEmpty) return;

      setState(() {
        _error = 'Failed to load stations: $e';
        _isLoading = false;
      });
    }
  }

  double? _calculateDistanceKm(FloodStation station) {
    if (widget.userLat == null ||
        widget.userLng == null ||
        station.latitude == null ||
        station.longitude == null) {
      return null;
    }

    const earthRadiusKm = 6371.0;

    final lat1 = _degToRad(widget.userLat!);
    final lat2 = _degToRad(station.latitude!);
    final dLat = _degToRad(station.latitude! - widget.userLat!);
    final dLng = _degToRad(station.longitude! - widget.userLng!);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  // ============================================================
  // SEARCH + FILTER
  // ============================================================

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _query = _searchController.text.trim();
      });
      _applyFilters();
    });
  }

  void _onFilterSelected(StationFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final query = _query.toLowerCase();

    var result = _allStations.where((station) {
      final matchesQuery = query.isEmpty ||
          station.name.toLowerCase().contains(query) ||
          station.river.toLowerCase().contains(query) ||
          station.district.toLowerCase().contains(query) ||
          station.state.toLowerCase().contains(query);

      final matchesFilter = _selectedFilter == StationFilter.all ||
          _statusMatches(station.status, _selectedFilter);

      return matchesQuery && matchesFilter;
    }).toList();

    // Sort: by distance if available, otherwise alphabetically.
    result.sort((a, b) {
      if (a.distance != null && b.distance != null) {
        return a.distance!.compareTo(b.distance!);
      }
      return a.name.compareTo(b.name);
    });

    setState(() {
      _filteredStations = result;
    });
  }

  bool _statusMatches(String status, StationFilter filter) {
    final normalized = status.toLowerCase();

    switch (filter) {
      case StationFilter.danger:
        return normalized.contains('danger') || normalized.contains('bahaya');
      case StationFilter.alert:
        return normalized.contains('alert') ||
            normalized.contains('warning') ||
            normalized.contains('waspada') ||
            normalized.contains('amaran');
      case StationFilter.normal:
        return normalized.contains('normal');
      case StationFilter.all:
        return true;
    }
  }

  // ============================================================
  // STATUS -> COLOR / LABEL
  // ============================================================

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();

    if (normalized.contains('danger') || normalized.contains('bahaya')) {
      return const Color(0xFFE53935); // red
    }
    if (normalized.contains('alert') ||
        normalized.contains('warning') ||
        normalized.contains('waspada') ||
        normalized.contains('amaran')) {
      return const Color(0xFFFB8C00); // orange
    }
    if (normalized.contains('normal')) {
      return const Color(0xFF43A047); // green
    }
    return const Color(0xFF9E9E9E); // grey fallback
  }

  String _statusLabel(String status) {
    if (status.trim().isEmpty) return 'Unknown';
    return status;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Search Stations'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          _buildResultsHeader(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Stations near me',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: const Color(0xFFF1F2F6),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: StationFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: isSelected,
              onSelected: (_) => _onFilterSelected(filter),
              selectedColor: const Color(0xFFE8EAFE),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF3F51F3) : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF3F51F3)
                      : const Color(0xFFDDDDDD),
                ),
              ),
              backgroundColor: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultsHeader() {
    final hasDistance = widget.userLat != null && widget.userLng != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_filteredStations.length} stations${_lastUpdatedLabel()}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          if (hasDistance)
            const Row(
              children: [
                Text(
                  'Sort: distance',
                  style: TextStyle(
                    color: Color(0xFF3F51F3),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _lastUpdatedLabel() {
    if (_lastFetchedAt == null) return '';

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final t = _lastFetchedAt!;
    return ' · updated ${twoDigits(t.hour)}:${twoDigits(t.minute)}';
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadStations,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredStations.isEmpty) {
      return const Center(child: Text('No stations found'));
    }

    return RefreshIndicator(
      onRefresh: _loadStations,
      child: ListView.separated(
        itemCount: _filteredStations.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final station = _filteredStations[index];
          return _buildStationTile(station);
        },
      ),
    );
  }

  Widget _buildStationTile(FloodStation station) {
    final color = _statusColor(station.status);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
      title: Text(
        station.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        station.river,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _statusLabel(station.status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (station.distance != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${station.distance!.toStringAsFixed(1)} km',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
      onTap: () {
        // TODO: navigate to a station detail page if you have one.
      },
    );
  }
}