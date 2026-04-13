#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: package.sh <version> [output-dir]}"
output_dir="${2:-dist}"
artifact_name="godot-bridge-plugin-${version}.zip"

mkdir -p "$output_dir"
rm -f "$output_dir/$artifact_name"

python3 - <<'PY' "$output_dir/$artifact_name"
import sys
import zipfile
from pathlib import Path

archive_path = Path(sys.argv[1])
root = Path("addons")

with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as zf:
    for path in sorted(root.rglob("*")):
        if path.is_file():
            zf.write(path, path.as_posix())
PY

printf '%s\n' "$output_dir/$artifact_name"
