import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'forecast.dart';
import 'flood_service.dart';
import 'flood_station.dart';
import 'Users/profile.dart';
import 'reportflood.dart';
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

  @override
  void initState() {
    super.initState();

    // St009 represents WP Kuala Lumpur.
    forecastData = _fetchForecastData('St009');
    floodData = _floodService.fetchStationSummary();
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

  void _refreshWeather() {
    setState(() {
      forecastData = _fetchForecastData('St009');
    });
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      forecastData = _fetchForecastData('St009');
      floodData = _floodService.fetchStationSummary();
    });

    await Future.wait([
      forecastData!,
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
                        onPressed: () {},
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                      ),
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

    return Container(
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
                const Text(
                  'Kuala Lumpur Weather',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  forecast.summaryForecast,
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
      showDragHandle: true,

      builder: (BuildContext context) {
        return FutureBuilder<List<Forecast>>(
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
              height: 450,
              child: Column(
                children: [
                  const Text(
                    'Kuala Lumpur 7-Day Forecast',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: ListView.builder(
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
                            forecast.summaryForecast,
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
                ],
              ),
            );
          },
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