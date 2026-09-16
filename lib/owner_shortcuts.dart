import 'package:flutter/material.dart';

class OwnerShortcutDefinition {
  const OwnerShortcutDefinition({required this.id,required this.title,required this.subtitle,required this.icon,required this.action});
  final String id,title,subtitle,action;
  final IconData icon;
}

/// Add future shortcuts here only. Existing user selections keep working by id.
const ownerShortcutCatalog=<OwnerShortcutDefinition>[
  OwnerShortcutDefinition(id:'qr',title:'QR Kodum',subtitle:'İndir / Paylaş',icon:Icons.qr_code_scanner_rounded,action:'qr'),
  OwnerShortcutDefinition(id:'vehicle',title:'Araç Bilgilerim',subtitle:'Düzenle',icon:Icons.directions_car_filled_rounded,action:'vehicles'),
  OwnerShortcutDefinition(id:'parking',title:'Park Yerim',subtitle:'Kaydet / Gör',icon:Icons.local_parking_rounded,action:'parking'),
  OwnerShortcutDefinition(id:'notifications',title:'Bildirimler',subtitle:'Tümünü Gör',icon:Icons.notifications_rounded,action:'notifications'),
  OwnerShortcutDefinition(id:'maintenance',title:'Bakım Geçmişi',subtitle:'Servis kayıtları',icon:Icons.build_rounded,action:'maintenance'),
  OwnerShortcutDefinition(id:'inspection',title:'Muayene',subtitle:'Tarih ve hatırlatma',icon:Icons.fact_check_rounded,action:'reminders'),
  OwnerShortcutDefinition(id:'insurance',title:'Sigorta / Kasko',subtitle:'Poliçe bilgileri',icon:Icons.verified_user_rounded,action:'reminders'),
  OwnerShortcutDefinition(id:'drivers',title:'Sürücüler',subtitle:'Yetkili sürücüler',icon:Icons.group_rounded,action:'vehicles'),
  OwnerShortcutDefinition(id:'settings',title:'Ayarlar',subtitle:'Uygulama ayarları',icon:Icons.settings_rounded,action:'settings'),
];

const defaultOwnerShortcutIds=['qr','vehicle'];
const maxOwnerShortcuts=4;
