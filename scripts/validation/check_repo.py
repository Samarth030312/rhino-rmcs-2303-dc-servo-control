#!/usr/bin/env python3
"""Repository hygiene checks that need no MATLAB licence (run in CI and locally).

- SOURCE_REGISTER.csv parses and has the expected columns and unique IDs.
- No copyrighted manuals, recordings or raw data are tracked by git.
- Every status word used in params.m is in the knowledge-base vocabulary.
"""
import csv, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
errors = []

cols = ['source_id', 'title', 'source_type', 'manufacturer_or_author', 'version_or_date',
        'local_path', 'url', 'authority', 'status', 'notes']
with open(ROOT / 'docs/knowledge-base/SOURCE_REGISTER.csv', newline='') as f:
    rows = list(csv.DictReader(f))
    if rows and list(rows[0].keys()) != cols:
        errors.append(f'SOURCE_REGISTER columns are {list(rows[0].keys())}')
ids = [r['source_id'] for r in rows]
if len(ids) != len(set(ids)):
    errors.append('duplicate source_id in SOURCE_REGISTER.csv')

tracked = subprocess.run(['git', '-C', str(ROOT), 'ls-files'], capture_output=True, text=True,
                         check=True).stdout.split()
for t in tracked:
    if t.startswith('docs/references/downloads/') and not t.endswith('.gitkeep'):
        errors.append(f'copyrighted download tracked: {t}')
    if re.search(r'\.(mp4|avi|mov|mkv)$', t):
        errors.append(f'video tracked: {t}')

vocab = {'VERIFIED_FROM_MANUAL', 'MEASURED', 'TESTED', 'ESTIMATED', 'ASSUMED', 'UNVERIFIED'}
pf = ROOT / 'matlab/functions/+servolab/+motor/params.m'
params = pf.read_text() if pf.exists() else ''
for _name, _unit, s in re.findall(r"add\('([^']+)',[^'\n]*'([^']*)',\s*'([^']*)'", params):
    if s not in vocab:
        errors.append(f'params.m uses unknown status {s}')

for e in errors:
    print('ERROR:', e)
print('check_repo:', 'FAILED' if errors else 'OK', f'({len(rows)} sources, {len(tracked)} tracked files)')
sys.exit(1 if errors else 0)
