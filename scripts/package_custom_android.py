#!/usr/bin/env python3
"""Replace only the ARM64 engine in a fresh unsigned APK; never signs it."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from zipfile import ZipFile

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--baseline', type=Path, required=True)
p.add_argument('--engine', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--zipalign', required=True)
a = p.parse_args()
if a.output.resolve() == a.baseline.resolve():
    p.error('Output must not overwrite baseline')
engine_entry = 'lib/arm64-v8a/libgodot_android.so'
a.output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory() as t:
    unaligned = Path(t) / 'custom.apk'
    with ZipFile(a.baseline) as source, ZipFile(unaligned, 'w') as dest:
        if engine_entry not in source.namelist():
            p.error('Baseline is missing ARM64 Godot engine')
        for info in source.infolist():
            data = a.engine.read_bytes() if info.filename == engine_entry else source.read(info)
            dest.writestr(copy.copy(info), data, compresslevel=9)
    subprocess.run([a.zipalign, '-P', '16', '-f', '4', str(unaligned), str(a.output)], check=True)
with ZipFile(a.baseline) as source, ZipFile(a.output) as dest:
    assert source.namelist() == dest.namelist(), 'ZIP entry list changed'
    changed = [n for n in source.namelist() if source.read(n) != dest.read(n)]
    assert changed == [engine_entry], changed
    native_bytes = sum(i.file_size for i in dest.infolist() if i.filename.startswith('lib/'))
report = dict(apk_bytes=a.output.stat().st_size, native_bytes=native_bytes,
              apk_plus_extracted_native_estimate=a.output.stat().st_size + native_bytes,
              sha256=hashlib.sha256(a.output.read_bytes()).hexdigest(),
              engine_sha256=hashlib.sha256(a.engine.read_bytes()).hexdigest(), changed_entries=changed)
print(json.dumps(report, indent=2))
