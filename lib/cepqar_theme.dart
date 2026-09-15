import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CepqarTheme {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  static bool get isLight => mode.value == ThemeMode.light;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = (prefs.getBool('cepqar_light_theme') ?? false)
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  static Future<void> toggle() async {
    mode.value = isLight ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cepqar_light_theme', isLight);
  }

  static const purple = Color(0xFF713BFF);
  static const darkBg = Color(0xFF07111F);
  static const darkPanel = Color(0xFF101A30);
  static const darkLine = Color(0xFF27355D);
  static const darkMuted = Color(0xFFA7B0C7);
  static const lightBg = Color(0xFFF7F8FC);
  static const lightPanel = Colors.white;
  static const lightLine = Color(0xFFE7E9F2);
  static const lightText = Color(0xFF0B1530);
  static const lightMuted = Color(0xFF6E7890);

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
        return InkWell(
          onTap: CepqarTheme.toggle,
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: 64,
            height: 36,
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
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
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
                      duration: const Duration(milliseconds: 250),
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
