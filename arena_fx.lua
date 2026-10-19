local E={time=0,particles={},ghosts={},labels={},sources={},sfxVolume=.8,musicVolume=.3,muted=false,paused=false,damageFlash=0}
local g=love.graphics
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function col(c,a)g.setColor(c[1],c[2],c[3],a or 1)end
local function text(t,x,y,w,align)g.printf(t,x,y,w,align or 'left')end
function E.sound(name,x,pitch)
 if E.muted then return end
 local proto=E.sources[name];if not proto then return end
 local s=proto:clone();s:setVolume(E.sfxVolume*(name=='step' and .22 or .8));s:setPitch(pitch or (1+love.math.random()*.08));s:play();E.playing=E.playing or {};table.insert(E.playing,s)
end
function E.load()
 E.font=g.newFont(12);E.small=g.newFont(10);E.title=g.newFont(24)
 for _,n in ipairs({'punch','kick','block','jump','land','step','menu','confirm','pickup','break','spring','web','teleport','flight','timestop','ko','whoosh'})do
  local p='assets/audio/'..n..'.wav';if love.filesystem.getInfo(p)then E.sources[n]=love.audio.newSource(p,'static')end
 end
 E.music={};for _,n in ipairs({'menu_theme','arena_theme'})do if love.filesystem.getInfo('assets/audio/'..n..'.wav')then local s=love.audio.newSource('assets/audio/'..n..'.wav','stream');s:setLooping(true);s:setVolume(0);E.music[n]=s end end
 E.art={};E.sheets={};E.walks={};E.animals={}
 for _,name in ipairs({"horse","boar"})do local p="assets/art/"..name..".png";if love.filesystem.getInfo(p)then E.animals[string.upper(name)]=g.newImage(p)end end
 for _,name in ipairs({'ember','tempest','warden','viper'})do
  local p='assets/art/'..name..'.png';if love.filesystem.getInfo(p)then E.art[name]=g.newImage(p);E.art[name]:setFilter('linear','linear')end
  local wp='assets/art/'..name..'-walk.png';if love.filesystem.getInfo(wp)then local im=g.newImage(wp);im:setFilter('linear','linear');local w,h=im:getDimensions();local a={image=im,frames={},w=w/2,h=h/2};for i=0,3 do a.frames[i+1]=g.newQuad(i%2*a.w,math.floor(i/2)*a.h,a.w,a.h,w,h)end;E.walks[name]=a end
  p='assets/art/'..name..'-poses.png';if love.filesystem.getInfo(p)then local im=g.newImage(p);im:setFilter('linear','linear');local w,h=im:getDimensions();local a={image=im,frames={},w=w/3,h=h/2};for i=0,5 do a.frames[i+1]=g.newQuad(i%3*a.w,math.floor(i/3)*a.h,a.w,a.h,w,h)end;E.sheets[name]=a end
 end
 -- Atlas geometry is measured from actual alpha bounds; no PNG resampling.
 local meta=require('assets.art.atlas')
 for name,a in pairs(E.sheets)do
  local m=meta[name..'-poses'];a.height=m.height;a.meta=m.frames;a.frames={};local w,h=a.image:getDimensions()
  for i,v in ipairs(m.frames)do a.frames[i]=g.newQuad(v.x,v.y,v.w,v.h,w,h)end
 end
 for name,a in pairs(E.walks)do
  local m=meta[name..'-walk'];a.height=m.height;a.meta=m.frames;a.frames={};local w,h=a.image:getDimensions()
  for i,v in ipairs(m.frames)do a.frames[i]=g.newQuad(v.x,v.y,v.w,v.h,w,h)end
 end
 if love.filesystem.getInfo('assets/art/arena.png')then E.background=g.newImage('assets/art/arena.png');E.background:setFilter('linear','linear')end
 E.reset()
end
function E.reset()
 E.particles={};E.ghosts={};E.labels={};E.gimmicks={
 {kind='spring',x=530,cool=0},{kind='crystal',x=910,hp=3,cool=0},
 {kind='wind',x=1430,cool=0},{kind='spring',x=1680,cool=0},
 {kind='crystal',x=2320,hp=3,cool=0},{kind='wind',x=2740,cool=0},
 {kind='altar',x=3080,cool=0}}
 E.lastTime=nil;E.resultPlayed=false
end
function E.burst(x,y,c,n,strength)
 for i=1,n do local a=love.math.random()*math.pi*2;local v=30+love.math.random()*(strength or 150);table.insert(E.particles,{x=x,y=y,vx=math.cos(a)*v,vy=math.sin(a)*v-35,t=.25+love.math.random()*.4,max=.7,c=c,size=1+love.math.random()*3})end
