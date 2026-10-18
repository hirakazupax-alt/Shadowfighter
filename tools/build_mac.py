from pathlib import Path
import shutil,zipfile,plistlib,sys,subprocess
r=Path(__file__).resolve().parents[1];out=r/'dist';out.mkdir(exist_ok=True)
archive=out/'Moonfall-Arena.love'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for p in r.rglob('*'):
  rel=p.relative_to(r)
  if p.is_file() and not any(x in ('.git','dist','__pycache__') for x in rel.parts) and p.suffix in ('.lua','.png','.wav','.txt','.html','.py','.json'):z.write(p,str(rel))
app=out/'Shadow Fighters - Moonfall Arena.app'
if not app.exists():shutil.copytree(sys.argv[1],app,symlinks=True)
resources=app/'Contents/Resources';shutil.copy2(archive,resources/'game.love')
for n in ['controller_server.py','controller.html']:shutil.copy2(r/n,resources/n)
p=app/'Contents/Info.plist'
with p.open('rb') as f:info=plistlib.load(f)
info['CFBundleIdentifier']='com.jomtien.shadowfighters.moonfall';info['CFBundleName']='Moonfall Arena';info['CFBundleDisplayName']='Shadow Fighters - Moonfall Arena';info['CFBundleShortVersionString']='0.2.0';info['CFBundleVersion']='2'
with p.open('wb') as f:plistlib.dump(info,f)
print(app);print(archive)

subprocess.run(["codesign","--force","--deep","--sign","-",str(app)],check=True)
