from pathlib import Path

path = Path('lib/owner_dashboard_live.dart')
text = path.read_text(encoding='utf-8')

# Owner hero must use exactly the same image sizing strategy as the driver hero:
# same 500/555 height, BoxFit.cover, top-center alignment, no extra scale/overlay.
text = text.replace(
    "child:Transform.scale(scale:1.16,alignment:Alignment.topCenter,child:Image.asset(light?'assets/Aracsahibig.png':'assets/Aracsahibi.png',key:ValueKey(light),fit:BoxFit.cover,alignment:Alignment.topCenter))",
    "child:Image.asset(light?'assets/Aracsahibig.png':'assets/Aracsahibi.png',key:ValueKey(light),fit:BoxFit.cover,alignment:Alignment.topCenter,filterQuality:FilterQuality.high)",
)

path.write_text(text, encoding='utf-8')
print('Owner hero sizing matched to driver hero.')
