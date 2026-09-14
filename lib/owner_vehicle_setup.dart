import 'package:flutter/material.dart';
import 'vehicle_api.dart';
import 'onboarding_backend.dart';

const _bg = Color(0xFF06111F);
const _panel = Color(0xFF101A30);
const _panel2 = Color(0xFF0B1529);
const _line = Color(0xFF29385F);
const _purple = Color(0xFF8B5CFF);
const _purple2 = Color(0xFF6C3CFF);
const _orange = Color(0xFFFFA51F);
const _muted = Color(0xFFA7B0C7);

class OwnerVehicleSetupPage extends StatefulWidget {
  const OwnerVehicleSetupPage({super.key, required this.onDone, required this.onBack});
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<OwnerVehicleSetupPage> createState() => _OwnerVehicleSetupPageState();
}

class _OwnerVehicleSetupPageState extends State<OwnerVehicleSetupPage> {
  final plate = TextEditingController(text: '34 ABC 123');
  String make = 'BMW';
  String model = '3 Series';
  List<String> makes = const [];
  List<String> models = const [];
  bool loadingModels = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    plate.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    plate.removeListener(_refresh);
    plate.dispose();
    super.dispose();
  }

  void _refresh() => mounted ? setState(() {}) : null;

  Future<void> _load() async {
    final all = await VehicleApi.getMakes();
    if (!mounted) return;
    setState(() => makes = all);
    await _loadModels(make);
  }

  Future<void> _loadModels(String value) async {
    setState(() => loadingModels = true);
    final result = await VehicleApi.getModels(value);
    if (!mounted) return;
    setState(() {
      models = result;
      model = result.isEmpty ? '' : result.firstWhere((m) => value == 'BMW' && m.toLowerCase().contains('3'), orElse: () => result.first);
      loadingModels = false;
    });
  }

  Future<void> _save() async {
    if (saving) return;
    if (plate.text.trim().isEmpty || make.isEmpty || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plaka, marka ve modeli tamamla.')));
      return;
    }
    if (OnboardingDraft.otpCode.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Telefon doğrulaması tamamlanmadı.')));
      return;
    }
    setState(() => saving = true);
    try {
      await OnboardingBackend.registerWithVehicle(
        phone: OnboardingDraft.phone,
        displayName: OnboardingDraft.displayName,
        email: OnboardingDraft.email,
        password: OnboardingDraft.password,
        plate: plate.text.trim(),
        make: make,
        model: model,
      );
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final compact = MediaQuery.sizeOf(context).height < 780;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, top + 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconButton(onPressed: widget.onBack, icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 34)),
                const SizedBox(width: 8),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: const LinearProgressIndicator(value: .55, minHeight: 6, backgroundColor: Color(0xFF25304A), valueColor: AlwaysStoppedAnimation(_purple)))),
                const SizedBox(width: 10),
                const Text('2/3', style: TextStyle(color: _muted, fontWeight: FontWeight.w800)),
              ]),
              SizedBox(height: compact ? 12 : 18),
              SizedBox(
                height: compact ? 205 : 230,
                child: Stack(children: [
                  Positioned.fill(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A1328), Color(0xFF17123E)])))),
                  Positioned(right: -28, bottom: -8, width: compact ? 235 : 260, child: Image.asset('assets/Aracsahibi.png', fit: BoxFit.contain)),
                  const Positioned(left: 18, top: 18, child: Text.rich(TextSpan(children: [TextSpan(text: 'Aracını ', style: TextStyle(color: Colors.white)), TextSpan(text: 'ekle', style: TextStyle(color: _purple))]), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1))),
                  const Positioned(left: 18, top: 66, width: 205, child: Text('Plakanı yaz, ardından marka ve modelini seç.', style: TextStyle(color: _muted, fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w500))),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                height: 52,
                decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: _line)),
                child: Row(children: [
                  Expanded(child: Container(alignment: Alignment.center, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, _purple2]), borderRadius: BorderRadius.circular(16)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 19), SizedBox(width: 8), Text('Plaka ile ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5))]))),
                  const Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_rounded, color: _muted, size: 18), SizedBox(width: 7), Text('Ruhsat fotoğrafı', style: TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 12.5))])),
                ]),
              ),
              const SizedBox(height: 14),
              _PlateField(controller: plate),
              const SizedBox(height: 14),
              _label('Araç markası', 'Marka seç', _showMakes),
              const SizedBox(height: 7),
              _Selector(onTap: _showMakes, leading: _BrandLogo(make), title: make, trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70)),
              const SizedBox(height: 14),
              _label('Model', 'Model seç', _showModels),
              const SizedBox(height: 7),
              _Selector(onTap: loadingModels ? null : _showModels, leading: const Icon(Icons.badge_outlined, color: _purple), title: loadingModels ? 'Modeller yükleniyor...' : (model.isEmpty ? 'Model seç' : model), trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70)),
              const SizedBox(height: 14),
              Container(
                height: 84,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
                child: Row(children: [
                  Container(width: 62, height: 58, decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(15), border: Border.all(color: _line)), child: Padding(padding: const EdgeInsets.all(10), child: _BrandLogo(make))),
                  const SizedBox(width: 13),
                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$make $model', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(plate.text.trim().toUpperCase(), style: const TextStyle(color: _muted, fontSize: 14))])),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 56, child: FilledButton(onPressed: saving ? null : _save, style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: const Color(0xFF10131D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(saving ? 'Kaydediliyor...' : 'Aracı kaydet', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(width: 8), if (!saving) const Icon(Icons.arrow_forward_rounded)]))),
              const SizedBox(height: 10),
              const Center(child: Text('QR etiketin bu araca bağlanacak.', style: TextStyle(color: _muted, fontSize: 12.5))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String left, String right, VoidCallback tap) => Row(children: [Text(left, style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w800)), const Spacer(), InkWell(onTap: tap, child: Row(children: [Text(right, style: const TextStyle(color: _purple, fontSize: 12.5, fontWeight: FontWeight.w900)), const Icon(Icons.chevron_right_rounded, color: _purple, size: 19)]))]);

  Future<void> _showMakes() async {
    final selected = await showModalBottomSheet<String>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _PickerSheet(title: 'Araç markasını seç', values: makes, selected: make, showLogos: true));
    if (selected == null || selected == make) return;
    setState(() { make = selected; model = ''; });
    await _loadModels(make);
  }

  Future<void> _showModels() async {
    if (models.isEmpty) return;
    final selected = await showModalBottomSheet<String>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _PickerSheet(title: 'Model seç', values: models, selected: model));
    if (selected != null) setState(() => model = selected);
  }
}

