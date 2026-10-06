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
  });

  test('WeatherSnapshot cache json round trip', () {
    final input = WeatherSnapshot(
      condition: WeatherCondition.partlyCloudy,
      location: 'Avcılar',
      description: 'Parçalı bulutlu',
      fetchedAt: DateTime.utc(2026, 10, 6, 6, 30),
      isDay: true,
      temperature: 18,
      maxTemperature: 21,
      minTemperature: 14,
    );

    final output = WeatherSnapshot.fromJson(input.toJson());

    expect(output, isNotNull);
    expect(output!.condition, WeatherCondition.partlyCloudy);
    expect(output.location, 'Avcılar');
    expect(output.temperature, 18);
    expect(output.maxTemperature, 21);
    expect(output.minTemperature, 14);
  });
}
