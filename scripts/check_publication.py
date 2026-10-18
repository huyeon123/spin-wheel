#!/usr/bin/env python3
"""Reject tracked files outside the reviewed source publication allowlist."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
allowed = set((root / ".publication-allowlist").read_text().splitlines())
tracked = set(subprocess.check_output(["git", "ls-files"], cwd=root, text=True).splitlines())
extra = sorted(tracked - allowed)
missing = sorted(allowed - tracked)
if extra or missing:
    raise SystemExit("Publication allowlist mismatch\nUnexpected: " + repr(extra) + "\nMissing: " + repr(missing))
print(f"Publication allowlist OK: {len(tracked)} source files")