class _PlateField extends StatelessWidget {
  const _PlateField({required this.controller}); final TextEditingController controller;
  @override Widget build(BuildContext context) => Container(height: 62, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Row(children: [Container(width: 62, alignment: Alignment.center, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0C49A1), Color(0xFF073273)])), child: const Text('TR', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))), Expanded(child: TextField(controller: controller, textAlign: TextAlign.center, textCapitalization: TextCapitalization.characters, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900), decoration: const InputDecoration(hintText: '34 ABC 123', hintStyle: TextStyle(color: Color(0xFF69738D)), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false)))]));
}

class _Selector extends StatelessWidget {
  const _Selector({required this.onTap, required this.leading, required this.title, required this.trailing}); final VoidCallback? onTap; final Widget leading,trailing; final String title;
  @override Widget build(BuildContext context) => Material(color: _panel, borderRadius: BorderRadius.circular(18), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(height: 62, padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Row(children: [SizedBox(width: 36, height: 36, child: Center(child: leading)), const SizedBox(width: 12), Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))), trailing]))));
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo(this.make); final String make;
  @override Widget build(BuildContext context) { final url = VehicleApi.brandLogoUrl(make); if (url == null) return const Icon(Icons.directions_car_filled_rounded, color: _purple, size: 28); return Image.network(url, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.directions_car_filled_rounded, color: _purple, size: 28)); }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.title, required this.values, required this.selected, this.showLogos=false}); final String title,selected; final List<String> values; final bool showLogos;
  @override State<_PickerSheet> createState()=>_PickerSheetState();
}
class _PickerSheetState extends State<_PickerSheet>{
  final search=TextEditingController(); String q='';
  @override void dispose(){search.dispose();super.dispose();}
  @override Widget build(BuildContext context){final list=widget.values.where((e)=>e.toLowerCase().contains(q.toLowerCase())).toList(); return Container(height:MediaQuery.sizeOf(context).height*.72,decoration:const BoxDecoration(color:Color(0xFF0B1427),borderRadius:BorderRadius.vertical(top:Radius.circular(28))),child:Column(children:[const SizedBox(height:10),Container(width:46,height:5,decoration:BoxDecoration(color:const Color(0xFF4B5775),borderRadius:BorderRadius.circular(8))),Padding(padding:const EdgeInsets.fromLTRB(20,16,20,12),child:Row(children:[Expanded(child:Text(widget.title,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900))),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded,color:Colors.white))])),Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:TextField(controller:search,onChanged:(v)=>setState(()=>q=v),style:const TextStyle(color:Colors.white),decoration:InputDecoration(hintText:'Ara...',hintStyle:const TextStyle(color:_muted),prefixIcon:const Icon(Icons.search_rounded,color:_muted),filled:true,fillColor:_panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:_line)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:_line))))),const SizedBox(height:12),Expanded(child:GridView.builder(padding:const EdgeInsets.fromLTRB(20,0,20,24),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.12),itemCount:list.length,itemBuilder:(c,i){final value=list[i],selected=value==widget.selected;return InkWell(onTap:()=>Navigator.pop(context,value),borderRadius:BorderRadius.circular(18),child:Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:selected?_purple.withValues(alpha:.18):_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:selected?_purple:_line,width:selected?1.7:1)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[if(widget.showLogos)SizedBox(width:38,height:38,child:_BrandLogo(value))else const Icon(Icons.directions_car_filled_rounded,color:_purple,size:25),const SizedBox(height:7),Text(value,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:selected?Colors.white:_muted,fontSize:11.5,fontWeight:FontWeight.w800))])));}))]));}
}
