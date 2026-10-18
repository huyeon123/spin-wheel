#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root = Path.cwd()
files = {
    'build/windows/SpinWheel.exe': 'SpinWheel/SpinWheel.exe',
    'LICENSE': 'SpinWheel/LICENSE',
    'assets/FONT-LICENSE.txt': 'SpinWheel/FONT-LICENSE.txt',
    'assets/GODOT-COPYRIGHT.txt': 'SpinWheel/GODOT-COPYRIGHT.txt',
    'assets/GODOT-LICENSE.txt': 'SpinWheel/GODOT-LICENSE.txt',
    'assets/GODOT-COPYRIGHT.txt': 'SpinWheel/GODOT-COPYRIGHT.txt',
    'README.md': 'SpinWheel/README.md',
    'docs/BUILD.md': 'SpinWheel/docs/BUILD.md',
}
with ZipFile(root / 'build/SpinWheel-Windows-x86_64.zip', 'w', ZIP_DEFLATED, compresslevel=6) as bundle:
    for source, destination in files.items():
        bundle.write(root / source, destination)
PY
