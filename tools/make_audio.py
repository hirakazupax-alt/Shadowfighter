import sys
import numpy as np, wave
from pathlib import Path
r=Path(__file__).resolve().parents[1]/'assets/audio';sr=24000;rng=np.random.default_rng(82)
def save(name,a):
 a=np.tanh(a*1.3);a*=min(1,.94/(np.max(np.abs(a))+1e-7));w=wave.open(str(r/(name+'.wav')),'wb');w.setnchannels(2 if a.ndim==2 else 1);w.setsampwidth(2);w.setframerate(sr);w.writeframes((a*32767).astype('<i2').tobytes());w.close()
def effect(name,dur,f0,f1,noise=.3,metal=0):
 t=np.arange(int(sr*dur))/sr;n=rng.normal(0,1,len(t));n=np.convolve(n,[.2,.6,.2],mode='same');env=np.exp(-t/(dur*.22))*np.minimum(t/.003,1);phase=2*np.pi*(f0*t+(f1-f0)*t*t/(2*dur));a=(np.sin(phase)*.65+n*noise+metal*np.sin(phase*2.73))*env
 for delay,g in [(.035,.18),(.071,.10)]:
  k=int(delay*sr)
  if k<len(a):a[k:]+=a[:-k].copy()*g
 save(name,a)
for row in [('punch',.25,170,42,.75,0),('kick',.4,115,30,.95,0),('block',.35,480,160,.5,.45),('jump',.24,210,620,.06,0),('land',.2,85,36,.6,0),('step',.12,80,35,.4,0),('menu',.12,660,990,.01,.15),('confirm',.4,440,880,.04,.12),('pickup',.7,520,1300,.06,.2),('break',.65,250,32,1.2,.3),('spring',.4,130,950,.08,.1),('web',.5,140,820,.5,.1),('teleport',.55,990,110,.5,.3),('flight',.9,220,660,.12,.3),('timestop',1.2,1400,70,.25,.5),('ko',1.1,110,24,1.1,.1),('whoosh',.22,240,100,1,0)]:effect(*row)
# Original 8-bar, four-chord loop. Pads, plucked melody, bass, kick/snare/hat and stereo echoes.
beat=60/112;beats=32;N=int(sr*beat*beats);mix=np.zeros((N,2));
def add(a,pos,vol=1,pan=0):
 start=int(pos*sr);ix=(np.arange(len(a))+start)%N;mix[ix,0]+=a*vol*np.sqrt((1-pan)/2);mix[ix,1]+=a*vol*np.sqrt((1+pan)/2)
def note(midi,dur,kind):
 t=np.arange(int(dur*sr))/sr;f=440*2**((midi-69)/12);ph=2*np.pi*f*t
 if kind=='pad':return (np.sin(ph)+.25*np.sin(ph*2)+.15*np.sin(ph*1.003))*np.minimum(t/.16,1)*np.minimum((dur-t)/.3,1)*.15
 if kind=='bass':return (np.sin(ph)+.3*np.sin(ph*2))*np.exp(-t*3)*np.minimum(t/.008,1)*.42
 return (np.sin(ph)+.28*np.sin(ph*2)+.12*np.sin(ph*3))*np.exp(-t*5)*np.minimum(t/.005,1)*.3
for bar in range(8):
 root=[45,41,48,43][bar%4];pos=bar*4*beat
 for j,n in enumerate([root+12,root+15,root+19]):add(note(n,4*beat,'pad'),pos,.6,(j-1)*.45)
 for b in range(4):add(note(root if b!=3 else root+7,beat*.85,'bass'),pos+b*beat,.75)
 for b,n in enumerate([0,7,12,15,12,7,10,7]):
  at=pos+b*beat/2;a=note(root+24+n,beat*.8,'pluck');add(a,at,.4,(-1)**b*.3);add(a,at+beat*.75,.15,(-1)**(b+1)*.55)
 for b in range(8):
  t=np.arange(int(sr*.08))/sr;hat=rng.normal(0,1,len(t));hat=hat-np.convolve(hat,np.ones(5)/5,'same');add(hat*np.exp(-t*70),pos+b*beat/2,.055,.3)
 for b in range(4):
  t=np.arange(int(sr*.23))/sr
  if b%2==0:a=np.sin(2*np.pi*(50*t+13*(1-np.exp(-t*35))))*np.exp(-t*20);vol=.5
  else:a=(rng.normal(0,1,len(t))*.5+np.sin(2*np.pi*180*t)*.25)*np.exp(-t*22);vol=.22
  add(a,pos+b*beat,vol)
save('arena_theme',mix*.7)
# Separate quieter menu mix with no percussion.
menu=np.zeros((N,2));old=mix;mix=menu
for bar in range(8):
 root=[45,41,48,43][bar%4]
 for j,n in enumerate([root+12,root+15,root+19]):add(note(n,4*beat,'pad'),bar*4*beat,.9,(j-1)*.6)
 for b,n in enumerate([12,19,22,19]):add(note(root+12+n,beat*1.8,'pluck'),(bar*4+b)*beat,.45,(-1)**b*.35)
save('menu_theme',mix)
(r/'LICENSE.txt').write_text('Original synthesized music and sound effects created for this project. No external recordings or commercial music used. Reproducible generation script: tools/make_audio.py.\n')
print('Created',len(list(r.glob('*.wav'))),'OGG files')
