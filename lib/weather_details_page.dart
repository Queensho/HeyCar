import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cepqar_theme.dart';
import 'weather_service.dart';

class WeatherDetailsPage extends StatefulWidget {
  const WeatherDetailsPage({
    super.key,
    required this.service,
    this.initialWeather,
    this.onUpdated,
  });

  final WeatherService service;
  final WeatherSnapshot? initialWeather;
  final ValueChanged<WeatherSnapshot>? onUpdated;

  @override
  State<WeatherDetailsPage> createState() => _WeatherDetailsPageState();
}

class _WeatherDetailsPageState extends State<WeatherDetailsPage> {
  WeatherSnapshot? weather;
  bool loading = false;

  Color get bg => CepqarTheme.bg;
  Color get panel => CepqarTheme.panel;
  Color get line => CepqarTheme.line;
  Color get text => CepqarTheme.text;
  Color get muted => CepqarTheme.muted;
  Color get purple => CepqarTheme.purple;
  Color get lime => CepqarTheme.lime;

  @override
  void initState() {
    super.initState();
    weather = widget.initialWeather;
    if (weather == null) _refresh();
  }

  Future<void> _refresh({bool force = true}) async {
    if (loading) return;
    if (mounted) setState(() => loading = true);
    try {
      final next = await widget.service.load(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        weather = next;
        loading = false;
      });
      widget.onUpdated?.call(next);
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get _unavailable =>
      weather == null ||
      (weather!.isFallback && weather!.temperature == null);

  String _degree(double? value) =>
      value == null ? '--°' : '${value.round()}°';

  String _number(double? value, {int decimals = 0}) {
    if (value == null) return '--';
    return value.toStringAsFixed(decimals);
  }

  String _visibility(double? meters) {
    if (meters == null) return '--';
    final km = meters / 1000;
    return '${km >= 10 ? km.round() : km.toStringAsFixed(1)} km';
  }

  String _wind(double? value) =>
      value == null ? '--' : '${value.round()} km/s';

  String _percent(double? value) =>
      value == null ? '--' : '%${value.round()}';

  String _dateLabel(DateTime date) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    const weekdays = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    return 'Bugün, ${date.day} ${months[date.month - 1]} ${weekdays[date.weekday - 1]}';
  }

  String _weekday(DateTime date, {bool today = false}) {
    if (today) return 'Bugün';
    const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return names[date.weekday - 1];
  }

  _DrivingGuidance _guidance(WeatherSnapshot w) {
    final visibilityKm = (w.visibility ?? 10000) / 1000;
    final wind = w.windSpeed ?? 0;
    if (w.condition == WeatherCondition.thunderstorm || wind >= 60) {
      return const _DrivingGuidance(
        title: 'Zorlu sürüş koşulları',
        subtitle: 'Güçlü rüzgar ve yağış bekleniyor.',
        icon: Icons.warning_amber_rounded,
        accent: Color(0xFFFF8A35),
      );
    }
    if (w.condition == WeatherCondition.snow) {
      return const _DrivingGuidance(
        title: 'Buzlanma riski',
        subtitle: 'Hızınızı düşürün ve dikkatli sürün.',
        icon: Icons.ac_unit_rounded,
        accent: Color(0xFF3888FF),
      );
    }
    if (w.condition == WeatherCondition.rain) {
      return const _DrivingGuidance(
        title: 'Islak zemin',
        subtitle: 'Takip mesafenizi artırın.',
        icon: Icons.water_drop_rounded,
        accent: Color(0xFF347DFF),
      );
    }
    if (w.conditionCode == 45 ||
        w.conditionCode == 48 ||
        visibilityKm < 4) {
      return const _DrivingGuidance(
        title: 'Düşük görüş',
        subtitle: 'Görüş mesafenize uygun hızda ilerleyin.',
        icon: Icons.visibility_rounded,
        accent: Color(0xFF5F72A5),
      );
    }
    return const _DrivingGuidance(
      title: 'Sürüş için uygun hava koşulları',
      subtitle: 'Şu anda önemli bir risk bulunmuyor.',
      icon: Icons.directions_car_filled_rounded,
      accent: Color(0xFF18B956),
    );
  }

