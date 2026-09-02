class Forecast {
  final String date;
  final String morningForecast;
  final String afternoonForecast;
  final String nightForecast;
  final String summaryForecast;
  final String summaryWhen;
  final int minTemp;
  final int maxTemp;

  const Forecast({
    required this.date,
    required this.morningForecast,
    required this.afternoonForecast,
    required this.nightForecast,
    required this.summaryForecast,
    required this.summaryWhen,
    required this.minTemp,
    required this.maxTemp,
  });

  factory Forecast.fromJson(Map<String, dynamic> json) {
    return Forecast(
      date: json['date'],
      morningForecast: json['morning_forecast'],
      afternoonForecast: json['afternoon_forecast'],
      nightForecast: json['night_forecast'],
      summaryForecast: json['summary_forecast'],
      summaryWhen: json['summary_when'],
      minTemp: json['min_temp'],
      maxTemp: json['max_temp'],
    );
  }
}