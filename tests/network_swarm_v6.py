"""Exercise all twelve dedicated slots with independently launched native clients."""
import os, subprocess, time, json, re, socket, errno
from pathlib import Path
root=Path(__file__).resolve().parents[1]
binary=root/'build/linux/ASHLINE.x86_64'
env=os.environ.copy()
for key,tail in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:env[key]=str(root/'.runtime'/tail)
server_log=root/'tests/native_server_v6.log'
handles=[];processes=[]
try:
 h=server_log.open('w');handles.append(h)
 server=subprocess.Popen([str(binary),'--headless','--','--server'],stdout=h,stderr=subprocess.STDOUT,env=env,cwd=root)
 processes.append(server)
 deadline=time.monotonic()+15
 while time.monotonic()<deadline:
  # Release builds buffer stdout; test the bound ENet socket instead of a log line.
  probe=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
  try:probe.bind(('0.0.0.0',27841))
  except OSError as error:
   if error.errno==errno.EADDRINUSE:probe.close();break
   raise
  finally:probe.close()
  if server.poll() is not None:raise RuntimeError('Server exited during startup')
  time.sleep(.1)
 else:raise RuntimeError('Server startup timeout')
 for i in range(12):
  h=(root/f'tests/native_client_v6_{i}.log').open('w');handles.append(h)
  processes.append(subprocess.Popen([str(binary),'--headless','--','--net-test'],stdout=h,stderr=subprocess.STDOUT,env=env,cwd=root))
 deadline=time.monotonic()+40
 while any(p.poll() is None for p in processes[1:]) and time.monotonic()<deadline:time.sleep(.1)
 clients=[]
 for i,p in enumerate(processes[1:]):
  text=(root/f'tests/native_client_v6_{i}.log').read_text()
  match=re.search(r'NETWORK_OK snapshots=(\d+) slot=(\d+) actors=(\d+).*?predicted_shots=(\d+).*?acknowledged=(\d+) pending=(\d+)',text)
  clients.append({'client':i,'exit_code':p.poll(),'ok':p.poll()==0 and bool(match), 'snapshots':int(match[1]) if match else 0,'slot':int(match[2]) if match else -1,'actors':int(match[3]) if match else 0,'shots':int(match[4]) if match else 0,'acknowledged':int(match[5]) if match else 0,'pending':int(match[6]) if match else -1})
 report={'success':all(c['ok'] for c in clients) and {c['slot'] for c in clients}==set(range(12)), 'clients':clients}
 (root/'tests/native_network_v6_report.json').write_text(json.dumps(report,indent=2))
 print(json.dumps(report,indent=2))
 if not report['success']:raise SystemExit(1)
finally:
 for p in processes:
  if p.poll() is None:p.terminate()
 for p in processes:
  try:p.wait(timeout=4)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for h in handles:h.close()