  String _advice(WeatherSnapshot w) {
    final visibilityKm = (w.visibility ?? 10000) / 1000;
    if (w.conditionCode == 45 ||
        w.conditionCode == 48 ||
        visibilityKm < 4) {
      return 'Görüş mesafesi düşük. Sis farlarını gerektiğinde kullanın.';
    }
    if (w.condition == WeatherCondition.thunderstorm) {
      return 'Fırtına bekleniyor. Mümkünse yolculuğu erteleyin; sürüşte ani manevralardan kaçının.';
    }
    if (w.condition == WeatherCondition.snow) {
      return 'Buzlanma riski olabilir. Hızınızı düşürün ve dikkatli sürün.';
    }
    if (w.condition == WeatherCondition.rain) {
      return 'Yağış bekleniyor. Takip mesafenizi artırın ve ani frenlerden kaçının.';
    }
    if (w.condition == WeatherCondition.night || !w.isDay) {
      return 'Gece sürüşünde görüş mesafenize uygun hızda ilerleyin.';
    }
    if ((w.maxTemperature ?? w.temperature ?? 0) >= 32) {
      return 'Yüksek sıcaklık bekleniyor. Uzun yol öncesi aracınızın sıvı seviyelerini kontrol edin.';
    }
    if (w.condition == WeatherCondition.clear ||
        w.condition == WeatherCondition.partlyCloudy) {
      return 'Hava açık. Uzun yolda güneş gözlüğü kullanmanız sürüş konforunuzu artırır.';
    }
    return 'Hava koşullarını takip edin ve yolculuk öncesi aracınızın temel kontrollerini yapın.';
  }

  String _roadCondition(WeatherSnapshot w) {
    if (w.condition == WeatherCondition.snow) return 'Hava: Karlı';
    if (w.condition == WeatherCondition.rain) return 'Hava: Islak';
    if (w.condition == WeatherCondition.thunderstorm) return 'Hava: Zorlu';
    if (w.conditionCode == 45 || w.conditionCode == 48) return 'Hava: Sisli';
    return 'Hava: Normal';
  }

