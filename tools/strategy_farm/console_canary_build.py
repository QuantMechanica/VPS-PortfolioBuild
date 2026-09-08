"""Artifact-only EA11421 design build using the installed v4 frozen dependency set.

Does not invoke the factory compiler, alter the factory EX5, install, attach,
restart any terminal, change a preset, or interact with a trading account.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import subprocess

from tools.strategy_farm.console_design_build import (
    EA_SOURCE, INCLUDE_ROOT, METAEDITOR, digest, validate_destination,
)
from tools.strategy_farm.chart_panel_acceptance import DEPENDENCIES


FROZEN = Path('D:/QM/ftmo/compile_probe_console_v4_20260907_1913Z/MQL5')
FROZEN_EXPERT = FROZEN / 'Experts/QM_FTMO' / EA_SOURCE.with_suffix('.ex5').name
FROZEN_EX5_SHA256 = '5be0846344014fee1b87036e496cc6573cd13986cf840b7732afd40610895614'
OVERRIDES = (*DEPENDENCIES, 'QM_StrategyConsoleV2.mqh',
             'QM_ChartPresentationV2.mqh', 'QM_ChartPanelCompare.mqh')


def compile_canary(destination: Path) -> dict:
    root = validate_destination(destination)
    if digest(FROZEN_EXPERT) != FROZEN_EX5_SHA256:
        raise ValueError('Frozen dependency reference does not match the recorded installed v4 artifact')
    factory_ex5 = EA_SOURCE.with_suffix('.ex5')
    factory_before = digest(factory_ex5)
    source_before = digest(EA_SOURCE)
    frozen_inputs = {str(p.relative_to(FROZEN / 'Include')): digest(p)
                     for p in (FROZEN / 'Include').rglob('*') if p.is_file()}
    ui_inputs = {name: digest(INCLUDE_ROOT / name) for name in OVERRIDES}
    source = root / 'MQL5/Experts/QM_FTMO' / EA_SOURCE.name
    source.parent.mkdir(parents=True)
    shutil.copytree(FROZEN / 'Include', root / 'MQL5/Include')
    shutil.copy2(EA_SOURCE, source)
    for name in OVERRIDES:
        shutil.copy2(INCLUDE_ROOT / name, root / 'MQL5/Include/QM' / name)
    effective = {str(p.relative_to(root / 'MQL5/Include')): digest(p)
                 for p in (root / 'MQL5/Include').rglob('*') if p.is_file()}
    allowed = {'QM/' + name for name in OVERRIDES}
    expected_keys = {name.replace('\\', '/') for name in frozen_inputs} | allowed
    if {name.replace('\\', '/') for name in effective} != expected_keys:
        raise RuntimeError('Unexpected addition/removal in the isolated dependency snapshot')
    # Normalize Windows separators for the whitelist comparison.
    for relative, original in frozen_inputs.items():
        if relative.replace('\\', '/') not in allowed and effective.get(relative) != original:
            raise RuntimeError(f'Non-UI frozen dependency drifted: {relative}')
    if digest(source) != source_before or digest(EA_SOURCE) != source_before:
        raise RuntimeError('EA source changed while snapshotting')
    if any(digest(root / 'MQL5/Include/QM' / name) != expected or
           digest(INCLUDE_ROOT / name) != expected for name, expected in ui_inputs.items()):
        raise RuntimeError('UI sources changed while snapshotting')
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    result = subprocess.run(
        [str(METAEDITOR), '/portable', f'/compile:{source}', f'/include:{root / "MQL5"}', '/log'],
        cwd=METAEDITOR.parent, startupinfo=startup, creationflags=subprocess.CREATE_NO_WINDOW,
        timeout=60, capture_output=True,
    )
    log, binary = source.with_suffix('.log'), source.with_suffix('.ex5')
    log_text = log.read_text(encoding='utf-16') if log.exists() else ''
    summary = re.search(r'Result:\s+(\d+) errors?,\s+(\d+) warnings?', log_text)
    passed = bool(summary and summary.groups() == ('0', '0') and binary.is_file())
    factory_after = digest(factory_ex5)
    passed = passed and factory_after == factory_before
    receipt = {
        'schema': 'qm.console-canary-build/v1', 'utc': datetime.now(timezone.utc).isoformat(),
        'status': 'PASS' if passed else 'FAIL', 'ea_id': 11421, 'artifact_only': True,
        'installed': False, 'terminal_started': False, 'factory_invoked': False,
        'factory_ex5_unchanged': factory_before == factory_after,
        'factory_ex5_sha256': factory_after, 'frozen_reference': str(FROZEN),
        'frozen_reference_ex5_sha256': FROZEN_EX5_SHA256,
        'source': str(source), 'source_sha256': digest(source),
        'binary': str(binary) if binary.exists() else None,
        'binary_sha256': digest(binary) if binary.exists() else None,
        'compile_log': str(log), 'returncode': result.returncode,
        'summary': summary.group(0) if summary else None,
        'ui_overrides': ui_inputs, 'non_ui_dependencies_match_captured_snapshot': True,
        'historical_v4_include_binding': 'not_attested: historical v4 receipt did not hash the Include tree',
        'effective_include_hashes': effective,
    }
    (root / 'build_receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact-root', required=True, type=Path)
    args = parser.parse_args()
    receipt = compile_canary(args.artifact_root)
    print(json.dumps({k: v for k, v in receipt.items() if k != 'effective_include_hashes'}, indent=2))
    return 0 if receipt['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
