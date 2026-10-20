import 'package:flutter/material.dart';

class MaintenanceV2Page extends StatelessWidget {
  const MaintenanceV2Page({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Araç Giderleri')),
    body: const Center(child: Text('Yakıt ve masraf takibi')),
  );
}
