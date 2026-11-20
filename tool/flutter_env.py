#!/usr/bin/env python3
"""Run Flutter with compile-time Supabase values loaded from the local .env file.

Usage:
  python3 tool/flutter_env.py run -d chrome
  python3 tool/flutter_env.py build web --release
"""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / ".env"


def read_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        if key:
            values[key] = value
    return values


local_values = read_env(ENV_FILE)
url = os.environ.get("SUPABASE_URL") or local_values.get("SUPABASE_URL", "")
publishable_key = os.environ.get("SUPABASE_PUBLISHABLE_KEY") or local_values.get("SUPABASE_PUBLISHABLE_KEY", "")

if not sys.argv[1:]:
    print("Usage: python3 tool/flutter_env.py <flutter command> [arguments...]")
    raise SystemExit(2)

command = sys.argv[1]
args = ["flutter", *sys.argv[1:]]
if command in {"run", "build"}:
    if url:
        args.append(f"--dart-define=SUPABASE_URL={url}")
    if publishable_key:
        args.append(f"--dart-define=SUPABASE_PUBLISHABLE_KEY={publishable_key}")

raise SystemExit(subprocess.call(args, cwd=ROOT))