end
function E.label(msg,x,y,c)table.insert(E.labels,{msg=msg,x=x,y=y,t=1,c=c or {1,.85,.4}})end
function E.hit(f,damage,blocked)
 E.sound(blocked and 'block' or (damage>=23 and 'kick' or 'punch'),f.x)
 E.burst(f.x,f.y-42,blocked and {.6,.85,1} or {1,.68,.3},blocked and 12 or 23,180)
 E.label(blocked and 'BLOCK' or tostring(damage),f.x,f.y-84,blocked and {.6,.85,1} or {1,.92,.75})
 E.damageFlash=.1
end
function E.special(f,index)
 E.sound(({'web','teleport','flight','timestop'})[index],f.x)
 E.burst(f.x,f.y-40,f.color,40,230)
 if index==2 then E.burst(f.x-f.facing*35,f.y-48,f.color,35,180)end
end
function E.update(dt,c)
 E.ctx=c;E.time=E.time+dt
 local duck=1
 for _,f in ipairs(c.fighters)do if f.special then duck=.58 end end
 local want=c.game.state=='character_select' and 'menu_theme' or 'arena_theme'
 for name,s in pairs(E.music)do if not s:isPlaying()then s:play()end;local target=(name==want and not E.muted and not E.paused) and E.musicVolume*duck or 0;s:setVolume(s:getVolume()+(target-s:getVolume())*math.min(1,dt*3))end
 if E.playing then for i=#E.playing,1,-1 do if not E.playing[i]:isPlaying()then table.remove(E.playing,i)end end end
 if E.paused then return end
 for _,p in ipairs(E.particles)do p.t=p.t-dt;p.x=p.x+p.vx*dt;p.y=p.y+p.vy*dt;p.vy=p.vy+160*dt end
 for i=#E.particles,1,-1 do if E.particles[i].t<=0 then table.remove(E.particles,i)end end
 for i=#E.labels,1,-1 do local l=E.labels[i];l.t=l.t-dt;l.y=l.y-dt*22;if l.t<=0 then table.remove(E.labels,i)end end
 if c.game.state~='fighting'then
  if c.game.state~='character_select' and not E.resultPlayed then E.sound('confirm');E.resultPlayed=true end
  return
 end
 if E.lastTime and c.game.timeRemaining>E.lastTime+1 then E.reset()end;E.lastTime=c.game.timeRemaining
 for _,f in ipairs(c.fighters)do
  f._step=(f._step or 0)-dt
  if f._grounded==false and f.grounded then E.sound('land');E.burst(f.x,f.y,{.7,.74,.8},8,60)end
  f._grounded=f.grounded
  local moving=f._oldx and math.abs(f.x-f._oldx)>dt*30
  if moving and f.grounded and f._step<=0 then E.sound('step');f._step=.26;E.burst(f.x,f.y,{.58,.59,.65},3,30)end
  f._oldx=f.x
  if f.flightTimer>0 or f.bootsTimer>0 then if math.floor(E.time*24)~=math.floor((E.time-dt)*24)then E.burst(f.x-f.facing*18,f.y-30,f.color,2,35)end end
 end
 for _,v in ipairs(E.gimmicks)do
  v.cool=math.max(0,v.cool-dt)
  for _,f in ipairs(c.fighters)do
   if not f.ko then local near=math.abs(f.x-v.x)
    if v.kind=='spring' and near<27 and f.grounded and f.y>=455 and v.cool<=0 then f.velocityY=-850;f.grounded=false;v.cool=.8;E.sound('spring');E.burst(v.x,455,{.3,1,.8},25,190);E.label('SKY BOOST',v.x,397)
    elseif v.kind=='wind' and near<65 and f.y>200 and not f.grounded and f.velocityY> -260 then f.velocityY=f.velocityY-dt*1000
    elseif v.kind=='crystal' and v.hp>0 and v.cool<=0 and near<105 and f.attack and f.attack.phase=='active' and math.abs(f.y-460)<90 and (v.x-f.x)*f.facing>0 then
     v.hp=v.hp-1;v.cool=.4;E.sound('block');E.burst(v.x,425,{.6,.4,1},16,120)
     if v.hp<=0 then E.sound('break');f.health=math.min(f.maxHealth,f.health+18);for i=1,4 do f.specialCooldowns[i]=math.max(0,f.specialCooldowns[i]-4)end;E.label('+18 HP / RECHARGE',v.x,390);E.burst(v.x,425,{.8,.6,1},50,230)end
    elseif v.kind=='altar' and near<35 and f.grounded and v.cool<=0 then v.cool=18;f.shieldHealth=math.max(f.shieldHealth,30);E.sound('pickup');E.label('GUARD BLESSING',v.x,385);E.burst(v.x,425,{.3,.8,1},35,150)end
   end
  end
 end
