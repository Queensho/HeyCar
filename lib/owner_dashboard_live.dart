import 'package:flutter/material.dart';
import 'main.dart' as app;
import 'owner_notifications_page.dart';

class OwnerDashboardLive extends StatefulWidget {
  const OwnerDashboardLive({super.key});
  @override
  State<OwnerDashboardLive> createState() => _OwnerDashboardLiveState();
}

class _OwnerDashboardLiveState extends State<OwnerDashboardLive> {
  int current = 0;

  @override
  Widget build(BuildContext context) {
    const screens = <Widget>[
      app.HomePage(),
      OwnerNotificationsPage(),
      app.HistoryPage(),
      app.SettingsPage(),
    ];
    const labels = ['Ana Sayfa', 'Bildirimler', 'Geçmiş', 'Ayarlar'];
    const icons = [Icons.home_rounded, Icons.notifications_none_rounded, Icons.schedule_rounded, Icons.settings_outlined];
    return Scaffold(
      body: IndexedStack(index: current, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: (value) => setState(() => current = value),
        destinations: List.generate(4, (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i])),
      ),
    );
  }
}
