"""Build immutable no-trade V1/V2 visual fixtures, never start a terminal.

All outputs stay under a fresh D:/QM/ftmo/compile_probe_* directory. Installation
and GUI attachment are intentionally separate, explicitly pinned operations.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

from tools.strategy_farm.chart_panel_acceptance import DEPENDENCIES, INCLUDE_ROOT, REPO


METAEDITOR = Path('C:/Program Files/FTMO Global Markets MT5 Terminal/metaeditor64.exe')
ALLOWED_ROOT = Path('D:/QM/ftmo')
SOURCE = REPO / 'framework/tests/mql5/QM_Console_Visual_QA.mq5'
EA_SOURCE = REPO / 'framework/EAs/QM5_11421_ohlc-daily-squeeze-reversal-d1/QM5_11421_ohlc-daily-squeeze-reversal-d1.mq5'
NEWS_TESTS = REPO / 'framework/tests/mql5/QM11421_ConsoleNews_selftests.mqh'


def exact_news_helpers(text: str) -> str:
    """Copy only the three pure production observation helpers into the fixture."""
    extracted = []
    for name in ('QM11421_ConsoleNewsKeyMatches', 'QM11421_ConsoleNewsObservation', 'QM11421_ConsoleGateAlerts'):
        match = re.search(r'\b(?:QM_ConsoleGateState|void|bool)\s+' + name + r'\s*\([^)]*\)\s*\{', text)
        if not match:
            raise ValueError(f'Missing exact production helper: {name}')
        depth = 0
        for index in range(match.end() - 1, len(text)):
            depth += (text[index] == '{') - (text[index] == '}')
            if depth == 0:
                extracted.append(text[match.start():index + 1])
                break
        else:
            raise ValueError(f'Unbalanced production helper: {name}')
    return '#include <QM/QM_ConsoleModel.mqh>\n\n' + '\n\n'.join(extracted) + '\n'


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_destination(path: Path) -> Path:
    target = path.resolve()
    if target.parent != ALLOWED_ROOT.resolve() or not target.name.startswith('compile_probe_'):
        raise ValueError('Expected a direct fresh D:/QM/ftmo/compile_probe_* directory')
    if target.exists():
        raise FileExistsError(target)
    return target


def compile_fixture(variant: str, artifact_root: Path) -> dict:
    if variant not in ('v1', 'v2'):
        raise ValueError('Only v1/v2 visual fixtures are supported')
    root = validate_destination(artifact_root)
    includes = list(DEPENDENCIES)
    if variant == 'v2':
        includes += ['QM_StrategyConsoleV2.mqh', 'QM_ChartPresentationV2.mqh', 'QM_ChartPanelCompare.mqh']
    inputs = [SOURCE, REPO / 'framework/tests/mql5/QM_ConsoleData_selftests.mqh']
    if variant == 'v2':
        inputs += [REPO / 'framework/tests/mql5/QM_ChartPresentationV2_selftests.mqh']
    inputs += [INCLUDE_ROOT / name for name in includes]
    inputs += [EA_SOURCE, NEWS_TESTS]
    if not all(path.is_file() for path in inputs) or not METAEDITOR.is_file():
        raise FileNotFoundError('A required source, include, or MetaEditor is missing')
    input_hashes = {str(path): digest(path) for path in inputs}
    expert = root / 'MQL5/Experts/QM_Console_Visual_QA.mq5'
    expert.parent.mkdir(parents=True)
    include_dir = root / 'MQL5/Include/QM'
    include_dir.mkdir(parents=True)
    for name in includes:
        shutil.copy2(INCLUDE_ROOT / name, include_dir / name)
    shutil.copy2(inputs[1], expert.parent / inputs[1].name)
    if variant == 'v2':
        shutil.copy2(inputs[2], expert.parent / inputs[2].name)
    shutil.copy2(NEWS_TESTS, expert.parent / NEWS_TESTS.name)
    generated_helpers = exact_news_helpers(EA_SOURCE.read_text(encoding='utf-8'))
    helper_path = expert.parent / 'QM11421_ConsoleNews_helpers.mqh'
    helper_path.write_text(generated_helpers, encoding='utf-8')
    source_text = SOURCE.read_text(encoding='utf-8')
    source_text = '#define QM_CONSOLE_NEWS_SELFTEST\n' + source_text
    if variant == 'v2':
        source_text = '#define QM_CONSOLE_DESIGN_V2\n#define QM_CONSOLE_DESIGN_COMPARE\n' + source_text
    expert.write_text(source_text, encoding='utf-8')
    # A concurrent source change invalidates the input claim before compilation.
    if any(digest(path) != input_hashes[str(path)] for path in inputs):
        raise RuntimeError('Sources changed while snapshotting; use a fresh build')
    for name in includes:
        if digest(include_dir / name) != input_hashes[str(INCLUDE_ROOT / name)]:
            raise RuntimeError(f'Copied include differs from captured source: {name}')
    local_tests = [inputs[1], NEWS_TESTS]
    if variant == 'v2':
        local_tests.append(inputs[2])
    for path in local_tests:
        if digest(expert.parent / path.name) != input_hashes[str(path)]:
            raise RuntimeError(f'Copied selftests differ from captured source: {path.name}')
    if expert.read_text(encoding='utf-8') != source_text:
        raise RuntimeError('Generated fixture source differs from the build recipe')
    if helper_path.read_text(encoding='utf-8') != generated_helpers:
        raise RuntimeError('Generated news helpers differ from the exact production bodies')
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    result = subprocess.run(
        [str(METAEDITOR), '/portable', f'/compile:{expert}', f'/include:{root / "MQL5"}', '/log'],
        cwd=METAEDITOR.parent, startupinfo=startup, creationflags=subprocess.CREATE_NO_WINDOW,
        capture_output=True, timeout=60,
    )
    log, binary = expert.with_suffix('.log'), expert.with_suffix('.ex5')
    log_text = log.read_text(encoding='utf-16') if log.exists() else ''
    summary = re.search(r'Result:\s+(\d+) errors?,\s+(\d+) warnings?', log_text)
    passed = bool(summary and summary.groups() == ('0', '0') and binary.is_file())
    receipt = {
        'schema': 'qm.console-design-build/v1', 'variant': variant,
        'utc': datetime.now(timezone.utc).isoformat(), 'status': 'PASS' if passed else 'FAIL',
        'artifact_only': True, 'terminal_started': False, 'installed': False,
        'synthetic_no_trade_fixture': True, 'returncode': result.returncode,
        'input_hashes': input_hashes, 'source': str(expert), 'source_sha256': digest(expert),
        'binary': str(binary) if binary.exists() else None,
        'binary_sha256': digest(binary) if binary.exists() else None,
        'compile_log': str(log), 'summary': summary.group(0) if summary else None,
        'snapshot_hashes': {str(path.relative_to(root)): digest(path)
                            for path in (root / 'MQL5').rglob('*') if path.is_file()},
    }
    (root / 'build_receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--variant', required=True, choices=['v1', 'v2'])
    parser.add_argument('--artifact-root', required=True, type=Path)
    args = parser.parse_args()
    result = compile_fixture(args.variant, args.artifact_root)
    print(json.dumps(result, indent=2))
    return 0 if result['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
