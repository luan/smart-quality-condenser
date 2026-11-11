#!/usr/bin/env python3
"""Build a deterministic release archive without tests or source artwork."""
import hashlib
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

root = Path(__file__).resolve().parents[1]
info = json.loads((root / 'info.json').read_text())
prefix = f"{info['name']}_{info['version']}"
destination = root / 'dist' / f'{prefix}.zip'
destination.parent.mkdir(exist_ok=True)
with ZipFile(destination, 'w') as archive:
    for source in sorted(root.rglob('*')):
        relative = source.relative_to(root)
        if not source.is_file() or relative.parts[0] in {'.git', '.data', 'dist', 'tests', 'tools'}:
            continue
        if source.suffix not in {'.lua', '.json', '.cfg', '.png', '.ogg', '.txt', '.md'} and source.name != 'LICENSE':
            continue
        entry = ZipInfo(f'{prefix}/{relative.as_posix()}')
        entry.compress_type = ZIP_DEFLATED
        entry.external_attr = 0o100644 << 16
        archive.writestr(entry, source.read_bytes())
print(destination)
print('sha256', hashlib.sha256(destination.read_bytes()).hexdigest())
