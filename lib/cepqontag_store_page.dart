import 'dart:convert';

import 'package:flutter/material.dart';

import 'cepqar_theme.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';

class CepqontagStorePage extends StatefulWidget {
  const CepqontagStorePage({super.key});

  @override
  State<CepqontagStorePage> createState() => _CepqontagStorePageState();
}

class _CepqontagStorePageState extends State<CepqontagStorePage> {
  static const _purple = Color(0xFF713BFF);
  static const _lime = Color(0xFFB6FF2A);

  static const List<_StoreProduct> _fallbackProducts = [
    _StoreProduct(
      id: 'vehicle_qr',
      sku: 'CQ-VEHICLE-QR',
      title: 'CepQontag Araç Etiketi',
      subtitle: 'Anonim mesaj ve arama için QR araç etiketi.',
      category: 'Etiketler',
      price: 299.90,
      asset: 'assets/Etiket4.png',
      badge: 'En çok tercih',
      features: [
        'Araç sahibine anonim mesaj',
        'Anonim arama',
        'QR güvenliği ve etiket analitiği',
        'Araca özel tekil etiket kodu',
      ],
    ),
    _StoreProduct(
      id: 'second_vehicle_qr',
      sku: 'CQ-EXTRA-QR',
      title: 'Ek Araç Etiketi',
      subtitle: 'İkinci aracınız veya yedek kullanım için.',
      category: 'Etiketler',
      price: 299.90,
      asset: 'assets/Etiket3.png',
      features: [
        'Yeni veya ikinci araca bağlanabilir',
        'Aynı CepQontag hesabından yönetilir',
        'Araç bazında ayrı QR güvenliği',
      ],
    ),
    _StoreProduct(
      id: 'nfc_qr',
      sku: 'CQ-NFC-QR',
      title: 'NFC + QR Akıllı Etiket',
      subtitle: 'Telefonu yaklaştır veya QR kodu okut.',
      category: 'Yakında',
      asset: 'assets/Etiket4.png',
      comingSoon: true,
      badge: 'Yakında',
      features: [
        'NFC ile tek dokunuşta açılış',
        'QR ile yedek erişim',
        'Tek araç sayfasında birleşik analitik',
      ],
    ),
    _StoreProduct(
      id: 'motorcycle',
      sku: 'CQ-MOTORCYCLE',
      title: 'Motosiklet Etiketi',
      subtitle: 'Motosiklet ve scooter için kompakt CepQontag.',
      category: 'Yakında',
      asset: 'assets/Etiket.png',
      comingSoon: true,
      badge: 'Yakında',
      features: [
        'Kompakt motosiklet etiketi',
        'Anonim araç sahibi iletişimi',
        'Acil durum modülüne hazır',
      ],
    ),
  ];

  List<_StoreProduct> products = List<_StoreProduct>.from(_fallbackProducts);
  bool loadingProducts = true;
  Map<String,dynamic> storeConfig={};

  final List<_CartLine> cart = [];
  List<_StoreVehicle> vehicles = [];
  bool loadingVehicles = true;
  String category = 'Tümü';

  Color get bg => CepqarTheme.bg;
  Color get panel => CepqarTheme.panel;
  Color get line => CepqarTheme.line;
  Color get text => CepqarTheme.text;
  Color get muted => CepqarTheme.muted;

  @override
  void initState() {
    super.initState();
    _loadStoreConfig();
    _loadProducts();
    _loadVehicles();
  }

  Future<void> _loadStoreConfig() async {
    try {
      final r=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/store/config'),json:false).timeout(const Duration(seconds:12));
      final d=r.body.isEmpty?<String,dynamic>{}:jsonDecode(r.body);
      if(r.statusCode==200&&d is Map&&d['config'] is Map){storeConfig=Map<String,dynamic>.from(d['config'] as Map);}
    } catch (_) {}
    if(mounted)setState((){});
  }

