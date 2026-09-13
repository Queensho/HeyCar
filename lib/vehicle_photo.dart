import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VehiclePhoto extends StatefulWidget {
  const VehiclePhoto({
    super.key,
    required this.make,
    required this.model,
    this.width = 110,
    this.height = 72,
    this.borderRadius = 14,
  });

  final String make;
  final String model;
  final double width;
  final double height;
  final double borderRadius;

  @override
  State<VehiclePhoto> createState() => _VehiclePhotoState();
}

class _VehiclePhotoState extends State<VehiclePhoto> {
  static final Map<String, String?> _cache = <String, String?>{};
  String? _url;
  bool _loading = false;

  String get _key => '${widget.make.trim()}|${widget.model.trim()}'.toLowerCase();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VehiclePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.make != widget.make || oldWidget.model != widget.model) {
      _load();
    }
  }

  Future<void> _load() async {
    final make = widget.make.trim();
    final model = widget.model.trim();
    if (make.isEmpty || model.isEmpty || make == 'Diğer') {
      if (mounted) setState(() { _url = null; _loading = false; });
      return;
    }

    if (_cache.containsKey(_key)) {
      if (mounted) setState(() { _url = _cache[_key]; _loading = false; });
      return;
    }

    if (mounted) setState(() { _loading = true; _url = null; });

    try {
      final query = Uri.encodeQueryComponent('$make $model automobile');
      final uri = Uri.parse(
        'https://commons.wikimedia.org/w/api.php'
        '?action=query&generator=search&gsrsearch=$query&gsrnamespace=6&gsrlimit=8'
        '&prop=imageinfo&iiprop=url&iiurlwidth=500&format=json&origin=*',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final decoded = jsonDecode(response.body);
      String? found;
      if (decoded is Map<String, dynamic>) {
        final queryMap = decoded['query'];
        if (queryMap is Map<String, dynamic>) {
          final pages = queryMap['pages'];
          if (pages is Map<String, dynamic>) {
            for (final value in pages.values) {
              if (value is! Map<String, dynamic>) continue;
              final title = (value['title'] ?? '').toString().toLowerCase();
              if (title.contains('logo') || title.contains('badge') || title.contains('interior')) continue;
              final infos = value['imageinfo'];
              if (infos is List && infos.isNotEmpty && infos.first is Map<String, dynamic>) {
                final info = infos.first as Map<String, dynamic>;
                final candidate = (info['thumburl'] ?? info['url'])?.toString();
                if (candidate != null && candidate.isNotEmpty) {
                  found = candidate;
                  break;
                }
              }
            }
          }
        }
      }
      _cache[_key] = found;
      if (mounted) setState(() { _url = found; _loading = false; });
    } catch (_) {
      _cache[_key] = null;
      if (mounted) setState(() { _url = null; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFFF3F5F8),
        alignment: Alignment.center,
        child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : _url == null
                ? const Icon(Icons.directions_car_filled_rounded, color: Color(0xFFFCA311), size: 34)
                : Image.network(
                    _url!,
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.directions_car_filled_rounded,
                      color: Color(0xFFFCA311),
                      size: 34,
                    ),
                  ),
      ),
    );
  }
}
