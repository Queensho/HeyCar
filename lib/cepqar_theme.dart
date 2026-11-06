import 'design/cq_motion.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CepqarTheme {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static bool get isLight => mode.value == ThemeMode.light;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = (prefs.getBool('cepqar_light_theme') ?? true)
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  static Future<void> setDarkMode(bool enabled) async {
    mode.value = enabled ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cepqar_light_theme', !enabled);
  }

  static Future<void> toggle() async {
    await setDarkMode(isLight);
  }

  static const purple = Color(0xFF651FFF);
  static const lime = Color(0xFFB9FF45);
  static const deepPurple = Color(0xFF4912C8);
  static const purpleTint = Color(0xFFF3EDFF);
  static const brightPurple = Color(0xFF713BFF);
  static const darkBg = Color(0xFF07111F);
  static const darkPanel = Color(0xFF101A30);
  static const darkLine = Color(0xFF27355D);
  static const darkMuted = Color(0xFFA7B0C7);
  static const lightBg = Color(0xFFF7F8FC);
  static const lightPanel = Colors.white;
  static const lightLine = Color(0xFFE7E9F2);
  static const lightText = Color(0xFF0B1530);
  static const lightMuted = Color(0xFF626C83);

  // Shared owner-app sizing scale. Keep authenticated screens visually consistent.
  static const double pageTitle = 25;
  static const double sectionTitle = 18;
  static const double cardTitle = 13;
  static const double body = 12;
  static const double bodySmall = 11;
  static const double caption = 10.5;
  static const double buttonText = 12.5;
  static const double navText = 10.5;

  static Color get bg => isLight ? lightBg : darkBg;
  static Color get panel => isLight ? lightPanel : darkPanel;
  static Color get line => isLight ? lightLine : darkLine;
  static Color get text => isLight ? lightText : Colors.white;
  static Color get muted => isLight ? lightMuted : darkMuted;
}

class CepqarThemeSwitch extends StatelessWidget {
  const CepqarThemeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: CepqarTheme.mode,
      builder: (_, mode, __) {
        final light = mode == ThemeMode.light;
        return CQPressable(
          semanticLabel: light ? 'Koyu temaya geç' : 'Açık temaya geç',
          onTap: CepqarTheme.toggle,
          borderRadius: 30,
          child: AnimatedContainer(
            duration: CQMotion.duration(context, CQMotion.feedback),
            curve: Curves.easeOutCubic,
            width: 64,
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: light ? const Color(0xFFF0E9FF) : const Color(0xFF17223A),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: light ? const Color(0xFFD7C7FF) : const Color(0xFF34415E),
              ),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: CQMotion.duration(context, CQMotion.feedback),
                  curve: CQMotion.standard,
                  alignment: light ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: light ? Colors.white : const Color(0xFF27344F),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .12),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: CQMotion.duration(context, CQMotion.feedback),
                      transitionBuilder: (child, animation) => RotationTransition(
                        turns: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: Icon(
                        light ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        key: ValueKey(light),
                        size: 17,
                        color: light ? const Color(0xFFFFB300) : const Color(0xFFB7C4FF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

