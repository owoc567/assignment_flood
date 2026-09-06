import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:flutter/foundation.dart';



import '../models/rainfall_station.dart';

class RainfallService {
  static const String _baseUrl =
      'https://publicinfobanjir.water.gov.my';

  static const Map<String, String> stateCodes = {
    'PLS': 'Perlis',
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

  Future<List<RainfallStation>> fetchRainfallStations() async {
    final results = await Future.wait(
      stateCodes.entries.map((entry) async {
        try {
          return await fetchRainfallForState(entry.key);
        } catch (error) {
          debugPrint(
            'Failed to fetch rainfall for ${entry.value}: $error',
          );

          return <RainfallStation>[];
        }
      }),
    );

    return results.expand((stations) => stations).toList();
  }

  Future<List<RainfallStation>>
  fetchRecentHighRainfallStations() async {
    final stations = await fetchRainfallStations();

    debugPrint('Total Rainfall StationsL ${stations.length}',
    );

    final recentHighRainfall = stations.where((station) {
      return station.hasRecentHighRainfall;
    }).toList();

    debugPrint('Recent High Rainfall Stations:'
                '${recentHighRainfall.length}',
    );

    recentHighRainfall.sort((a, b) {
      return b.highestRecentRainfall.compareTo(
        a.highestRecentRainfall,
      );
    });

    return recentHighRainfall;
  }

// Keep this temporarily so the existing dashboard does not show an error.
  Future<List<RainfallStation>> fetchHeavyRainStations() {
    return fetchRecentHighRainfallStations();
  }


  Future<List<RainfallStation>> fetchRainfallForState(
      String stateCode,
      ) async {
    final stateName = stateCodes[stateCode] ?? stateCode;

    final url = Uri.parse(
      '$_baseUrl/wp-content/themes/shapely/agency/'
          'searchresultrainfall.php',
    ).replace(
      queryParameters: {
        'state': stateCode,
        'district': 'ALL',
        'station': 'ALL',
        'loginStatus': '',
        'language': '',
      },
    );

    debugPrint('Rainfall URL: $url');

    final response = await http
        .get(
      url,
      headers: {
        'Accept': 'text/html',
        'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/120 Mobile Safari/537.36',
      },
    )
        .timeout(
      const Duration(seconds: 60),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode} for $stateName',
      );
    }

    return _parseRainfallTable(
      response.body,
      stateName,
    );
  }

  List<RainfallStation> _parseRainfallTable(
      String htmlBody,
      String stateName,
      ) {
    final document = html_parser.parse(htmlBody);
    final tables = document.querySelectorAll('table');


    dom.Element? rainfallTable;

// The rainfall data table contains station rows with 13 columns.
// Selecting by its structure is more reliable than checking header text.
    for (final table in tables) {
      final rows = table.querySelectorAll('tr');

      final containsStationRows = rows.any((row) {
        return row.querySelectorAll('td').length >= 13;
      });

      if (containsStationRows) {
        rainfallTable = table;
        break;
      }
    }

    if (rainfallTable == null) {
      debugPrint(
        'No rainfall table found for $stateName',
      );

      debugPrint(
        '$stateName rainfall table found',
      );

      return [];
    }



    final rows = rainfallTable.querySelectorAll('tr');
    final stations = <RainfallStation>[];
    final datePattern = RegExp(
      r'^\d{2}/\d{2}/\d{4}$',
    );

    final detectedDates = rainfallTable
        .querySelectorAll('th, td')
        .map((cell) => cell.text.trim())
        .where((text) => datePattern.hasMatch(text))
        .toSet()
        .take(6)
        .toList();

    final dailyDates = detectedDates.length == 6
        ? detectedDates
        : List.generate(
      6,
          (index) => 'Previous day ${6 - index}',
    );

    for (final row in rows) {
      final cells = row.querySelectorAll('td');

      // Actual column structure:
      // 0: No.
      // 1: Station ID
      // 2: Station
      // 3: District
      // 4: Last Updated
      // 5-10: Previous six daily rainfall values
      // 11: Rainfall from midnight
      // 12: Current one-hour rainfall
      if (cells.length < 13) {
        continue;
      }

      String cellText(int index) {
        return cells[index].text.trim();
      }

      double? parseRainfall(String value) {
        final cleaned = value.replaceAll(
          RegExp(r'[^0-9.\-]'),
          '',
        );

        if (cleaned.isEmpty || cleaned == '-') {
          return null;
        }

        return double.tryParse(cleaned);
      }

      final stationId = cellText(1);
      final stationName = cellText(2);
      final district = cellText(3);
      final lastUpdated = cellText(4);

      final currentOneHourRainfall = parseRainfall(
        cellText(cells.length - 1),
      ) ??
          0;

      final dailyRainfall = <String, double>{};

      // Columns 5 to 10 are always the previous six daily readings.
      for (var index = 0; index < 6; index++) {
        final cellIndex = 5 + index;
        final amount = parseRainfall(
          cellText(cellIndex),
        );

        // Ignore -9999 because it represents unavailable data.
        if (amount != null && amount >= 0) {
          dailyRainfall[dailyDates[index]] = amount;
        }
      }

      stations.add(
        RainfallStation(
          id: stationId,
          name: stationName,
          district: district,
          state: stateName,
          rainfall:
          currentOneHourRainfall < 0
              ? 0
              : currentOneHourRainfall,
          lastUpdated: lastUpdated,
          dailyRainfall: dailyRainfall,
        ),
      );
    }

    debugPrint(
      '$stateName: ${stations.length} rainfall stations',
    );

    return stations;
  }
}