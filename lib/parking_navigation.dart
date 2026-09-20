import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> navigateToParking(
  double latitude,
  double longitude,
  String name,
) async {
  final destinations = <Uri>[
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
      Uri.parse('https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d'),
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
      Uri.parse('google.navigation:q=$latitude,$longitude&mode=d'),
      Uri.parse(
        'geo:$latitude,$longitude?q=$latitude,$longitude(${Uri.encodeComponent(name)})',
      ),
    ],
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
    ),
  ];
  for (final uri in destinations) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication))
        return true;
    } catch (_) {}
  }
  return false;
}
