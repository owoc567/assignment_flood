class RainfallStation {
  final String id;
  final String name;
  final String district;
  final String state;
  final double rainfall;
  final String lastUpdated;

  // Date and rainfall amount for the previous daily records.
  final Map<String, double> dailyRainfall;

  const RainfallStation({
    required this.id,
    required this.name,
    required this.district,
    required this.state,
    required this.rainfall,
    required this.lastUpdated,
    required this.dailyRainfall,
  });

  String get intensity {
    if (rainfall > 60) {
      return 'Very Heavy';
    } else if (rainfall >= 31) {
      return 'Heavy';
    } else if (rainfall >= 11) {
      return 'Moderate';
    } else if (rainfall >= 1) {
      return 'Light';
    } else {
      return 'No Rainfall';
    }
  }

  double get highestRecentRainfall {
    if (dailyRainfall.isEmpty) {
      return 0;
    }

    double highest = 0;

    for (final amount in dailyRainfall.values) {
      if (amount > highest) {
        highest = amount;
      }
    }

    return highest;
  }

  String get highestRainfallDate {
    if (dailyRainfall.isEmpty) {
      return '';
    }

    String highestDate = '';
    double highest = 0;

    dailyRainfall.forEach((date, amount) {
      if (amount > highest) {
        highest = amount;
        highestDate = date;
      }
    });

    return highestDate;
  }

  bool get hasRecentHighRainfall {
    return highestRecentRainfall >= 31;
  }
}