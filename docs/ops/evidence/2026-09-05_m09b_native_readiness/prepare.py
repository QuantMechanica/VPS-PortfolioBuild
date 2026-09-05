"""M09-B bounded package staging; never starts MT5 or changes account config."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sys
from pathlib import Path

REPO = Path('C:/QM/repo')
LANE = Path('D:/QM/mt5/FTMO_STREAM1')
MANIFEST = Path('D:/QM/reports/ftmo_trial/sets_20260905_055750/manifest.json')
MANIFEST_SHA = 'db442c0095b7a9bbac7cdcbf898036486a6f2e4d3af90f057660fbca3430b94c'
OUT = Path(__file__).resolve().parent


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    if sha(MANIFEST) != MANIFEST_SHA:
        raise RuntimeError('Immutable target manifest changed')
    sys.path.insert(0, str(REPO / 'tools/strategy_farm'))
    from ftmo_lane_runner import scan_terminal_processes, _safe_profile_identity
    processes = scan_terminal_processes()
    # A process-probe failure is raised by the existing governed reader.
    for row in processes:
        if 'ftmo_stream1' in json.dumps(row).lower():
            raise RuntimeError('Isolated lane is active; defer package installation')
    profile = _safe_profile_identity(LANE / 'Config/common.ini')
    if profile.get('experts_enabled_raw_is_zero') is not True:
        raise RuntimeError('Isolated lane must already have Experts disabled')
    protected = [LANE / 'Config' / name for name in
                 ('common.ini', 'accounts.dat', 'servers.dat')]
    before = {str(path): sha(path) for path in protected}
    target = json.loads(MANIFEST.read_text(encoding='utf-8'))
    if len(target['sets']) != 8:
        raise RuntimeError('Expected exactly eight bound candidates')
    copies = []
    for row in target['sets']:
        for kind, key, digest_key, directory in (
            ('candidate', 'binary', 'binary_sha256', 'MQL5/Experts/QM/M09B'),
            ('trial_set', 'output', 'output_sha256', 'MQL5/Profiles/Presets/M09B'),
        ):
            source = Path(row[key])
            destination = LANE / directory / source.name
            destination.resolve().relative_to(LANE.resolve())
            if sha(source) != row[digest_key]:
                raise RuntimeError(f'Input hash mismatch: {source}')
            if destination.exists() and sha(destination) != row[digest_key]:
                raise RuntimeError(f'Refusing to overwrite different bytes: {destination}')
            copies.append(dict(kind=kind, ea_id=row['ea_id'], source=str(source),
                               destination=str(destination), sha256=row[digest_key]))
    receipt = OUT / 'install_manifest.json'
    if args.install and receipt.exists():
        raise RuntimeError('Evidence exists; use a new reviewed run, never overwrite')
    if args.install:
        for row in copies:
            destination = Path(row['destination'])
            destination.parent.mkdir(parents=True, exist_ok=True)
            if not destination.exists():
                # Exclusive creation; an intervening writer cannot be overwritten.
                with destination.open('xb') as handle:
                    handle.write(Path(row['source']).read_bytes())
            if sha(destination) != row['sha256']:
                raise RuntimeError(f'Installed hash mismatch: {destination}')
            row['verified_installed'] = True
    after = {str(path): sha(path) for path in protected}
    if before != after:
        raise RuntimeError('Account configuration changed during observation')
    result = dict(
        schema='qm.m09b-readiness-install/v1',
        created_at_utc=dt.datetime.now(dt.timezone.utc).isoformat(),
        task_id='7cc4ab4c-ae16-4eb7-9409-4ce5ff179d77',
        mode='INSTALLED' if args.install else 'DRY_RUN',
        manifest_path=str(MANIFEST), manifest_sha256=MANIFEST_SHA,
        lane=str(LANE), account_config_unchanged=True, protected_hashes=after,
        files=copies, collector_compiled=False, terminal_started=False,
        autotrading_touched=False, exact_binaries_recompiled=False,
        native_scenario_execution=False, native_testable_count=0,
        native_untestable_count=8, pipeline_verdict=None,
        blockers=['GOVERNED_COLLECTOR_COMPILE_EA_LABEL_INVALID',
                  'EXACT_BINARIES_HAVE_NO_NEW_RESERVATION_EVENT_INSTRUMENTATION',
                  'BOUND_SHARED_ACCOUNT_SCENARIO_ADAPTER_ABSENT',
                  'EXACT_PROFILE_ACCOUNT_UNPROVEN',
                  'NATIVE_EXECUTION_FORBIDDEN_IN_THIS_SCHEDULED_CYCLE'],
    )
    if args.install:
        with receipt.open('x', encoding='utf-8') as handle:
            json.dump(result, handle, indent=2)
            handle.write('\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
