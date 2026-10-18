from pathlib import Path
from PIL import Image
from collections import deque
import json
r=Path(__file__).resolve().parents[1]/'assets/art';allmeta={}
for p in list(r.glob('*-poses.png'))+list(r.glob('*-walk.png')):
 im=Image.open(p);w,h=im.size;a=im.getchannel('A');step=3;sw=(w+step-1)//step;sh=(h+step-1)//step;raw=a.tobytes();mask=bytearray(1 if raw[min(y*step,h-1)*w+min(x*step,w-1)]>170 else 0 for y in range(sh) for x in range(sw));comps=[]
 for k in range(len(mask)):
  if not mask[k]:continue
  mask[k]=0;q=deque([k]);xs=[];ys=[]
  while q:
   v=q.pop();x=v%sw;y=v//sw;xs.append(x);ys.append(y)
   for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
    if 0<=nx<sw and 0<=ny<sh:
     j=ny*sw+nx
     if mask[j]:mask[j]=0;q.append(j)
  if len(xs)>200:comps.append((len(xs),max(0,min(xs)*step-5),max(0,min(ys)*step-5),min(w,(max(xs)+1)*step+5),min(h,(max(ys)+1)*step+5)))
 count=6 if '-poses' in p.stem else 4;cols=3 if count==6 else 2;comps=sorted(comps,reverse=True)[:count];assert len(comps)==count,(p,len(comps));comps=sorted(comps,key=lambda b:(b[2]+b[4])/2);ordered=[]
 for row in (comps[:cols],comps[cols:]):ordered+=sorted(row,key=lambda b:b[1])
 frames=[]
 for _,x,y,x2,y2 in ordered:
  # Metadata only: read the alpha distribution to locate a torso pivot. Source PNGs stay untouched.
  band=a.crop((x,y+int((y2-y)*.2),x2,y+int((y2-y)*.7)));bw,bh=band.size;d=band.tobytes();proj=[sum(d[xx::bw]) for xx in range(bw)];pivot=proj.index(max(proj))
  frames.append({'x':x,'y':y,'w':x2-x,'h':y2-y,'ox':pivot,'oy':y2-y-5})
 allmeta[p.stem]={'height':frames[0]['h']-10,'frames':frames}
 print(p.name,len(frames))
(r/'atlas.json').write_text(json.dumps(allmeta,indent=2))
# Lua table is loaded without requiring a JSON dependency.
def lua(v):
 if isinstance(v,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(x) for k,x in v.items())+'}'
 if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
 return str(v)
(r/'atlas.lua').write_text('return '+lua(allmeta)+'\n')