end
function E.backgroundDraw(cameraX)
 if not E.background then return false end
 local im=E.background;local w,h=im:getDimensions();g.setColor(1,1,1);local scale=math.max(960/w,470/h);g.draw(im,-cameraX*.20,0,0,math.max(scale,(960+3600*.20)/w),470/h)
 -- Near silhouettes move faster than the distant panorama.
 for i=0,9 do local x=i*440-cameraX*.48;g.setColor(.045,.085,.13,.52);g.polygon('fill',x,460,x+32,258+(i%3)*21,x+48,258+(i%3)*21,x+78,460);g.rectangle('fill',x-14,295+(i%3)*21,91,12)end
 for i=1,35 do local x=(i*113-E.time*8-cameraX*.12)%1020-30;local y=180+(i*61)%270+math.sin(E.time+i)*12;g.setColor(.5,.9,1,.2+.25*math.sin(E.time*2+i)^2);g.circle('fill',x,y,1.1)end
 g.setColor(.025,.03,.055,.18);g.rectangle('fill',0,0,960,460)
 return true
end
function E.portrait(character,x,y,scale,selected)
 local im=E.art[string.lower(character.name)];if not im then return false end
 if selected then col(character.accent,.1+.05*math.sin(E.time*3));g.circle('fill',x,y,69*scale)end
 local w,h=im:getDimensions();local s=143*scale/h;g.setColor(1,1,1);g.draw(im,x,y+68*scale,0,s,s,w/2,h);return true
end
function E.fighter(f)
 local name=f.character and string.lower(f.character.name);local a=E.sheets[name];local im=E.art[name];if not a and not im then return false end
 local frame=1
 local moving=f._oldDrawX and math.abs(f.x-f._oldDrawX)>.03
 f._oldDrawX=f.x
 if f.ko or f.hitFlash>0 then frame=6 elseif f.crouching then frame=4 elseif f.attack then frame=f.attack.kind=='low' and 3 or 2 elseif not f.grounded then frame=5 end
 if E.walks[name] and not f.ko and f.hitFlash<=0 and not f.attack and f.grounded and not f.crouching then
  if f.mount then a=E.walks[name];frame=3 elseif f.blocking then a=E.walks[name];frame=4 elseif moving then a=E.walks[name];frame=math.floor(E.time*9)%2+1 end
 end
 local h=(f.mount and 90 or 102)*(f.mushroomTimer>0 and 1.35 or 1);local y=f.y;local bob=(f.grounded and not f.attack and not f.crouching)and math.sin(E.time*(f.state=='walking' and 15 or 4))*1.2 or 0
 g.setColor(.02,.025,.04,.35);g.ellipse('fill',f.x,f.y-1,24*(h/102),4)
 g.setColor(1,1,1,f.invulnerableTimer>0 and (.5+.5*math.sin(E.time*28)^2)or 1)
 g.push();g.translate(f.x,y+bob)
 if f.ko then g.rotate(-f.facing*1.2)end
 if a then local s=h/(a.height or a.h*.88);local m=a.meta and a.meta[frame];g.draw(a.image,a.frames[frame],0,0,0,s*f.facing,s,m and m.ox or a.w*.5,m and m.oy or a.h*.94)
 else local w,ih=im:getDimensions();g.draw(im,0,0,0,h/ih*f.facing,h/ih,w*.5,ih)end
 g.pop()
 if f.timeStopTimer>0 then g.setColor(.3,.8,1,.25);g.circle('fill',f.x,f.y-45,50);g.setColor(.6,.9,1,.8);g.setLineWidth(2);g.circle('line',f.x,f.y-45,45);for k=1,8 do local a=k*math.pi/4+E.time*.1;g.line(f.x+math.cos(a)*39,f.y-45+math.sin(a)*39,f.x+math.cos(a)*45,f.y-45+math.sin(a)*45)end end
 if f.blocking or f.shieldHealth>0 then col(f.character.accent,.4);g.setLineWidth(2);g.arc('line','open',f.x,f.y-45,40,f.facing==1 and -1.3 or 1.8,f.facing==1 and 1.3 or 4.5)end
 if f.attack and f.attack.phase=='active'then local y=f.y-(f.attack.kind=='low' and 14 or 53);col(f.character.accent,.7);g.setLineWidth(3);g.arc('line','open',f.x+f.facing*28,y,28,f.facing==1 and -1.4 or 1.7,f.facing==1 and 1.4 or 4.5);g.setLineWidth(1)end
 return true
