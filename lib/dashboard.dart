import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'forecast.dart';
import 'signOut.dart';

class FloodStation {
  final String stationName;
  final String riverName;
  final String state;
  final String riverBasin;
  final double waterLevel;
  final double rainfall;
  final String status;
  final String lastUpdated;

  const FloodStation({
    required this.stationName,
    required this.riverName,
    required this.state,
    required this.riverBasin,
    required this.waterLevel,
    required this.rainfall,
    required this.status,
    required this.lastUpdated,
  });

  factory FloodStation.fromJson(Map<String, dynamic> json) {
    return FloodStation(
      stationName: json['station_name'],
      riverName: json['river_name'],
      state: json['state'],
      riverBasin: json['river_basin'],
      waterLevel: (json['water_level'] as num).toDouble(),
      rainfall: (json['rainfall'] as num).toDouble(),
      status: json['status'],
      lastUpdated: json['last_updated'],
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Future<List<Forecast>>? forecastData;
  Future<List<FloodStation>>? floodStationData;

  @override
  void initState() {
    super.initState();

    // St009 represents WP Kuala Lumpur.
    forecastData = _fetchForecastData('St009');
    floodStationData = _loadFloodStationData();
  }

  Future<List<FloodStation>> _loadFloodStationData() async {
    final jsonString = await rootBundle.loadString(
      'assets/data/flood_stations.json',
    );
    final jsonData = jsonDecode(jsonString) as List;
    return jsonData.map((json) {
      return FloodStation.fromJson(json);
    }).toList();
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

  void _refreshData() {
    setState(() {
      forecastData = _fetchForecastData('St009');
      floodStationData = _loadFloodStationData();
    });
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
            _refreshData();
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
                FutureBuilder<List<FloodStation>>(
                  future: floodStationData,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return _warningCard(_highestRiskStation(snapshot.data!));
                    }
                    if (snapshot.hasError) {
                      return _floodDataErrorCard(snapshot.error.toString());
                    }
                    return _dataLoadingCard();
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

                FutureBuilder<List<FloodStation>>(
                  future: floodStationData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _dataLoadingCard();
                    }
                    if (snapshot.hasError) {
                      return _floodDataErrorCard(snapshot.error.toString());
                    }
                    final stations = snapshot.data ?? [];
                    final normalCount = stations.where((station) {
                      return station.status.toLowerCase() == 'normal';
                    }).length;
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                number: stations.length.toString(),
                                title: 'Flood Stations',
                                subtitle: 'Active monitoring',
                                numberColor: const Color(0xFF4142C7),
                                backgroundColor: const Color(0xFFF1F2FF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _statCard(
                                number: stations.where((station) {
                                  return station.waterLevel >= 0;
                                }).length.toString(),
                                title: 'Water Level Stations',
                                subtitle: 'Monitoring now',
                                numberColor: const Color(0xFF16B86D),
                                backgroundColor: const Color(0xFFEEFBF5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _normalStationsCard(
                          normalCount,
                          stations.isEmpty ? '-' : stations.first.lastUpdated,
                        ),
                      ],
                    );
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
                        const SignOut(),
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

  FloodStation _highestRiskStation(List<FloodStation> stations) {
    int riskValue(String status) {
      if (status.toLowerCase() == 'danger') return 4;
      if (status.toLowerCase() == 'warning') return 3;
      if (status.toLowerCase() == 'alert') return 2;
      return 1;
    }

    final sortedStations = List<FloodStation>.from(stations);
    sortedStations.sort((first, second) {
      return riskValue(second.status).compareTo(riskValue(first.status));
    });
    return sortedStations.first;
  }

  Widget _warningCard(FloodStation station) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFFF31646),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33F31646),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 28,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flood Monitoring',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  station.stationName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),

                Text(
                  '${station.riverBasin}, ${station.state}',
                  style: const TextStyle(
                    color: Color(0xFFFFD5DF),
                    fontSize: 12,
                  ),
                ),

                Text(
                  '${station.status} • ${station.waterLevel} m • Updated ${station.lastUpdated}',
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

  Widget _searchBar() {
    return TextField(
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
            onPressed: _refreshData,
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

  Widget _normalStationsCard(int normalStations, String lastUpdated) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFFEEFBF5),
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                normalStations.toString(),
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
            ],
          ),

          Column(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              const Text(
                'Last Updated',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
              Text(
                lastUpdated,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataLoadingCard() {
    return Container(
      width: double.infinity,
      height: 105,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _floodDataErrorCard(String message) {
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
          Expanded(child: Text(message, style: const TextStyle(fontSize: 11))),
          IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh)),
        ],
      ),
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
    return Container(
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
    );
  }
}