  Future<void> _loadProducts() async {
    try {
      final r = await OwnerHttp.get(
        Uri.parse('${OnboardingBackend.baseUrl}/api/store/products'),
        json: false,
      ).timeout(const Duration(seconds: 12));
      final d = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode == 200 && d is Map && d['items'] is List) {
        final next = (d['items'] as List)
            .whereType<Map>()
            .map((x) => _StoreProduct.fromJson(Map<String, dynamic>.from(x)))
            .where((x) => x.id.isNotEmpty && x.title.isNotEmpty)
            .toList();
        if (next.isNotEmpty) products = next;
      }
    } catch (_) {}
    if (mounted) setState(() => loadingProducts = false);
  }

  Future<void> _loadVehicles() async {
    try {
      final r = await OwnerHttp.get(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),
        json: false,
      ).timeout(const Duration(seconds: 12));
      final d = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode == 200 && d is Map && d['vehicles'] is List) {
        vehicles = (d['vehicles'] as List)
            .whereType<Map>()
            .map((v) => _StoreVehicle(
                  id: '${v['id'] ?? ''}',
                  plate: '${v['plate'] ?? ''}',
                  title: '${v['make'] ?? ''} ${v['model'] ?? ''}'.trim(),
                ))
            .where((v) => v.id.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => loadingVehicles = false);
  }

  int get cartCount => cart.fold(0, (sum, x) => sum + x.quantity);
  double get cartTotal =>
      cart.fold(0, (sum, x) => sum + (x.product.price ?? 0) * x.quantity);

  List<_StoreProduct> get visibleProducts {
    if (category == 'Tümü') return products;
    if (category == 'Yakında') {
      return products.where((x) => x.comingSoon).toList();
    }
    return products.where((x) => x.category == category).toList();
  }

  String _money(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} TL';

  void _openProduct(_StoreProduct product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductDetailSheet(
        product: product,
        vehicles: vehicles,
        loadingVehicles: loadingVehicles,
        onAdd: (vehicle) {
          Navigator.pop(context);
          _addToCart(product, vehicle);
        },
      ),
    );
  }

  void _addToCart(_StoreProduct product, _StoreVehicle? vehicle) {
    if (product.comingSoon || product.price == null) return;
    final vehicleId = vehicle?.id ?? '';
    final index = cart.indexWhere(
      (x) => x.product.id == product.id && x.vehicle?.id == vehicleId,
    );
    setState(() {
      if (index >= 0) {
        cart[index] = cart[index].copyWith(quantity: cart[index].quantity + 1);
      } else {
        cart.add(_CartLine(product: product, vehicle: vehicle));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.title} sepete eklendi.'),
        action: SnackBarAction(label: 'Sepet', onPressed: _openCart),
      ),
    );
  }

  void _changeQty(int index, int delta) {
    setState(() {
      final next = cart[index].quantity + delta;
      if (next <= 0) {
        cart.removeAt(index);
      } else {
        cart[index] = cart[index].copyWith(quantity: next);
      }
    });
  }

  void _openCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => _CartSheet(
          cart: cart,
          total: cartTotal,
          money: _money,
          onQty: (index, delta) {
            _changeQty(index, delta);
            setSheetState(() {});
          },
          onCheckout: cart.isEmpty
              ? null
              : () {
                  Navigator.pop(sheetContext);
                  _openCheckout();
                },
        ),
      ),
    );
  }

  void _openCheckout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreCheckoutPage(
          lines: List<_CartLine>.from(cart),
          total: cartTotal,
        ),
      ),
    );
  }

  Widget _hero() => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        height: 166,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E1020), Color(0xFF351281), Color(0xFF713BFF)],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: -12,
              bottom: -8,
              child: Opacity(
                opacity: .42,
                child: Image.asset(
                  'assets/Etiket4.png',
                  width: 170,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 17,
              right: 148,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _lime,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      'CEPQONTAG MAĞAZA',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (storeConfig['heroTitle']??'Aracın için hazır.').toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: .95,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    (storeConfig['heroBody']??'Yeni araç, yedek etiket ve gelecek akıllı ürünler tek yerde.').toString(),
                    maxLines: 2,
                    style: TextStyle(
                      color: Color(0xFFD7D0EA),
                      fontSize: 10.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _categoryChip(String value) {
    final selected = category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        onTap: () => setState(() => category = value),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _purple : panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _purple : line),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: selected ? Colors.white : muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _productCard(_StoreProduct p) => InkWell(
        onTap: () => _openProduct(p),
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: line),
            boxShadow: CepqarTheme.isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .035),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: _storeProductImage(
                            p,
                            fit: BoxFit.contain,
                            fallbackSize: 54,
                          ),
                        ),
                      ),
                      if (p.badge != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: p.comingSoon ? _purple : _lime,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              p.badge!,
                              style: TextStyle(
                                color: p.comingSoon
                                    ? Colors.white
                                    : Colors.black,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                p.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontSize: 9.5,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.comingSoon
                          ? 'Yakında'
                          : p.soldOut
                              ? 'Stokta yok'
                              : _money(p.price ?? 0),
                      style: TextStyle(
                        color: p.comingSoon ? _purple : text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: _purple.withValues(alpha: .10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      p.comingSoon
                          ? Icons.schedule_rounded
                          : Icons.add_shopping_cart_rounded,
                      color: _purple,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final list = visibleProducts;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        title: Text(
          (storeConfig['storeTitle']??'Mağaza').toString(),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: _openCart,
                icon: const Icon(Icons.shopping_bag_outlined),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 5,
                  top: 4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF405D),
                      borderRadius: BorderRadius.all(Radius.circular(9)),
                    ),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if(storeConfig['showHero']!=false) _hero(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ürünler',
                    style: TextStyle(
                      color: text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${products.where((x) => !x.comingSoon).length} satışta',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 38,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _categoryChip('Tümü'),
                _categoryChip('Etiketler'),
                _categoryChip('Yakında'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              itemCount: list.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .72,
              ),
              itemBuilder: (_, i) => _productCard(list[i]),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: _purple.withValues(alpha: .16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: _purple.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        const Icon(Icons.sync_rounded, color: _purple, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Etiketi kaybedersen veya yeni araç eklersen mağazadan yeni etiketi doğrudan aracına bağlayabileceksin.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDetailSheet extends StatefulWidget {
  const _ProductDetailSheet({
    required this.product,
    required this.vehicles,
    required this.loadingVehicles,
    required this.onAdd,
  });

  final _StoreProduct product;
  final List<_StoreVehicle> vehicles;
  final bool loadingVehicles;
  final ValueChanged<_StoreVehicle?> onAdd;

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  _StoreVehicle? selected;

  @override
  void initState() {
    super.initState();
    if (widget.vehicles.isNotEmpty) selected = widget.vehicles.first;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final bg = CepqarTheme.bg;
    final panel = CepqarTheme.panel;
    final line = CepqarTheme.line;
    final text = CepqarTheme.text;
    final muted = CepqarTheme.muted;

    return SafeArea(
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 190,
              decoration: BoxDecoration(
                color: const Color(0xFF713BFF).withValues(alpha: .06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _storeProductImage(
                  p,
                  fit: BoxFit.contain,
                  fallbackSize: 80,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    p.title,
                    style: TextStyle(
                      color: text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  p.comingSoon
                      ? 'Yakında'
                      : '${p.price!.toStringAsFixed(2).replaceAll('.', ',')} TL',
                  style: const TextStyle(
                    color: Color(0xFF713BFF),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              p.subtitle,
              style: TextStyle(color: muted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: line),
              ),
              child: Column(
                children: p.features
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF23C976),
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f,
                                style: TextStyle(
                                  color: text,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (!p.comingSoon) ...[
              const SizedBox(height: 17),
              Text(
                'Hangi araç için?',
                style: TextStyle(
                  color: text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.loadingVehicles)
                const Center(child: CircularProgressIndicator())
              else if (widget.vehicles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: line),
                  ),
                  child: Text(
                    'Hesabında araç bulunamadı. Etiketi aldıktan sonra da araca bağlayabilirsin.',
                    style: TextStyle(color: muted, fontSize: 10.5, height: 1.35),
                  ),
                )
              else
                ...widget.vehicles.map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: InkWell(
                      onTap: () => setState(() => selected = v),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: panel,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected?.id == v.id
                                ? const Color(0xFF713BFF)
                                : line,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.directions_car_filled_rounded,
                              color: Color(0xFF713BFF),
                              size: 20,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.plate.isEmpty ? 'Araç' : v.plate,
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (v.title.isNotEmpty)
                                    Text(
                                      v.title,
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Radio<String>(
                              value: v.id,
                              groupValue: selected?.id,
                              onChanged: (_) => setState(() => selected = v),
                              activeColor: const Color(0xFF713BFF),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 49,
                child: FilledButton.icon(
                  onPressed: p.soldOut ? null : () => widget.onAdd(selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF713BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(
                    p.soldOut ? 'Stokta Yok' : 'Sepete Ekle',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF713BFF).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: Color(0xFF713BFF)),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Bu ürün henüz satışta değil. Hazır olduğunda mağazada aktif hale gelecek.',
                        style: TextStyle(
                          color: Color(0xFF713BFF),
                          fontSize: 10.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartSheet extends StatelessWidget {
  const _CartSheet({
    required this.cart,
    required this.total,
    required this.money,
    required this.onQty,
    required this.onCheckout,
  });

  final List<_CartLine> cart;
  final double total;
  final String Function(double) money;
  final void Function(int index, int delta) onQty;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final bg = CepqarTheme.bg;
    final panel = CepqarTheme.panel;
    final line = CepqarTheme.line;
    final text = CepqarTheme.text;
    final muted = CepqarTheme.muted;

    return SafeArea(
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .82),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sepetim',
                      style: TextStyle(
                        color: text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: cart.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              color: muted,
                              size: 48,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sepetin henüz boş.',
                              style: TextStyle(
                                color: text,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(18, 5, 18, 10),
                      itemCount: cart.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final x = cart[i];
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: panel,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: line),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF713BFF)
                                      .withValues(alpha: .06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _storeProductImage(
                                  x.product,
                                  fit: BoxFit.contain,
                                  fallbackSize: 34,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      x.product.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: text,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      x.vehicle == null
                                          ? 'Araç daha sonra seçilebilir'
                                          : '${x.vehicle!.plate} • ${x.vehicle!.title}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      money((x.product.price ?? 0) * x.quantity),
                                      style: TextStyle(
                                        color: text,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => onQty(i, -1),
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  Text(
                                    '${x.quantity}',
                                    style: TextStyle(
                                      color: text,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => onQty(i, 1),
                                    icon: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (cart.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Toplam',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          money(total),
                          style: TextStyle(
                            color: text,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 49,
                      child: FilledButton(
                        onPressed: onCheckout,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF713BFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Siparişe Devam Et',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class StoreCheckoutPage extends StatefulWidget {
  const StoreCheckoutPage({
    super.key,
    required this.lines,
    required this.total,
  });

  final List<_CartLine> lines;
  final double total;

  @override
  State<StoreCheckoutPage> createState() => _StoreCheckoutPageState();
}

class _StoreCheckoutPageState extends State<StoreCheckoutPage> {
  int step = 0;
  bool creatingOrder = false;
  Map<String, dynamic>? createdOrder;
  final name = TextEditingController(text: OnboardingDraft.displayName);
  final phone = TextEditingController(text: OnboardingDraft.phone);
  final address = TextEditingController();
  final district = TextEditingController();
  final city = TextEditingController(text: 'İstanbul');
  final note = TextEditingController();

  Color get bg => CepqarTheme.bg;
  Color get panel => CepqarTheme.panel;
  Color get line => CepqarTheme.line;
  Color get text => CepqarTheme.text;
  Color get muted => CepqarTheme.muted;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    district.dispose();
    city.dispose();
    note.dispose();
    super.dispose();
  }

  String _money(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} TL';

  bool _deliveryValid() =>
      name.text.trim().length >= 2 &&
      phone.text.replaceAll(RegExp(r'\D'), '').length >= 10 &&
      address.text.trim().length >= 8 &&
      district.text.trim().isNotEmpty &&
      city.text.trim().isNotEmpty;

  Future<void> _next() async {
    if (step == 0) {
      if (!_deliveryValid()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teslimat bilgilerini eksiksiz doldurun.')),
        );
        return;
      }
      setState(() => step = 1);
      return;
    }

    if (step == 1) {
      if (createdOrder != null) {
        setState(() => step = 2);
        return;
      }
      if (creatingOrder) return;
      setState(() => creatingOrder = true);
      try {
        final response = await OwnerHttp.post(
          Uri.parse('${OnboardingBackend.baseUrl}/api/owner/store/orders'),
          body: jsonEncode({
            'deliveryName': name.text.trim(),
            'deliveryPhone': phone.text.trim(),
            'deliveryAddress': address.text.trim(),
            'deliveryDistrict': district.text.trim(),
            'deliveryCity': city.text.trim(),
            'deliveryNote': note.text.trim(),
            'items': widget.lines
                .map((x) => {
                      'productId': x.product.id,
                      if (x.vehicle != null) 'vehicleId': x.vehicle!.id,
                      'quantity': x.quantity,
                    })
                .toList(),
          }),
        ).timeout(const Duration(seconds: 20));
        final d = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            d is! Map) {
          throw Exception(
            d is Map ? (d['error'] ?? 'Sipariş oluşturulamadı.') : 'Sipariş oluşturulamadı.',
          );
        }
        if (!mounted) return;
        setState(() {
          createdOrder = d['order'] is Map
              ? Map<String, dynamic>.from(d['order'] as Map)
              : <String, dynamic>{};
          step = 2;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString()
                    .replaceFirst('Exception: ', '')
                    .replaceAll('PRODUCT_NOT_FOUND', 'Ürün bilgisi güncel değil. Mağazayı yenileyip tekrar deneyin.')
                    .replaceAll('PRODUCT_NOT_FOR_SALE', 'Bu ürün şu anda satışta değil.')
                    .replaceAll('OUT_OF_STOCK', 'Ürün stokta kalmadı.'),
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => creatingOrder = false);
      }
    }
  }

  Widget _indicator(int i, String label) {
    final active = step >= i;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF713BFF)
                  : const Color(0xFF713BFF).withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${i + 1}',
              style: TextStyle(
                color: active ? Colors.white : muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? text : muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboard,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboard,
          style: TextStyle(color: text, fontSize: 12),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: muted, fontSize: 11),
            prefixIcon: Icon(icon, color: const Color(0xFF713BFF), size: 19),
            filled: true,
            fillColor: panel,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF713BFF)),
            ),
          ),
        ),
      );

  Widget _delivery() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teslimat Bilgileri',
            style: TextStyle(
              color: text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Etiketin gönderileceği adresi gir.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          _field(name, 'Ad Soyad', Icons.person_outline_rounded),
          _field(
            phone,
            'Telefon',
            Icons.phone_outlined,
            keyboard: TextInputType.phone,
          ),
          _field(
            address,
            'Açık adres',
            Icons.location_on_outlined,
            maxLines: 2,
          ),
          Row(
            children: [
              Expanded(
                child: _field(
                  district,
                  'İlçe',
                  Icons.map_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(
                  city,
                  'İl',
                  Icons.location_city_outlined,
                ),
              ),
            ],
          ),
          _field(
            note,
            'Teslimat notu (isteğe bağlı)',
            Icons.notes_rounded,
            maxLines: 2,
          ),
        ],
      );

  Widget _summary() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sipariş Özeti',
            style: TextStyle(
              color: text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.lines.map(
            (x) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF713BFF).withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: _storeProductImage(
                      x.product,
                      fit: BoxFit.contain,
                      fallbackSize: 30,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          x.product.title,
                          style: TextStyle(
                            color: text,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          x.vehicle == null
                              ? 'Araç aktivasyonda seçilecek'
                              : '${x.vehicle!.plate} • ${x.vehicle!.title}',
                          style: TextStyle(color: muted, fontSize: 9.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${x.quantity} adet • ${_money((x.product.price ?? 0) * x.quantity)}',
                          style: TextStyle(
                            color: text,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: line),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Ürün toplamı',
                        style: TextStyle(color: muted, fontSize: 11)),
                    const Spacer(),
                    Text(
                      _money(widget.total),
                      style: TextStyle(
                        color: text,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Kargo',
                        style: TextStyle(color: muted, fontSize: 11)),
                    const Spacer(),
                    const Text(
                      'Siparişte hesaplanacak',
                      style: TextStyle(
                        color: Color(0xFF713BFF),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Divider(height: 22, color: line),
                Row(
                  children: [
                    Text(
                      'Toplam',
                      style: TextStyle(
                        color: text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _money(widget.total),
                      style: TextStyle(
                        color: text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Widget _payment() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ödeme',
            style: TextStyle(
              color: text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF713BFF).withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.credit_card_rounded,
                    color: Color(0xFF713BFF),
                    size: 27,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ödeme altyapısı hazırlanıyor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  createdOrder == null
                      ? 'Mağaza akışı hazır. Kartla ödeme entegrasyonu açıldığında bu adım aktif olacak.'
                      : 'Siparişiniz admin paneline kaydedildi. Sipariş no: ${createdOrder!['orderNo'] ?? '-'}. Kartla ödeme entegrasyonu açıldığında buradan tamamlanacak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 10.5, height: 1.4),
                ),
                const SizedBox(height: 13),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF713BFF).withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Yakında',
                    style: TextStyle(
                      color: Color(0xFF713BFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final content = step == 0
        ? _delivery()
        : step == 1
            ? _summary()
            : _payment();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        title: const Text(
          'Sipariş',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
              child: Row(
                children: [
                  _indicator(0, 'Teslimat'),
                  Container(width: 28, height: 1, color: line),
                  _indicator(1, 'Özet'),
                  Container(width: 28, height: 1, color: line),
                  _indicator(2, 'Ödeme'),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                children: [content],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Row(
                children: [
                  if (step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => step--),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: text,
                          side: BorderSide(color: line),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Geri'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: step < 2 && !creatingOrder ? _next : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF713BFF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        creatingOrder
                            ? 'Sipariş oluşturuluyor...'
                            : step == 0
                                ? 'Sipariş Özetine Geç'
                                : step == 1
                                    ? 'Ödemeye Geç'
                                    : 'Ödeme Yakında',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreProduct {
  const _StoreProduct({
    required this.id,
    required this.sku,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.asset,
    required this.features,
    this.imageUrl,
    this.price,
    this.currency = 'TRY',
    this.badge,
    this.comingSoon = false,
    this.trackStock = false,
    this.stockQuantity,
  });

  factory _StoreProduct.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    return _StoreProduct(
      id: '${json['id'] ?? ''}',
      sku: '${json['sku'] ?? ''}',
      title: '${json['title'] ?? ''}',
      subtitle: '${json['subtitle'] ?? ''}',
      category: '${json['category'] ?? 'Etiketler'}',
      asset: '${json['imageAsset'] ?? 'assets/Etiket4.png'}',
      imageUrl: json['imageUrl']?.toString(),
      features: rawFeatures is List
          ? rawFeatures.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      price: json['price'] is num
          ? (json['price'] as num).toDouble()
          : double.tryParse('${json['price'] ?? ''}'),
      currency: '${json['currency'] ?? 'TRY'}',
      badge: json['badge']?.toString(),
      comingSoon: json['comingSoon'] == true,
      trackStock: json['trackStock'] == true,
      stockQuantity: json['stockQuantity'] is num
          ? (json['stockQuantity'] as num).toInt()
          : int.tryParse('${json['stockQuantity'] ?? ''}'),
    );
  }

  final String id;
  final String sku;
  final String title;
  final String subtitle;
  final String category;
  final String asset;
  final String? imageUrl;
  final List<String> features;
  final double? price;
  final String currency;
  final String? badge;
  final bool comingSoon;
  final bool trackStock;
  final int? stockQuantity;

  bool get soldOut =>
      trackStock && stockQuantity != null && stockQuantity! <= 0;
}

Widget _storeProductImage(
  _StoreProduct product, {
  BoxFit fit = BoxFit.contain,
  double fallbackSize = 42,
}) {
  final url = (product.imageUrl ?? '').trim();
  if (url.isNotEmpty) {
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, __, ___) => Icon(
        Icons.qr_code_2_rounded,
        color: const Color(0xFF713BFF),
        size: fallbackSize,
      ),
    );
  }
  return Image.asset(
    product.asset,
    fit: fit,
    errorBuilder: (_, __, ___) => Icon(
      Icons.qr_code_2_rounded,
      color: const Color(0xFF713BFF),
      size: fallbackSize,
    ),
  );
}

class _StoreVehicle {
  const _StoreVehicle({
    required this.id,
    required this.plate,
    required this.title,
  });

  final String id;
  final String plate;
  final String title;
}

class _CartLine {
  const _CartLine({
    required this.product,
    required this.vehicle,
    this.quantity = 1,
  });

  final _StoreProduct product;
  final _StoreVehicle? vehicle;
  final int quantity;

  _CartLine copyWith({int? quantity}) => _CartLine(
        product: product,
        vehicle: vehicle,
        quantity: quantity ?? this.quantity,
      );
}
