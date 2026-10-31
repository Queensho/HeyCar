# 119 / 123 migration farkı — tam dosya adları

Bu karşılaştırma main `61b3206c0686d630c7293a6b6af3e8fedaf44ddc` ile staging deploy workflow'ünün
seçtiği kaynak commit `4238d9a4ea1a1a39edc2884d0f44d699dba4b7a2` arasında yapılmıştır.
VPS'e erişim olmadığından uzaktaki dosya listesinin bu kaynakla aynı olduğu iddia edilmez.
Özellikle rsync eski dosyaları silmediğinden VPS'te ayrıca tam filename/SHA-256 manifest'i alınmalıdır.

- main: **119 SQL**
- staging kaynak: **123 SQL**
- İkisinde de bulunan: **118 dosya**, hepsinin SHA-256 içeriği aynı.
- Ortak isimli fakat checksum'ı farklı dosya: **0**.
- Denklem: **119 − 1 + 5 = 123**. Fark dört eksik migration demek değildir.

## Yalnız staging kaynağında bulunan beş dosya

| Tam dosya adı | SHA-256 |
|---|---|
| `123_marketplace_services.sql` | `26ba621b1d91b43df17c1ac8837ecc7f11d35f5fd226d98281093f2227a4ff05` |
| `124_marketplace_weekly_hours.sql` | `b6f27b7987f9b01b5e899b51c5879948b979c4ad1dc3f40d8e6cece953bd44a8` |
| `125_marketplace_reviews.sql` | `f05d0ff57408859430435df69670e8b659f1bf0e2ad009b101246e384cf8dcd7` |
| `126_marketplace_service_images.sql` | `3de5052b1c05d44806bd2e0931d639e3ba561082d954e854266bb11455545f2d` |
| `127_marketplace_moderation.sql` | `8660a170098842037a93952b973bb4df5fb8ede473cc31b7b79fb476946bb299` |

## Yalnız main içinde bulunan dosya

| Tam dosya adı | SHA-256 |
|---|---|
| `123_vehicle_custom_reminders.sql` | `f354d58fcd93fa035324053689e725daefeadc9407e0543b5d1a5cd515eb6be2` |

`123_marketplace_services.sql` ile `123_vehicle_custom_reminders.sql` farklı dosyalardır.
Birini diğerinin yerine uygulanmış saymak veya sadece 123 numarasını kaydetmek yanlıştır.

## Her iki kaynakta da aynı prefix'i paylaşan dosyalar

- `014_maintenance_shares.sql`, `014_vehicle_reminders.sql`
- `015_vehicle_parking_locations.sql`, `015_vehicle_reminder_deliveries.sql`
- `036_admin_audit_log.sql`, `036_admin_audit_logs.sql`
- `041_fix_vehicle_reminder_ownership.sql`, `041_support_tickets.sql`
- `053_admin_audit_canonical.sql`, `053_vehicle_relation_fk_hardening.sql`

Bu dosyaların her biri bağımsız migration kimliğidir ve ayrı checksum ile takip edilir.
`080_towing_messages.sql` iki kaynakta da vardır; dökümde tablosunun eksik olması
branch farkıyla açıklanmaz. `101_anonymous_call_atomic_rate_limit.sql` dosyasının geçici
sayacı `102_anonymous_call_rolling_rate_limit.sql` tarafından kaldırılmıştır.

Bütün 242 kaynak/dosya kaydı ve checksum'ları `migration-inventory.csv` içindedir.
Bu envanter veya yapısal eşleşme tek başına baseline yetkisi vermez.
