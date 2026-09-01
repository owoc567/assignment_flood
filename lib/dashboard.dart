import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'forecast.dart';
import 'alerts.dart';
import 'flood_service.dart';
import 'flood_station.dart';
import 'Users/profile.dart';
import 'reportflood.dart';
import 'saved_rivers.dart';
import 'search.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Future<List<Forecast>>? forecastData;
  Future<FloodStationSummary>? floodData;
  final FloodService _floodService = FloodService();
  String _weatherLocationName = 'Kuala Lumpur';
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();

    // Show Kuala Lumpur first while the phone location is being obtained.
    forecastData = _fetchForecastData('St009');
    floodData = _floodService.fetchStationSummary();

    // Replace Kuala Lumpur with the user's detected area when available.
    _loadWeatherUsingCurrentLocation();
  }

  Future<List<Forecast>> _fetchForecastData(
      String locationId,
      ) async {
    if (locationId.isEmpty) {
      return Future.value([]);
    }

    final url = Uri.parse(
      'https://api.data.gov.my/weather/forecast'
          '?contains=$locationId@location__location_id'
          '&sort=date',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as List;

        return jsonData.map((json) {
          return Forecast.fromJson(json);
        }).toList();
      } else {
        throw Exception(
          'Failed to load forecast: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception(
        'Error fetching forecast data: $e',
      );
    }
  }

  Future<List<Forecast>> _fetchForecastByLocationName(
      String locationName,
      ) async {
    final url = Uri.https(
      'api.data.gov.my',
      '/weather/forecast',
      {
        'contains': '$locationName@location__location_name',
        'sort': 'date',
      },
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final jsonData = jsonDecode(response.body) as List;
      return jsonData.map((json) => Forecast.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  String _normaliseMalaysianLocation(String location) {
    final name = location.trim().toLowerCase();

    const replacements = <String, String>{
      'wilayah persekutuan kuala lumpur': 'WP Kuala Lumpur',
      'federal territory of kuala lumpur': 'WP Kuala Lumpur',
      'kuala lumpur': 'WP Kuala Lumpur',
      'wilayah persekutuan putrajaya': 'WP Putrajaya',
      'federal territory of putrajaya': 'WP Putrajaya',
      'putrajaya': 'WP Putrajaya',
      'wilayah persekutuan labuan': 'WP Labuan',
      'federal territory of labuan': 'WP Labuan',
      'labuan': 'WP Labuan',
      'penang': 'Pulau Pinang',
      'pulau pinang': 'Pulau Pinang',
      'malacca': 'Melaka',
      'melaka': 'Melaka',
      'johore': 'Johor',
      'johor': 'Johor',
    };

    return replacements[name] ?? location.trim();
  }

  Future<void> _loadWeatherUsingCurrentLocation() async {
    if (_isGettingLocation) return;
    _isGettingLocation = true;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please turn on your phone location.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it in Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final geocoding = Geocoding();
      final List<Placemark> placemarks =
      await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        throw Exception('Unable to identify your current area.');
      }

      final place = placemarks.first;
      final detectedNames = <String>[
        place.subLocality ?? '',
        place.locality ?? '',
        place.subAdministrativeArea ?? '',
        place.administrativeArea ?? '',
      ]
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();

      if (detectedNames.isEmpty) {
        throw Exception('Unable to identify your current area.');
      }

      // Keep the smallest detected area for the card title, for example
      // "Setapak Weather", even when MET Malaysia only provides a broader
      // Kuala Lumpur forecast for that area.
      final displayLocationName = detectedNames.first;

      final candidates = detectedNames
          .map(_normaliseMalaysianLocation)
          .toSet()
          .toList();

      for (final locationName in candidates) {
        final forecasts = await _fetchForecastByLocationName(locationName);
        if (forecasts.isEmpty) continue;
        if (!mounted) return;

        setState(() {
          _weatherLocationName = displayLocationName;
          forecastData = Future.value(forecasts);
        });
        return;
      }

      // Setapak and some smaller Kuala Lumpur localities are not individual
      // data.gov.my forecast locations. Use WP Kuala Lumpur's official
      // forecast but retain the detected locality in the card title.
      final administrativeArea = _normaliseMalaysianLocation(
        place.administrativeArea ?? '',
      );

      if (administrativeArea == 'WP Kuala Lumpur') {
        final forecasts = await _fetchForecastData('St009');
        if (!mounted) return;

        setState(() {
          _weatherLocationName = displayLocationName;
          forecastData = Future.value(forecasts);
        });
        return;
      }

      throw Exception('No government forecast matches your current area.');
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Using Kuala Lumpur weather. ${error.toString()}',
          ),
        ),
      );
    } finally {
      _isGettingLocation = false;
    }
  }

  Future<void> _refreshWeather() async {
    await _loadWeatherUsingCurrentLocation();
  }

  String _translateWeather(String malayWeather) {
    final weather = malayWeather.trim().toLowerCase();

    const translations = <String, String>{
      'berjerebu': 'Hazy',
      'tiada hujan': 'No rain',
      'hujan': 'Rain',
      'hujan di beberapa tempat': 'Scattered rain',
      'hujan di satu dua tempat': 'Isolated rain',
      'hujan di satu dua tempat di kawasan pantai':
      'Isolated rain over coastal areas',
      'hujan di satu dua tempat di kawasan pedalaman':
      'Isolated rain over inland areas',
      'ribut petir': 'Thunderstorms',
      'ribut petir di beberapa tempat': 'Scattered thunderstorms',
      'ribut petir di beberapa tempat di kawasan pedalaman':
      'Scattered thunderstorms over inland areas',
      'ribut petir di satu dua tempat': 'Isolated thunderstorms',
      'ribut petir di satu dua tempat di kawasan pantai':
      'Isolated thunderstorms over coastal areas',
      'ribut petir di satu dua tempat di kawasan pedalaman':
      'Isolated thunderstorms over inland areas',
    };

    return translations[weather] ?? malayWeather;
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      floodData = _floodService.fetchStationSummary();
    });

    await Future.wait([
      _loadWeatherUsingCurrentLocation(),
      floodData!,
    ]);
  }

  void _openSearchPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SearchPage(),
      ),
    );
  }

  void _openAlertsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AlertsPage(),
      ),
    ).then((_) => _refreshDashboard());
  }

  Widget _alertBadge({bool compact = false}) {
    return FutureBuilder<FloodStationSummary>(
      future: floodData,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final summary = snapshot.data!;
        final count = summary.alertStations +
            summary.warningStations +
            summary.dangerStations;
        if (count == 0) return const SizedBox.shrink();

        if (compact) {
          return const CircleAvatar(
            radius: 4,
            backgroundColor: Color(0xFFFF174F),
          );
        }

        return Container(
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: const BoxDecoration(
            color: Color(0xFFFF174F),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          alignment: Alignment.center,
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  void _openWaterLevelStations(FloodStationSummary summary) {
    StationFilter filter = StationFilter.all;

    if (summary.dangerStations > 0) {
      filter = StationFilter.danger;
    } else if (summary.warningStations > 0) {
      filter = StationFilter.warning;
    } else if (summary.alertStations > 0) {
      filter = StationFilter.alert;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchPage(
          initialFilter: filter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.menu,
            color: Color(0xFF4A45D6),
          ),
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
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
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
                onPressed: _openAlertsPage,
              ),
              Positioned(
                right: 10,
                top: 9,
                child: _alertBadge(compact: true),
              ),
            ],
          ),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _refreshDashboard();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              20,
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<FloodStationSummary>(
                  future: floodData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return _floodLoadingCard();
                    } else if (snapshot.hasError) {
                      return _floodErrorCard(snapshot.error.toString());
                    } else if (snapshot.hasData) {
                      return _warningCard(snapshot.data!);
                    } else {
                      return _floodErrorCard('No flood data available.');
                    }
                  },
                ),

                const SizedBox(height: 14),

                _searchBar(),

                const SizedBox(height: 14),

                FutureBuilder<List<Forecast>>(
                  future: forecastData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return _weatherLoadingCard();
                    } else if (snapshot.hasError) {
                      return _weatherErrorCard(
                        snapshot.error.toString(),
                      );
                    } else if (snapshot.hasData &&
                        snapshot.data!.isNotEmpty) {
                      final forecast =
                          snapshot.data!.first;

                      return _weatherCard(forecast);
                    } else {
                      return _weatherErrorCard(
                        'No weather data available.',
                      );
                    }
                  },
                ),

                const SizedBox(height: 14),

                FutureBuilder<FloodStationSummary>(
                  future: floodData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return _stationSummaryLoading();
                    } else if (snapshot.hasError) {
                      return _floodErrorCard(snapshot.error.toString());
                    } else if (snapshot.hasData) {
                      return _stationSummary(snapshot.data!);
                    } else {
                      return _floodErrorCard('No station data available.');
                    }
                  },
                ),

                const SizedBox(height: 20),

                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _actionCard(
                        icon: Icons.cloud_outlined,
                        iconColor:
                        const Color(0xFF514BD6),
                        title: 'Weather',
                        subtitle: 'Forecast by area',
                        onPressed: _showWeatherDetails,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: _actionCard(
                        icon: Icons.bookmark_border,
                        iconColor:
                        const Color(0xFF16B86D),
                        title: 'Saved rivers',
                        subtitle: 'Your watchlist',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const SavedRiversPage(),
                            ),
                          );
                        },
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
      ),

      bottomNavigationBar: Container(
        height: 70,
        color: Colors.white,

        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.home,
                    color: Color(0xFF4A45D6),
                  ),
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
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_none,
                        color: Colors.grey,
                      ),
                      onPressed: _openAlertsPage,
                    ),
                    Positioned(
                      right: 5,
                      top: 2,
                      child: _alertBadge(),
                    ),
                  ],
                ),
                const Text(
                  'Alerts',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),

            Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.person_outline,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                        const ProfilePage(),
                      ),
                    );
                  },
                ),
                const Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningCard(FloodStationSummary summary) {
    final hasDanger = summary.dangerStations > 0;
    final hasWarning = summary.warningStations > 0;
    final hasAlert = summary.alertStations > 0;
    final hasRisk = hasDanger || hasWarning || hasAlert;

    String statusTitle = 'All Monitored Stations Safe';
    String statusDetails = '${summary.normalStations} normal readings';
    Color cardColor = const Color(0xFF16B86D);

    if (hasDanger) {
      statusTitle = 'Danger Water Level';
      statusDetails = '${summary.dangerStations} station(s) in danger';
      cardColor = const Color(0xFFF31646);
    } else if (hasWarning) {
      statusTitle = 'Water Level Warning';
      statusDetails = '${summary.warningStations} station(s) at warning level';
      cardColor = const Color(0xFFFF8A00);
    } else if (hasAlert) {
      statusTitle = 'Water Level Alert';
      statusDetails = '${summary.alertStations} station(s) at alert level';
      cardColor = const Color(0xFFF0B429);
    }

    return InkWell(
      onTap: () => _openWaterLevelStations(summary),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: cardColor.withValues(alpha: 0.20),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),

        child: Row(
          children: [
            Icon(
              hasRisk ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: Colors.white,
              size: 28,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    statusTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    statusDetails,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),

                  Text(
                    '${summary.waterLevelStations} water-level stations monitored',
                    style: const TextStyle(
                      color: Color(0xFFFFD5DF),
                      fontSize: 12,
                    ),
                  ),

                  Text(
                    'Updated: ${_formatLastUpdated(summary.lastUpdated)}',
                    style: const TextStyle(
                      color: Color(0xFFFFD5DF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastUpdated(String value) {
    if (value.isEmpty) {
      return 'Not available';
    }

    final dateTime = DateTime.tryParse(value);
    if (dateTime == null) {
      return value;
    }


    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(dateTime.day)}/${twoDigits(dateTime.month)}/'
        '${dateTime.year} ${twoDigits(dateTime.hour)}:'
        '${twoDigits(dateTime.minute)}';
  }

  Widget _floodLoadingCard() {
    return Container(
      width: double.infinity,
      height: 125,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _floodErrorCard(String errorMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unable to load live flood data',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  errorMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDashboard,
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      readOnly: true,
      onTap: _openSearchPage,
      decoration: InputDecoration(
        hintText: 'Search a river or station',
        hintStyle: const TextStyle(
          fontSize: 13,
          color: Colors.grey,
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: Colors.grey,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
    );
  }

  Widget _weatherCard(Forecast forecast) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFFF1F2FF),
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.cloud_outlined,
              color: Color(0xFF514BD6),
              size: 30,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '$_weatherLocationName Weather',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  _translateWeather(forecast.summaryForecast),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  forecast.date,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          Text(
            '${forecast.minTemp}°C\n'
                '${forecast.maxTemp}°C',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF4142C7),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherLoadingCard() {
    return Container(
      width: double.infinity,
      height: 110,

      decoration: BoxDecoration(
        color: const Color(0xFFF1F2FF),
        borderRadius: BorderRadius.circular(16),
      ),

      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _weatherErrorCard(String errorMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          const Icon(
            Icons.cloud_off,
            color: Colors.red,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unable to load weather',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  errorMessage,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshWeather,
          ),
        ],
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

      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Text(
            number,
            style: TextStyle(
              color: numberColor,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          Text(
            title,
            style: TextStyle(
              color: numberColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stationSummary(FloodStationSummary summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                number: summary.floodStations.toString(),
                title: 'Flood Stations',
                subtitle: 'All JPS station types',
                numberColor: const Color(0xFF4142C7),
                backgroundColor: const Color(0xFFF1F2FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                number: summary.waterLevelStations.toString(),
                title: 'Water Level Stations',
                subtitle: 'Monitoring now',
                numberColor: const Color(0xFF16B86D),
                backgroundColor: const Color(0xFFEEFBF5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEFBF5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.normalStations.toString(),
                    style: const TextStyle(
                      color: Color(0xFF16B86D),
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Normal Stations',
                    style: TextStyle(
                      color: Color(0xFF16B86D),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${summary.rainfallStations} rainfall stations',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Last Updated',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  Text(
                    _formatLastUpdated(summary.lastUpdated),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${summary.noLatestData} without latest reading',
                    style: const TextStyle(color: Colors.grey, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stationSummaryLoading() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _stationLoadingBox()),
            const SizedBox(width: 12),
            Expanded(child: _stationLoadingBox()),
          ],
        ),
        const SizedBox(height: 12),
        _stationLoadingBox(),
      ],
    );
  }

  Widget _stationLoadingBox() {
    return Container(
      height: 105,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),

      child: Container(
        height: 95,
        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 25,
            ),

            const Spacer(),

            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeatherDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      showDragHandle: true,

      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: FutureBuilder<List<Forecast>>(
              future: forecastData,

              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SizedBox(
                    height: 250,
                    child: Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const SizedBox(
                    height: 250,
                    child: Center(
                      child: Text(
                        'No forecast data available',
                      ),
                    ),
                  );
                }

                final forecasts = snapshot.data!;

                return SizedBox(
                  height: MediaQuery.of(context).size.height * 0.72,
                  child: Column(
                    children: [
                      Text(
                        '$_weatherLocationName 7-Day Forecast',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Expanded(
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.only(bottom: 30),
                            itemCount: forecasts.length,
                            itemBuilder: (context, index) {
                              final forecast =
                              forecasts[index];

                              return ListTile(
                                leading: const Icon(
                                  Icons.cloud_outlined,
                                  color: Color(0xFF514BD6),
                                ),
                                title: Text(
                                  forecast.date,
                                ),
                                subtitle: Text(
                                  _translateWeather(forecast.summaryForecast),
                                ),
                                trailing: Text(
                                  '${forecast.minTemp}°C - '
                                      '${forecast.maxTemp}°C',
                                  style: const TextStyle(
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _reportFloodCard() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ReportFloodPage(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),

        child: const Row(
          children: [
            Icon(
              Icons.outlined_flag,
              color: Color(0xFFFF174F),
              size: 28,
            ),

            SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Flood',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Notify authorities',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            CircleAvatar(
              radius: 4,
              backgroundColor: Color(0xFFFF174F),
            ),
          ],
        ),
      ),
    );
  }
}
