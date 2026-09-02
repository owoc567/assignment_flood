/// Summary counts across all monitored stations.
class FloodStationSummary {
  final int floodStations;
  final int rainfallStations;
  final int waterLevelStations;
  final int normalStations;
  final int alertStations;
  final int warningStations;
  final int dangerStations;
  final int noLatestData;
  final String lastUpdated;

  const FloodStationSummary({
    required this.floodStations,
    required this.rainfallStations,
    required this.waterLevelStations,
    required this.normalStations,
    required this.alertStations,
    required this.warningStations,
    required this.dangerStations,
    required this.noLatestData,
    required this.lastUpdated,
  });
}

/// Individual flood monitoring station.
///
/// [status] is NOT trusted as-is from the API. FloodService computes it
/// live by comparing [waterLevel] against this station's own threshold
/// levels ([normalLevel], [alertLevel], [dangerLevel]) every time data is
/// fetched. That way a station that drops back under its alert threshold
/// automatically shows "Normal" again on the next refresh, with no manual
/// reset needed.
class FloodStation {
  final String id;
  final String name;
  final String river;
  final String district;
  final String state;

  /// Computed status: 'Normal', 'Alert', 'Warning', 'Danger', or 'Unknown'
  /// (Unknown = no threshold data was available to compute it from).
  final String status;

  final double waterLevel;
  final double? rainfall;
  final String lastUpdated;
  final double? latitude;
  final double? longitude;
  final double? distance;

  /// Threshold levels (in metres) used to compute [status]. Null when the
  /// API didn't provide a threshold for this station.
  final double? normalLevel;
  final double? alertLevel;
  final double? warningLevel;
  final double? dangerLevel;

  const FloodStation({
    required this.id,
    required this.name,
    required this.river,
    required this.district,
    required this.state,
    required this.status,
    required this.waterLevel,
    required this.lastUpdated,
    this.rainfall,
    this.latitude,
    this.longitude,
    this.distance,
    this.normalLevel,
    this.alertLevel,
    this.warningLevel,
    this.dangerLevel,
  });

  FloodStation copyWith({
    String? id,
    String? name,
    String? river,
    String? district,
    String? state,
    String? status,
    double? waterLevel,
    double? rainfall,
    String? lastUpdated,
    double? latitude,
    double? longitude,
    double? distance,
    double? normalLevel,
    double? alertLevel,
    double? warningLevel,
    double? dangerLevel,
  }) {
    return FloodStation(
      id: id ?? this.id,
      name: name ?? this.name,
      river: river ?? this.river,
      district: district ?? this.district,
      state: state ?? this.state,
      status: status ?? this.status,
      waterLevel: waterLevel ?? this.waterLevel,
      rainfall: rainfall ?? this.rainfall,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distance: distance ?? this.distance,
      normalLevel: normalLevel ?? this.normalLevel,
      alertLevel: alertLevel ?? this.alertLevel,
      warningLevel: warningLevel ?? this.warningLevel,
      dangerLevel: dangerLevel ?? this.dangerLevel,
    );
  }
}