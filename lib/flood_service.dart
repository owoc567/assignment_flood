import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

import 'flood_station.dart';

/// Talks to the NATIONAL publicinfobanjir.water.gov.my water level pages.
///
/// This site does not expose a clean JSON API for individual stations —
/// the real data lives in an HTML <table> rendered at:
///
///   https://publicinfobanjir.water.gov.my/aras-air/data-paras-air/aras-air-data/
///     ?state={code}&district=ALL&station=ALL&lang=en
///
/// Each row has: No. | Station ID | Station Name | District | Main Basin |
/// Sub River Basin | Last Updated | Water Level (m) | Normal | Alert |
/// Warning | Danger
///
/// The last four columns are the station's own threshold levels (in
/// metres). Status is computed live by comparing the current water level
/// against them — never trusted as a pre-baked field — so a station
/// automatically reverts to "Normal" the moment its reading drops back
/// under the alert threshold.
class FloodService {
  static const String _baseUrl = 'https://publicinfobanjir.water.gov.my';

  /// State codes recognised by the API, mapped to display names.
  static const Map<String, String> stateCodes = {
    'KDH': 'Kedah',
    'PNG': 'Pulau Pinang',
    'PRK': 'Perak',
    'SEL': 'Selangor',
    'WLH': 'WP Kuala Lumpur',
    'PTJ': 'WP Putrajaya',
    'NSN': 'Negeri Sembilan',
    'MLK': 'Melaka',
    'JHR': 'Johor',
    'PHG': 'Pahang',
    'TRG': 'Terengganu',
    'KEL': 'Kelantan',
    'SRK': 'Sarawak',
    'SAB': 'Sabah',
    'WLP': 'WP Labuan',
  };

  // ============================================================
  // FETCH ALL STATIONS (all states, merged)
  // ============================================================

  Future<List<FloodStation>> fetchStations() async {
    print('');
    print('🔥 fetchStations() CALLED — fetching all states in parallel');
    print('');

    final results = await Future.wait(
      stateCodes.entries.map((entry) async {
        try {
          return await fetchStationsForState(entry.key);
        } catch (e) {
          // One state failing (e.g. a temporary timeout) shouldn't blank
          // out every other state's data.
          print('⚠️ Failed to fetch ${entry.value} (${entry.key}): $e');
          return <FloodStation>[];
        }
      }),
    );

    final allStations = results.expand((list) => list).toList();
    print('PARSED STATIONS (all states): ${allStations.length}');
    return allStations;
  }

  // ============================================================
  // FETCH STATIONS FOR ONE STATE
  // ============================================================

  Future<List<FloodStation>> fetchStationsForState(String stateCode) async {
    final stateName = stateCodes[stateCode] ?? stateCode;

    final url = Uri.parse(
      '$_baseUrl/aras-air/data-paras-air/aras-air-data/',
    ).replace(queryParameters: {
      'state': stateCode,
      'district': 'ALL',
      'station': 'ALL',
      'lang': 'en',
    });

    final response = await http.get(
      url,
      headers: {
        'Accept': 'text/html',
        // Some gov sites reject requests with no/blank User-Agent.
        'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load $stateName ($stateCode): HTTP ${response.statusCode}',
      );
    }

    return _parseStationTable(response.body, stateName);
  }

  // ============================================================
  // HTML TABLE PARSING
  // ============================================================

  List<FloodStation> _parseStationTable(String htmlBody, String stateName) {
    final document = html_parser.parse(htmlBody);

    final tables = document.querySelectorAll('table');
    dom.Element? dataTable;

    for (final table in tables) {
      final headerText = table.querySelector('tr')?.text.toLowerCase() ?? '';
      if (headerText.contains('station')) {
        dataTable = table;
        break;
      }
    }

    // Fall back to the first table if none matched the header check.
    dataTable ??= tables.isNotEmpty ? tables.first : null;

    if (dataTable == null) {
      print('⚠️ No <table> found in response for $stateName');
      return [];
    }

    final rows = dataTable.querySelectorAll('tr');
    final stations = <FloodStation>[];

    // Row 0 is the header row — data starts at row 1.
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i].querySelectorAll('td');

      // Expect: No, StationID, Name, District, MainBasin, SubBasin,
      // LastUpdated, WaterLevel, Normal, Alert, Warning, Danger = 12 cols.
      if (cells.length < 12) continue;

      String cellText(int idx) => cells[idx].text.trim();

      double? parseNum(String raw) {
        final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
        if (cleaned.isEmpty) return null;
        return double.tryParse(cleaned);
      }

      final id = cellText(1);
      final name = cellText(2);
      final district = cellText(3);
      final mainBasin = cellText(4);
      final subBasin = cellText(5);
      final lastUpdated = cellText(6);

      final waterLevel = parseNum(cellText(7)) ?? 0.0;
      final normalLevel = parseNum(cellText(8));
      final alertLevel = parseNum(cellText(9));
      final warningLevel = parseNum(cellText(10));
      final dangerLevel = parseNum(cellText(11));

      if (name.isEmpty) continue; // skip malformed/empty rows

      final status = _computeStatus(
        waterLevel,
        normal: normalLevel,
        alert: alertLevel,
        warning: warningLevel,
        danger: dangerLevel,
      );

      stations.add(FloodStation(
        id: id,
        name: name,
        river: subBasin.isNotEmpty ? subBasin : mainBasin,
        district: district,
        state: stateName,
        status: status,
        waterLevel: waterLevel,
        lastUpdated: lastUpdated,
        normalLevel: normalLevel,
        alertLevel: alertLevel,
        warningLevel: warningLevel,
        dangerLevel: dangerLevel,
      ));
    }

    print('$stateName: parsed ${stations.length} stations');
    return stations;
  }

  /// Compares the live water level against this station's own threshold
  /// levels, highest severity first, so status is always derived fresh
  /// rather than trusted from a static field.
  String _computeStatus(
      double waterLevel, {
        double? normal,
        double? alert,
        double? warning,
        double? danger,
      }) {
    if (danger != null && waterLevel >= danger) return 'Danger';
    if (warning != null && waterLevel >= warning) return 'Warning';
    if (alert != null && waterLevel >= alert) return 'Alert';
    if (normal != null || alert != null || warning != null || danger != null) {
      return 'Normal';
    }
    return 'Unknown';
  }

  // ============================================================
  // SUMMARY (derived from the same station list, for the Dashboard)
  // ============================================================

  Future<FloodStationSummary> fetchStationSummary() async {
    final stations = await fetchStations();

    var normal = 0, alert = 0, warning = 0, danger = 0, unknown = 0;
    String lastUpdated = '';

    for (final s in stations) {
      switch (s.status) {
        case 'Normal':
          normal++;
          break;
        case 'Alert':
          alert++;
          break;
        case 'Warning':
          warning++;
          break;
        case 'Danger':
          danger++;
          break;
        default:
          unknown++;
      }
      if (lastUpdated.isEmpty && s.lastUpdated.isNotEmpty) {
        lastUpdated = s.lastUpdated;
      }
    }

    return FloodStationSummary(
      floodStations: stations.length,
      rainfallStations: 0,
      waterLevelStations: stations.length,
      normalStations: normal,
      alertStations: alert,
      warningStations: warning,
      dangerStations: danger,
      noLatestData: unknown,
      lastUpdated: lastUpdated,
    );
  }
}