end
function E.world(c)
 local t=E.time
 for _,v in ipairs(E.gimmicks)do
  if v.kind=='spring'then g.setColor(.13,.35,.34);g.rectangle('fill',v.x-26,453,52,7,3);g.setColor(.3,1,.75);for i=0,2 do local y=448-i*9-math.sin(t*5)*2;g.line(v.x-12,y+5,v.x,y,v.x+12,y+5)end
  elseif v.kind=='crystal' and v.hp>0 then g.setColor(.24,.12,.4);g.ellipse('fill',v.x,459,22,4);g.setColor(.55,.28,.92);g.polygon('fill',v.x,399+math.sin(t*3)*3,v.x+19,425,v.x+8,452,v.x-12,450,v.x-20,425);g.setColor(.85,.7,1);g.line(v.x,403,v.x+3,446);text('HIT '..v.hp,v.x-25,465,50,'center')
  elseif v.kind=='wind'then for i=0,8 do local y=460-(t*100+i*34)%240;g.setColor(.4,.85,1,.18*(1-(460-y)/260));g.arc('line','open',v.x,y,20+((460-y)/10),0,math.pi)end
  elseif v.kind=='altar'then g.setColor(.18,.22,.32);g.rectangle('fill',v.x-23,445,46,15,3);g.setColor(.35,.8,1,v.cool>0 and .18 or .8);g.circle('line',v.x,420,19);g.polygon('line',v.x,407,v.x+10,417,v.x+7,431,v.x,436,v.x-7,431,v.x-10,417)end
 end
 for _,p in ipairs(E.particles)do col(p.c,math.min(1,p.t*3));g.rectangle('fill',p.x,p.y,p.size,p.size)end
 g.setFont(E.font);for _,l in ipairs(E.labels)do col(l.c,math.min(1,l.t*2));text(l.msg,l.x-90,l.y,180,'center')end
end
function E.health(f,x,right,label,lives)
 local bx=right and 668 or 18;g.setFont(E.font);g.setColor(.025,.035,.06,.87);g.rectangle('fill',bx-5,15,279,66,7);col(f.color);text(f.character.name,bx,21,180,right and 'right' or 'left');g.setColor(.9,.94,1);text(tostring(f.health)..' / '..f.maxHealth,bx,21,264,right and 'left' or 'right');g.setColor(.13,.16,.23);g.rectangle('fill',bx,43,264,13,4);col(f.color);g.rectangle('fill',bx,43,264*f.health/f.maxHealth,13,4);g.setColor(.85,.9,1);text('LIVES '..lives..'   '..(label=='F1' and 'P1' or 'P2'),bx,62,264,right and 'right' or 'left')
end
function E.specialHud(f,x,right,keys)
 local bx=right and 668 or 18;g.setFont(E.small)
 for i,key in ipairs(keys)do local px=bx+(i-1)*67;local cd=f.specialCooldowns[i];g.setColor(.04,.07,.12,.86);g.rectangle('fill',px,88,62,29,4);col(f.character.accent,cd<=0 and .8 or .24);g.rectangle('line',px,88,62,29,4);g.setColor(.85,.92,1);text(key..' '..(cd<=0 and ({'WEB','SHIFT','FLY','TIME'})[i] or string.format('%.1f',cd)),px,97,62,'center')end
end
function E.overlay()
 local w,h=g.getDimensions();g.setFont(E.small);g.setColor(.8,.85,.95,.7);g.printf('ESC PAUSE  |  F2 CPU / PVP  |  0 MUTE  |  - / + MUSIC',15,h-19,w-30,'right')
 if E.paused then g.setColor(.015,.025,.045,.88);g.rectangle('fill',0,0,w,h);g.setColor(1,.85,.5);g.setFont(E.title);g.printf('PAUSED',0,h*.35,w,'center');g.setFont(E.font);g.setColor(.9,.94,1);g.printf('ESC Resume    C Characters    0 Mute\n- / + Music volume    [ / ] Sound effects\nF2 Toggle CPU opponent',0,h*.46,w,'center')end
end
function E.key(key)
 if key=='escape'then E.paused=not E.paused;E.sound('menu');return true end
 if key=='0'then E.muted=not E.muted;return true end
 if key=='-' or key=='='then E.musicVolume=clamp(E.musicVolume+(key=='=' and .05 or -.05),0,.8);return true end
 if key=='[' or key==']'then E.sfxVolume=clamp(E.sfxVolume+(key==']' and .1 or -.1),0,1);E.sound('menu');return true end
 if E.paused and key~='c'then return true end
end
function E.animal(a)
 local im=E.animals[a.kind];if not im then return false end
 local h=a.kind=='HORSE' and 80 or 51;local w,ih=im:getDimensions();local s=h/ih;local dir=a.facing or 1
 g.setColor(.02,.03,.04,.35);g.ellipse('fill',a.x,a.y,37,5)
 g.setColor(1,1,1);g.draw(im,a.x,a.y+math.sin(E.time*5+a.x)*.6,0,s*dir,s,w*.5,ih)
 if not a.rider then g.setFont(E.small);g.setColor(.95,.85,.5);text('E / RIDE',a.x-35,a.y-h-17,70,'center')end
 if a.bonded then g.setColor(1,.8,.3,.5);g.circle('line',a.x,a.y-28,40)end
 return true
end
return E
