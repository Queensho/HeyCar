import 'package:flutter/material.dart';

/// Calendar dialog shared by standard and custom vehicle reminders.
Future<DateTime?> showVehicleReminderCalendar(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final now = DateTime.now();
  return showDialog<DateTime>(
    context: context,
    barrierColor: const Color(0x990B1026),
    builder: (_) => _ReminderCalendarDialog(
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(now.year - 2),
      lastDate: lastDate ?? DateTime(now.year + 10),
    ),
  );
}

class _ReminderCalendarDialog extends StatefulWidget {
  const _ReminderCalendarDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });
  final DateTime initialDate, firstDate, lastDate;

  @override
  State<_ReminderCalendarDialog> createState() => _ReminderCalendarDialogState();
}

class _ReminderCalendarDialogState extends State<_ReminderCalendarDialog> {
  static const purple = Color(0xFF5425D9);
  static const ink = Color(0xFF11182E);
  static const muted = Color(0xFF7C8199);
  static const months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const dayNames = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
  ];
  late DateTime selected;
  late DateTime displayed;

  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  bool within(DateTime d) =>
      !day(d).isBefore(day(widget.firstDate)) &&
      !day(d).isAfter(day(widget.lastDate));

  @override
  void initState() {
    super.initState();
    final proposed = day(widget.initialDate);
    selected = proposed.isBefore(day(widget.firstDate))
        ? day(widget.firstDate)
        : proposed.isAfter(day(widget.lastDate))
            ? day(widget.lastDate)
            : proposed;
    displayed = DateTime(selected.year, selected.month);
  }

  void changeMonth(int offset) {
    final next = DateTime(displayed.year, displayed.month + offset);
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (next.isBefore(firstMonth) || next.isAfter(lastMonth)) return;
    setState(() => displayed = next);
  }

  Future<void> chooseYear() async {
    final year = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yıl seçin'),
        content: SizedBox(
          width: 260,
          height: 280,
          child: ListView.builder(
            itemCount: widget.lastDate.year - widget.firstDate.year + 1,
            itemBuilder: (_, i) {
              final year = widget.firstDate.year + i;
              return ListTile(
                title: Text('$year'),
                selected: year == displayed.year,
                onTap: () => Navigator.pop(ctx, year),
              );
            },
          ),
        ),
      ),
    );
    if (year == null || !mounted) return;
    final candidate = DateTime(year, displayed.month);
    final lower = DateTime(widget.firstDate.year, widget.firstDate.month);
    final upper = DateTime(widget.lastDate.year, widget.lastDate.month);
    setState(() => displayed = candidate.isBefore(lower)
        ? lower
        : candidate.isAfter(upper) ? upper : candidate);
  }

  Widget roundedIcon(IconData icon, VoidCallback? action) => Material(
    color: const Color(0xFFF0ECFF),
    borderRadius: BorderRadius.circular(16),
    child: IconButton(
      onPressed: action,
      icon: Icon(icon, color: purple),
      iconSize: 25,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final today = day(DateTime.now());
    final daysInMonth = DateTime(displayed.year, displayed.month + 1, 0).day;
    final start = displayed.weekday - 1;
    final count = ((start + daysInMonth + 6) ~/ 7) * 7;
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      backgroundColor: const Color(0xFFFCFBFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 42, height: 5,
              decoration: BoxDecoration(color: const Color(0xFFD5D1E2),
                borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: const Color(0xFFF0ECFF),
                  borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.event_outlined, color: purple, size: 30)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tarih Seçin', style: TextStyle(
                    color: ink, fontSize: 23, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Hatırlatma tarihi belirleyin.',
                    style: TextStyle(color: muted, fontSize: 13)),
                ])),
              roundedIcon(Icons.close_rounded, () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0ECFF),
                borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                Text('${selected.day}', style: const TextStyle(
                  color: purple, fontSize: 48, fontWeight: FontWeight.w900)),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${months[selected.month - 1].toUpperCase()} ${selected.year}',
                      style: const TextStyle(color: ink,
                        fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(dayNames[selected.weekday - 1],
                      style: const TextStyle(color: muted, fontSize: 15)),
                  ])),
                roundedIcon(Icons.edit_outlined, chooseYear),
              ]),
            ),
            const SizedBox(height: 18),
            Row(children: [
              roundedIcon(Icons.chevron_left_rounded,
                displayed.isAfter(firstMonth) ? () => changeMonth(-1) : null),
              Expanded(child: TextButton.icon(
                onPressed: chooseYear,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ink),
                label: Text('${months[displayed.month - 1]} ${displayed.year}',
                  style: const TextStyle(color: ink, fontSize: 18,
                    fontWeight: FontWeight.w800)),
              )),
              roundedIcon(Icons.chevron_right_rounded,
                displayed.isBefore(lastMonth) ? () => changeMonth(1) : null),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              for (final label in weekdays)
                Expanded(child: Center(child: Text(label,
                  style: const TextStyle(color: muted, fontSize: 12)))),
            ]),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: count,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisSpacing: 4,
                crossAxisSpacing: 3, childAspectRatio: 0.95),
              itemBuilder: (_, index) {
                final number = index - start + 1;
                if (number < 1 || number > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final value = DateTime(displayed.year, displayed.month, number);
                final active = day(value) == selected;
                final isToday = day(value) == today;
                final enabled = within(value);
                return InkWell(
                  key: Key('reminder_calendar_day_$number'),
                  onTap: enabled ? () => setState(() => selected = value) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? purple : isToday
                        ? const Color(0xFFEAFBE8) : Colors.transparent,
                      border: isToday && !active
                        ? Border.all(color: const Color(0xFF95DB25), width: 1.5)
                        : null,
                      borderRadius: BorderRadius.circular(12)),
                    child: Text('$number', style: TextStyle(
                      color: !enabled ? const Color(0xFFC4C4CE)
                        : active ? Colors.white
                        : isToday ? const Color(0xFF16834A) : ink,
                      fontSize: 15,
                      fontWeight: active || isToday
                        ? FontWeight.w800 : FontWeight.w500)),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: SizedBox(height: 49, child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0ECFF),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
                child: const Text('İptal', style: TextStyle(
                  color: purple, fontWeight: FontWeight.w800)),
              ))),
              const SizedBox(width: 10),
              Expanded(child: SizedBox(height: 49, child: FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
                child: const Text('Tarihi Kaydet',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              ))),
            ]),
          ]),
        ),
      ),
    );
  }
}
