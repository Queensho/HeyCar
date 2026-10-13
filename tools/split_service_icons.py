from pathlib import Path
import cv2,numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[1]
source=root/'assets/file_000000006b808210b2c74a878fdd8cee.png'
out=root/'assets/images/services'
out.mkdir(parents=True,exist_ok=True)
img=np.asarray(Image.open(source).convert('RGB'))
assert img.shape[:2]==(1024,1536),img.shape
boxes={'magaza':(20,70,450,500),'cekici':(430,80,1060,510),'yol_yardim':(1020,60,1510,520),'vale':(120,520,740,1000),'firsatlar':(760,530,1490,1000)}
for name,(x,y,x2,y2) in boxes.items():
 crop=img[y:y2,x:x2].copy()
 h,w=crop.shape[:2]
 mask=np.zeros((h,w),np.uint8)
 bg=np.zeros((1,65),np.float64);fg=np.zeros((1,65),np.float64)
 cv2.grabCut(crop,mask,(10,10,w-20,h-20),bg,fg,8,cv2.GC_INIT_WITH_RECT)
 mask=np.isin(mask,[1,3]).astype('uint8')
 count,labels,stats,_=cv2.connectedComponentsWithStats(mask,8)
 kept=np.zeros_like(mask)
 for i in range(1,count):
  if stats[i,cv2.CC_STAT_AREA]>.02*h*w:kept[labels==i]=1
 if kept.sum()==0:raise RuntimeError('Cannot isolate '+name)
 alpha=cv2.medianBlur(kept*255,5)
 yy,xx=np.where(alpha>10)
 rgba=np.dstack((crop,alpha))[yy.min():yy.max()+1,xx.min():xx.max()+1]
 icon=Image.fromarray(rgba,'RGBA');iw,ih=icon.size
 scale=min(472/iw,472/ih)
 icon=icon.resize((round(iw*scale),round(ih*scale)),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(512,512),(0,0,0,0))
 canvas.alpha_composite(icon,((512-icon.width)//2,(512-icon.height)//2))
 assert canvas.getextrema()[3][0]==0,name
 canvas.save(out/(name+'.png'))
 print(name,'512x512 RGBA')
