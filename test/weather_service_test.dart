import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/weather_service.dart';

void main() {
  group('WeatherService WMO mapping', () {
    test('maps daytime conditions', () {
      expect(
        WeatherService.conditionFromWmo(0, isDay: true),
        WeatherCondition.clear,
      );
      expect(
        WeatherService.conditionFromWmo(2, isDay: true),
        WeatherCondition.partlyCloudy,
      );
      expect(
        WeatherService.conditionFromWmo(3, isDay: true),
        WeatherCondition.cloudy,
      );
      expect(
        WeatherService.conditionFromWmo(61, isDay: true),
        WeatherCondition.rain,
      );
      expect(
        WeatherService.conditionFromWmo(73, isDay: true),
        WeatherCondition.snow,
      );
      expect(
        WeatherService.conditionFromWmo(95, isDay: true),
        WeatherCondition.thunderstorm,
      );
    });

    test('night overrides visual condition', () {
      expect(
        WeatherService.conditionFromWmo(0, isDay: false),
        WeatherCondition.night,
      );
      expect(
        WeatherService.conditionFromWmo(61, isDay: false),
        WeatherCondition.night,
      );
    });

    test('keeps fog description from raw WMO code', () {
      expect(
        WeatherService.descriptionFromWmo(45, isDay: true),
        'Sisli',
      );
    });
  });

  test('WeatherSnapshot cache json round trip keeps detail forecast', () {
    final hourly = WeatherHourlyForecast(
      time: DateTime(2026, 10, 6, 10),
      condition: WeatherCondition.partlyCloudy,
      conditionCode: 2,
      isDay: true,
      temperature: 19,
      feelsLike: 18,
      humidity: 62,
      windSpeed: 14,
      visibility: 10000,
      precipitationProbability: 10,
    );
    final daily = WeatherDailyForecast(
      date: DateTime(2026, 10, 6),
      condition: WeatherCondition.partlyCloudy,
      conditionCode: 2,
      maxTemperature: 21,
      minTemperature: 14,
      precipitationProbability: 10,
      sunrise: DateTime(2026, 10, 6, 7, 5),
      sunset: DateTime(2026, 10, 6, 18, 42),
    );
    final input = WeatherSnapshot(
      condition: WeatherCondition.partlyCloudy,
      conditionCode: 2,
      location: 'Avcılar',
      description: 'Parçalı bulutlu',
      fetchedAt: DateTime.utc(2026, 10, 6, 6, 30),
      isDay: true,
      temperature: 18,
      feelsLike: 17,
      maxTemperature: 21,
      minTemperature: 14,
      humidity: 62,
      windSpeed: 14,
      visibility: 10000,
      precipitationProbability: 10,
      hourlyForecast: [hourly],
      dailyForecast: [daily],
      sunrise: daily.sunrise,
      sunset: daily.sunset,
    );

    final output = WeatherSnapshot.fromJson(input.toJson());

    expect(output, isNotNull);
    expect(output!.condition, WeatherCondition.partlyCloudy);
    expect(output.location, 'Avcılar');
    expect(output.temperature, 18);
    expect(output.feelsLike, 17);
    expect(output.humidity, 62);
    expect(output.windSpeed, 14);
    expect(output.visibility, 10000);
    expect(output.precipitationProbability, 10);
    expect(output.hourlyForecast, hasLength(1));
    expect(output.hourlyForecast.first.temperature, 19);
    expect(output.dailyForecast, hasLength(1));
    expect(output.dailyForecast.first.maxTemperature, 21);
    expect(output.sunrise, DateTime(2026, 10, 6, 7, 5));
    expect(output.sunset, DateTime(2026, 10, 6, 18, 42));
  });
}