  @override
  Widget build(BuildContext context) {
    if (weather == null && loading) return _skeleton();
    final w = weather ??
        WeatherSnapshot(
          condition: WeatherCondition.partlyCloudy,
          conditionCode: 2,
          location: 'Konum',
          description: 'Hava durumu şu anda alınamıyor.',
          fetchedAt: DateTime.now(),
          isDay: true,
          isFallback: true,
        );
    final guidance = _guidance(w);
    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: purple,
        onRefresh: () => _refresh(force: true),
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _hero(w),
            if (_unavailable)
              _errorCard()
            else ...[
              _drivingCard(guidance),
              _forecastCard(
                title: 'Saatlik Tahmin',
                child: _hourly(w),
              ),
              _forecastCard(
                title: '7 Günlük Tahmin',
                child: _daily(w),
              ),
              _drivingConditions(w),
              _adviceCard(w),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _hero(WeatherSnapshot w) {
    final dark = w.condition == WeatherCondition.rain ||
        w.condition == WeatherCondition.thunderstorm ||
        w.condition == WeatherCondition.night;
    final foreground = dark ? Colors.white : const Color(0xFF071126);
    final secondary = dark
        ? Colors.white.withValues(alpha: .78)
        : const Color(0xFF535D73);
    return SizedBox(
      height: 365,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _WeatherHeroPainter(
                condition: w.condition,
                lime: lime,
                purple: purple,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Column(
                children: [
                  SizedBox(
                    height: 42,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: foreground,
                              size: 21,
                            ),
                          ),
                        ),
                        Image.asset(
                          CepqarTheme.isLight
                              ? 'assets/file_00000000b130820abb8d411e67ab0d25.png'
                              : 'assets/Logoyeni.png',
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: dark ? lime : const Color(0xFF1976FF),
                          size: 22,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            w.location.isEmpty ? 'Konum' : w.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dateLabel(DateTime.now()),
                      style: TextStyle(
                        color: secondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _degree(w.temperature),
                      style: TextStyle(
                        color: foreground,
                        fontSize: 72,
                        height: .92,
                        letterSpacing: -3,
                        fontWeight: FontWeight.w900,
                        shadows: dark
                            ? const [
                                Shadow(
                                  color: Color(0x40000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      w.description,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _metrics(w, foreground, secondary),
                  const SizedBox(height: 13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metrics(
    WeatherSnapshot w,
    Color foreground,
    Color secondary,
  ) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          _metric(
            icon: Icons.arrow_upward_rounded,
            iconColor: const Color(0xFFFF3E48),
            value: _degree(w.maxTemperature),
            label: 'En yüksek',
            foreground: foreground,
            secondary: secondary,
          ),
          _divider(),
          _metric(
            icon: Icons.arrow_downward_rounded,
            iconColor: const Color(0xFF1976FF),
            value: _degree(w.minTemperature),
            label: 'En düşük',
            foreground: foreground,
            secondary: secondary,
          ),
          _divider(),
          _metric(
            icon: Icons.thermostat_rounded,
            iconColor: purple,
            value: _degree(w.feelsLike),
            label: 'Hissedilen',
            foreground: foreground,
            secondary: secondary,
          ),
          _divider(),
          _metric(
            icon: Icons.water_drop_outlined,
            iconColor: purple,
            value: _percent(w.humidity),
            label: 'Nem',
            foreground: foreground,
            secondary: secondary,
          ),
          _divider(),
          _metric(
            icon: Icons.air_rounded,
            iconColor: purple,
            value: _wind(w.windSpeed),
            label: 'Rüzgar',
            foreground: foreground,
            secondary: secondary,
          ),
          _divider(),
          _metric(
            icon: Icons.visibility_outlined,
            iconColor: purple,
            value: _visibility(w.visibility),
            label: 'Görüş',
            foreground: foreground,
            secondary: secondary,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 42,
        color: Colors.black.withValues(alpha: .08),
      );

  Widget _metric({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color foreground,
    required Color secondary,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: secondary,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _drivingCard(_DrivingGuidance guidance) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Container(
          minHeight: 76,
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                guidance.accent.withValues(alpha: .09),
                lime.withValues(alpha: .10),
                Colors.white.withValues(alpha: .94),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: guidance.accent.withValues(alpha: .16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: lime.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  guidance.icon,
                  color: guidance.accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guidance.title,
                      style: const TextStyle(
                        color: Color(0xFF0B1530),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      guidance.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF727A8D),
                        fontSize: 11.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: guidance.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  guidance.title.startsWith('Sürüş')
                      ? Icons.check_rounded
                      : Icons.priority_high_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _forecastCard({
    required String title,
    required Widget child,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    'Tümünü Gör',
                    style: TextStyle(
                      color: purple,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: purple,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );

  Widget _hourly(WeatherSnapshot w) {
    final items = w.hourlyForecast;
    if (items.isEmpty) {
      return SizedBox(
        height: 94,
        child: Center(
          child: Text(
            'Saatlik tahmin alınamıyor.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ),
      );
    }
    return SizedBox(
      height: 102,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (_, index) {
          final item = items[index];
          final now = index == 0;
          final time =
              '${item.time.hour.toString().padLeft(2, '0')}:00';
          return Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: now
                  ? purple.withValues(alpha: .09)
                  : CepqarTheme.isLight
                      ? const Color(0xFFFBFBFE)
                      : const Color(0xFF151D2D),
              borderRadius: BorderRadius.circular(14),
              border: now
                  ? Border.all(color: purple.withValues(alpha: .12))
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  now ? 'Şu an' : time,
                  style: TextStyle(
                    color: now ? purple : muted,
                    fontSize: 9.5,
                    fontWeight: now ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                _WeatherGlyph(
                  condition: item.condition,
                  size: 29,
                ),
                const Spacer(),
                Text(
                  _degree(item.temperature),
                  style: TextStyle(
                    color: text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _daily(WeatherSnapshot w) {
    final items = w.dailyForecast;
    if (items.isEmpty) {
      return SizedBox(
        height: 112,
        child: Center(
          child: Text(
            '7 günlük tahmin alınamıyor.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ),
      );
    }
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final item = items[index];
          return Container(
            width: 69,
            padding: const EdgeInsets.fromLTRB(5, 8, 5, 7),
            decoration: BoxDecoration(
              color: index == 0
                  ? purple.withValues(alpha: .06)
                  : CepqarTheme.isLight
                      ? const Color(0xFFFBFBFE)
                      : const Color(0xFF151D2D),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  _weekday(item.date, today: index == 0),
                  style: TextStyle(
                    color: text,
                    fontSize: 10.5,
                    fontWeight:
                        index == 0 ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                _WeatherGlyph(condition: item.condition, size: 29),
                const Spacer(),
                Text(
                  _degree(item.maxTemperature),
                  style: const TextStyle(
                    color: Color(0xFFFF4E5B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _degree(item.minTemperature),
                  style: const TextStyle(
                    color: Color(0xFF1976FF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _drivingConditions(WeatherSnapshot w) {
    final cells = [
      (
        Icons.route_rounded,
        const Color(0xFF8BCD26),
        'Yol Durumu',
        _roadCondition(w),
      ),
      (
        Icons.water_drop_rounded,
        const Color(0xFF42C649),
        'Yağış Riski',
        _percent(w.precipitationProbability),
      ),
      (
        Icons.air_rounded,
        purple,
        'Rüzgar',
        _wind(w.windSpeed),
      ),
      (
        Icons.visibility_outlined,
        const Color(0xFF2878D8),
        'Görüş',
        _visibility(w.visibility),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sürüş Koşulları',
              style: TextStyle(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: cells[i].$2.withValues(alpha: .075),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: cells[i].$2.withValues(alpha: .13),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              cells[i].$1,
                              color: cells[i].$2,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cells[i].$3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 8.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cells[i].$4,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 9.7,
                                    height: 1.05,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _adviceCard(WeatherSnapshot w) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 13, 12, 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                purple.withValues(alpha: .08),
                const Color(0xFFF6F1FF),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: purple.withValues(alpha: .10)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [purple, purple.withValues(alpha: .78)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bugünün Önerisi',
                      style: TextStyle(
                        color: purple,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _advice(w),
                      style: const TextStyle(
                        color: Color(0xFF70768A),
                        fontSize: 11,
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: purple,
                size: 24,
              ),
            ],
          ),
        ),
      );

  Widget _errorCard() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: line),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: muted,
                size: 34,
              ),
              const SizedBox(height: 9),
              Text(
                'Hava durumu şu anda alınamıyor.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: loading ? null : () => _refresh(force: true),
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );

  Widget _skeleton() {
    Widget block(double height, {double? width, double radius = 16}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFEDEFF5),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
    return Scaffold(
      backgroundColor: bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 365,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFEAF7FF),
                          Color(0xFFDCEBFF),
                          Color(0xFFF5FFD7),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        block(30, width: 130),
                        const SizedBox(height: 32),
                        block(24, width: 120),
                        const SizedBox(height: 12),
                        block(72, width: 145),
                        const SizedBox(height: 8),
                        block(22, width: 150),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: block(i == 0 ? 76 : 150),
            ),
        ],
      ),
    );
  }
}

class _DrivingGuidance {
  const _DrivingGuidance({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
}

class _WeatherGlyph extends StatelessWidget {
  const _WeatherGlyph({
    required this.condition,
    required this.size,
  });

  final WeatherCondition condition;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (condition) {
      case WeatherCondition.clear:
        return Icon(
          Icons.wb_sunny_rounded,
          color: const Color(0xFFFFC928),
          size: size,
        );
      case WeatherCondition.partlyCloudy:
        return SizedBox(
          width: size * 1.2,
          height: size,
          child: Stack(
            children: [
              Positioned(
                left: 1,
                top: 0,
                child: Icon(
                  Icons.wb_sunny_rounded,
                  color: const Color(0xFFFFC928),
                  size: size * .72,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Icon(
                  Icons.cloud_rounded,
                  color: const Color(0xFFA9C9E9),
                  size: size * .86,
                ),
              ),
            ],
          ),
        );
      case WeatherCondition.cloudy:
        return Icon(
          Icons.cloud_rounded,
          color: const Color(0xFFA8BED2),
          size: size,
        );
      case WeatherCondition.rain:
        return Icon(
          Icons.grain_rounded,
          color: const Color(0xFF3C84E8),
          size: size,
        );
      case WeatherCondition.snow:
        return Icon(
          Icons.ac_unit_rounded,
          color: const Color(0xFF79B7F0),
          size: size,
        );
      case WeatherCondition.thunderstorm:
        return Icon(
          Icons.thunderstorm_rounded,
          color: CepqarTheme.purple,
          size: size,
        );
      case WeatherCondition.night:
        return Icon(
          Icons.nightlight_round,
          color: const Color(0xFF7767CE),
          size: size,
        );
    }
  }
}

class _WeatherHeroPainter extends CustomPainter {
  const _WeatherHeroPainter({
    required this.condition,
    required this.lime,
    required this.purple,
  });

  final WeatherCondition condition;
  final Color lime;
  final Color purple;

  bool get dark => condition == WeatherCondition.rain ||
      condition == WeatherCondition.thunderstorm ||
      condition == WeatherCondition.night;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = switch (condition) {
      WeatherCondition.clear => const [
          Color(0xFF71BDFF),
          Color(0xFFAEDCFF),
          Color(0xFFF5FFE0),
        ],
      WeatherCondition.partlyCloudy => const [
          Color(0xFF78BEF8),
          Color(0xFFB5DDF4),
          Color(0xFFF0F7DF),
        ],
      WeatherCondition.cloudy => const [
          Color(0xFF9EC3DA),
          Color(0xFFC5D5E1),
          Color(0xFFF1F5EE),
        ],
      WeatherCondition.rain => const [
          Color(0xFF314B7D),
          Color(0xFF526998),
          Color(0xFF8778B4),
        ],
      WeatherCondition.snow => const [
          Color(0xFFC8E4F8),
          Color(0xFFEAF7FF),
          Color(0xFFF6FFF4),
        ],
      WeatherCondition.thunderstorm => const [
          Color(0xFF222D57),
          Color(0xFF4A487D),
          Color(0xFF7664A2),
        ],
      WeatherCondition.night => const [
          Color(0xFF111A3A),
          Color(0xFF30285F),
          Color(0xFF5A3D7E),
        ],
    };
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0, .58, 1],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.75, .88),
          radius: 1.1,
          colors: [
            lime.withValues(alpha: dark ? .12 : .25),
            lime.withValues(alpha: .02),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    if (condition == WeatherCondition.night) {
      _moon(canvas, size);
      _stars(canvas, size);
      _cloud(canvas, Offset(size.width * .73, 150), 1.5, .17);
    } else {
      if (condition == WeatherCondition.clear ||
          condition == WeatherCondition.partlyCloudy) {
        _sun(canvas, size);
      }
      if (condition != WeatherCondition.clear) {
        _cloud(
          canvas,
          Offset(size.width * .69, 154),
          1.6,
          dark ? .28 : .74,
        );
        _cloud(
          canvas,
          Offset(size.width * .86, 194),
          1.2,
          dark ? .18 : .50,
        );
      } else {
        _cloud(canvas, Offset(size.width * .75, 196), 1.0, .52);
      }
      if (condition == WeatherCondition.rain) _rain(canvas, size);
      if (condition == WeatherCondition.snow) _snow(canvas, size);
      if (condition == WeatherCondition.thunderstorm) {
        _lightning(canvas, size);
      }
    }

    _horizon(canvas, size);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 95, size.width, 95),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0),
            (dark ? const Color(0xFF15203C) : Colors.white)
                .withValues(alpha: dark ? .18 : .58),
          ],
        ).createShader(
          Rect.fromLTWH(0, size.height - 95, size.width, 95),
        ),
    );
  }

  void _sun(Canvas canvas, Size size) {
    final center = Offset(size.width * .79, 118);
    final ray = Paint()
      ..color = const Color(0xFFFFE05A).withValues(alpha: .40)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 16; i++) {
      final angle = math.pi * 2 * i / 16;
      final p1 = center + Offset(math.cos(angle), math.sin(angle)) * 51;
      final p2 = center + Offset(math.cos(angle), math.sin(angle)) * 68;
      canvas.drawLine(p1, p2, ray);
    }
    canvas.drawCircle(
      center,
      51,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFF8C8),
            Color(0xFFFFE65C),
            Color(0xFFFFC427),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 51)),
    );
    canvas.drawCircle(
      center,
      76,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE85E).withValues(alpha: .23),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 76)),
    );
  }

  void _cloud(
    Canvas canvas,
    Offset center,
    double scale,
    double opacity,
  ) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, 10 * scale),
          width: 85 * scale,
          height: 28 * scale,
        ),
        Radius.circular(18 * scale),
      ),
      paint,
    );
    canvas.drawCircle(
      center.translate(-25 * scale, 0),
      19 * scale,
      paint,
    );
    canvas.drawCircle(
      center.translate(0, -8 * scale),
      27 * scale,
      paint,
    );
    canvas.drawCircle(
      center.translate(27 * scale, 1),
      19 * scale,
      paint,
    );
  }

  void _rain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC6DEFF).withValues(alpha: .42)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 13; i++) {
      final x = size.width * (.55 + i * .034);
      final y = 205.0 + (i % 3) * 8;
      canvas.drawLine(Offset(x, y), Offset(x - 4, y + 16), paint);
    }
  }

  void _snow(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .82);
    for (var i = 0; i < 20; i++) {
      final x = size.width * (.52 + (i % 7) * .065);
      final y = 185.0 + (i % 5) * 24;
      canvas.drawCircle(Offset(x, y), i.isEven ? 2.2 : 1.5, paint);
    }
  }

  void _lightning(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .78, 192)
      ..lineTo(size.width * .70, 235)
      ..lineTo(size.width * .77, 228)
      ..lineTo(size.width * .72, 276);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFEF6D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _moon(Canvas canvas, Size size) {
    final center = Offset(size.width * .79, 111);
    final outer = Path()
      ..addOval(Rect.fromCircle(center: center, radius: 45));
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: center.translate(18, -10),
          radius: 43,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, cut),
      Paint()..color = const Color(0xFFF0ECFF).withValues(alpha: .95),
    );
  }

  void _stars(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .62);
    const points = [
      [.56, .12],
      [.63, .20],
      [.72, .09],
      [.87, .20],
      [.93, .11],
      [.95, .29],
      [.58, .34],
    ];
    for (final p in points) {
      canvas.drawCircle(
        Offset(size.width * p[0], size.height * p[1]),
        1.6,
        paint,
      );
    }
  }

  void _horizon(Canvas canvas, Size size) {
    final y = size.height - 74;
    final haze = Paint()
      ..color = (dark ? Colors.white : const Color(0xFF9FB8C7))
          .withValues(alpha: dark ? .05 : .12);
    canvas.drawRect(Rect.fromLTWH(0, y, size.width, 18), haze);
    final city = Paint()
      ..color = (dark ? const Color(0xFF111A33) : const Color(0xFF7291A5))
          .withValues(alpha: dark ? .18 : .22);
    var x = size.width * .68;
    final widths = [5.0, 8.0, 4.0, 10.0, 6.0, 5.0, 9.0, 4.0, 7.0];
    for (var i = 0; i < widths.length; i++) {
      final h = 12.0 + (i % 4) * 7;
      canvas.drawRect(
        Rect.fromLTWH(x, y - h, widths[i], h),
        city,
      );
      x += widths[i] + 3;
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherHeroPainter oldDelegate) =>
      oldDelegate.condition != condition ||
      oldDelegate.lime != lime ||
      oldDelegate.purple != purple;
}
