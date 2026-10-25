import 'package:flutter/material.dart';
import 'app_environment.dart';

Widget environmentBanner(BuildContext context, Widget? child) {
  if (!AppEnvironment.isStaging) return child ?? const SizedBox.shrink();
  return Column(children: [
    SafeArea(bottom: false, child: Container(width: double.infinity, color: const Color(0xFFB9FF45), padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12), child: const Text('STAGING / TEST ORTAMI', textAlign: TextAlign.center, style: TextStyle(inherit: false, fontFamily: 'Roboto', decoration: TextDecoration.none, height: 1.2, color: Color(0xFF10152D), fontSize: 13, fontWeight: FontWeight.w800)))),
    Expanded(child: child ?? const SizedBox.shrink()),
  ]);
}
