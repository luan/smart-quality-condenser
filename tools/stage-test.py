#!/usr/bin/env python3
"""Stage an isolated native test; never modifies the supplied mod directory or save."""
import argparse
import json
from pathlib import Path
import shlex
import shutil
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--mods', type=Path, required=True, help='Installed mod directory, used read-only')
parser.add_argument('--data', type=Path, required=True, help='Factorio data directory')
parser.add_argument('--save', type=Path, help='Test migration from an existing 0.1.0 save instead of fresh logistics')
parser.add_argument('--output', type=Path, help='New isolated stage directory')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
info = json.loads((root / 'info.json').read_text())
name = info['name'] + '_' + info['version']
kind = 'migration' if args.save else 'native'
stage = (args.output or root / '.data' / f'builtin-{info["version"]}' / kind).resolve()
mods = stage / 'mods'
if mods.exists():
    raise SystemExit(f'Test stage already exists: {mods}. Choose a new --output.')
mods.mkdir(parents=True)
(stage / 'write').mkdir(exist_ok=True)
source_mods = args.mods.resolve()
for source in source_mods.glob('*.zip'):
    if source.name.startswith(info['name'] + '_'):
        continue
    if args.save or source.name.startswith('beacon-interface_'):
        (mods / source.name).symlink_to(source)
if not list(mods.glob('beacon-interface_*.zip')):
    raise SystemExit('The installed mod directory must contain beacon-interface')
with zipfile.ZipFile(root / 'dist' / f'{name}.zip') as archive:
    archive.extractall(mods)
mod = mods / name
(mod / 'tests').mkdir()
if args.save:
    for filename in ['mod-list.json', 'mod-settings.dat']:
        shutil.copy2(source_mods / filename, mods / filename)
    shutil.copy2(root / 'tests/builtin-migration.lua', mod / 'tests/builtin-migration.lua')
    control = mod / 'control.lua'
    text = control.read_text().replace('local TargetsGui = require("scripts.targets-gui")', 'local TargetsGui = require("scripts.targets-gui")\nlocal MigrationQA = require("tests.builtin-migration")')
    text = text.replace('  Smart.on_configuration_changed()', '  local before=MigrationQA.before()\n  Smart.on_configuration_changed()\n  MigrationQA.after(before,Smart,TargetsGui)')
    control.write_text(text)
else:
    for source, dest in [('builtin.lua', 'builtin.lua'), ('native/blueprint.lua', 'blueprint.lua')]:
        shutil.copy2(root / 'tests' / source, mod / 'tests' / dest)
    with (mod / 'control.lua').open('a') as control:
        control.write('\nrequire("tests.builtin")(Smart, TargetsGui, initialize_base, Handler)\n')
    shutil.copytree(root / 'tests/native', mods / 'smart-quality-condenser-qa')
    (mods / 'smart-quality-condenser-qa' / 'control.lua').write_text('')
    enabled = ['base', 'quality', 'space-age', 'elevated-rails', 'beacon-interface', info['name'], 'smart-quality-condenser-qa']
    (mods / 'mod-list.json').write_text(json.dumps({'mods': [{'name': mod_name, 'enabled': True} for mod_name in enabled]}))
config = stage / 'config.ini'
config.write_text(f'[path]\nread-data={args.data.resolve()}\nwrite-data={stage / "write"}\n[other]\ncheck-updates=false\n')
command = ['factorio', '--config', str(config), '--mod-directory', str(mods)]
if args.save:
    print(shlex.join(command + ['--benchmark', str(args.save.resolve()), '--benchmark-ticks', '1', '--benchmark-runs', '1']))
else:
    save = str(stage / 'qa.zip')
    print(shlex.join(command + ['--create', save]))
    print(shlex.join(command + ['--test-save', save, '--test-ticks', '42130', '--test-arg', 'native']))
