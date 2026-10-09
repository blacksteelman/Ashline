"""Dedicated server + native clients from the editor binary (no export needed).
python3 tests/network_local_v8.py [clients]"""
import os, subprocess, time, re, sys, json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
count = int(sys.argv[1]) if len(sys.argv) > 1 else 3
cmd = ['godot', '--headless', '--path', str(root)]
logs = root / 'build' / 'net_v8'; logs.mkdir(parents=True, exist_ok=True)
procs = []
try:
    server = subprocess.Popen(cmd + ['--', '--server'], stdout=(logs / 'server.log').open('w'), stderr=subprocess.STDOUT)
    procs.append(server); time.sleep(6)
    for i in range(count):
        procs.append(subprocess.Popen(cmd + ['--', '--net-test'], stdout=(logs / f'client_{i}.log').open('w'), stderr=subprocess.STDOUT))
    deadline = time.monotonic() + 90
    while any(p.poll() is None for p in procs[1:]) and time.monotonic() < deadline:
        time.sleep(.2)
    results = []
    for i, p in enumerate(procs[1:]):
        text = (logs / f'client_{i}.log').read_text()
        m = re.search(r'NETWORK_OK snapshots=(\d+) slot=(\d+).*?predicted_shots=(\d+).*?acknowledged=(\d+) pending=(\d+)', text)
        errors = [l for l in text.splitlines() if 'SCRIPT ERROR' in l]
        results.append({'client': i, 'exit': p.poll(), 'ok': p.poll() == 0 and bool(m) and not errors,
                        'slot': int(m[2]) if m else -1, 'shots': int(m[3]) if m else 0, 'acknowledged': int(m[4]) if m else 0,
                        'errors': errors[:3]})
    server_errors = [l for l in (logs / 'server.log').read_text().splitlines() if 'SCRIPT ERROR' in l]
    report = {'success': all(r['ok'] for r in results) and not server_errors, 'clients': results, 'server_errors': server_errors[:5]}
    print(json.dumps(report, indent=1))
    sys.exit(0 if report['success'] else 1)
finally:
    for p in procs:
        if p.poll() is None:
            p.kill()
