"""Read-only M09 exact-binary preflight and explicitly synthetic reader replay.

This harness has no terminal execution or account mutation path. A scenario
without native, exact-binary execution evidence is UNTESTABLE, never a PASS.
All outputs are exclusive-create under this canonical evidence directory.
"""
import datetime as dt
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, 'C:/QM/repo')
from tools.strategy_farm import ftmo_lane_runner as lane
from tools.strategy_farm.portfolio import ftmo_trial_telemetry as telemetry

ROOT = Path(__file__).resolve().parent
MANIFEST = Path('D:/QM/reports/ftmo_trial/sets_20260905_055750/manifest.json')
SCENARIOS = {
    'reservation_activation': 'Show reservation acquired before order submission, released after reject/fill; bind exact binary and input activation.',
    'simultaneous_entries': 'Synchronize at least two candidate entry requests against one account budget; prove atomic refusal above remaining risk.',
    'pending_orders': 'Include pending-order stop risk and reservation in admission, cancellation, fill and orphan-recovery paths.',
    'restart': 'Restart only the isolated harness; reconcile existing positions, pending orders and reservations before a new entry.',
    'disconnect': 'Disconnect only the isolated harness; block unsafe entries and expose telemetry gaps/reconciliation on reconnect.',
    'foreign_positions': 'Introduce an independently identified non-roster position; include its risk in the same account-wide budget.',
    'measurement_resolution': 'Prove exact collector binary, UTC/Prague anchors and observed event cadence on the target account.',
    'intraday_trough': 'Capture a native equity trough between M5 endpoints and quantify unobserved loss bounds.',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def write(name, obj):
    path = ROOT / name
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(obj, stream, indent=2, sort_keys=True, allow_nan=False)
        stream.write('\n')


def main():
    data = MANIFEST.read_bytes()
    manifest = json.loads(data)
    with (ROOT / 'target_manifest.json').open('xb') as stream:
        stream.write(data)
    processes = lane.scan_terminal_processes()
    observations, native_streams = [], []
    for name in sorted(lane.LANE_ROOTS):
        root = lane.LANE_ROOTS[name]
        try:
            provision = lane.build_provision_receipt(name, process_rows=processes)
            observation = {'lane': name, 'inspection': provision}
        except (lane.FtmoLaneError, OSError) as exc:
            observation = {'lane': name, 'inspection_error': str(exc)}
        files = list((root / 'MQL5/Experts').rglob('*.ex5'))
        candidates = {int(row['ea_id']): [] for row in manifest['sets']}
        for path in files:
            for row in manifest['sets']:
                if path.name == Path(row['binary']).name:
                    candidates[int(row['ea_id'])].append({'path': str(path), 'sha256': sha(path),
                                                        'matches_target': sha(path) == row['binary_sha256']})
        observation['candidate_binaries_present'] = candidates
        observation['collector_binaries'] = [{'path': str(p), 'sha256': sha(p)} for p in files if p.name == 'QM_FTMO_TrialTelemetry.ex5']
        streams = list((root / 'MQL5/Files').rglob('trial_telemetry_raw.jsonl'))
        observation['native_telemetry_streams'] = [{'path': str(p), 'sha256': sha(p)} for p in streams]
        native_streams.extend(streams)
        observations.append(observation)
    write('lane_inspection.json', {'schema': 'qm.m09-lane-observation/v1', 'created_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
                                 'inspection_only': True, 'admission_receipt': False, 'lanes': observations,
                                 'cli_destination_refusal': 'The provision CLI accepts only D:/QM/reports/state. No receipt was written there; pure inspection was retained as evidence only.'})
    targets = []
    for row in manifest['sets']:
        target = dict(row)
        target['current_binary_sha256'] = sha(Path(row['binary']))
        target['current_set_sha256'] = sha(Path(row['output']))
        target['binary_matches_manifest'] = target['current_binary_sha256'] == row['binary_sha256']
        target['set_matches_manifest'] = target['current_set_sha256'] == row['output_sha256']
        try:
            lane.validate_set_guardrails(Path(row['output']).read_text(encoding='utf-8-sig'))
            target['backtest_runner_admission'] = 'ACCEPTED'
        except lane.FtmoLaneError as exc:
            target['backtest_runner_admission'] = 'REFUSED'
            target['backtest_runner_reason'] = str(exc)
        targets.append(target)
    write('target_bindings.json', {'manifest_path': str(MANIFEST), 'manifest_sha256': sha(MANIFEST), 'targets': targets})
    matrix = []
    for name, criterion in SCENARIOS.items():
        row = {'scenario': name, 'status': 'UNTESTABLE', 'acceptance': criterion,
               'native_execution_performed': False, 'exact_binary_execution_proven': False,
               'blockers': ['NO_BOUND_SHARED_ACCOUNT_SCENARIO_EXECUTION_RECEIPT',
                            'NO_NATIVE_TARGET_COLLECTOR_STREAM',
                            'BACKTEST_LANE_CANNOT_ADMIT_PERCENT_RISK_TRIAL_SETS'],
               'evidence': ['lane_inspection.json', 'target_bindings.json']}
        matrix.append(row)
    write('scenario_matrix.json', {'schema': 'qm.m09-exact-binary-scenarios/v1',
                                  'task_id': '3d2c9e2f-59a0-4bf7-8933-a3f2b2738721',
                                  'target_count': len(targets), 'scenarios': matrix,
                                  'summary': {'PASS': 0, 'FAIL': 0, 'UNTESTABLE': len(matrix)},
                                  'native_streams_found': len(native_streams)})
    # Reader exercise is explicitly synthetic and grants no scenario PASS.
    fixture = Path('D:/QM/reports/portfolio/ftmo_trial_telemetry_dryrun_20260905_055307/tester_generated_raw.jsonl')
    with (ROOT / 'synthetic_reader_fixture.jsonl').open('xb') as stream:
        stream.write(fixture.read_bytes())
    report = telemetry.build_report(ROOT / 'synthetic_reader_fixture.jsonl', maximum_sample_gap_seconds=90)
    write('synthetic_reader_report.json', {'evidence_class': 'SYNTHETIC_READER_FIXTURE_ONLY',
                                         'exact_candidate_binaries_executed': False, 'report': report})
    write('code_bindings.json', {str(p): sha(p) for p in [Path(lane.__file__), Path(telemetry.__file__), Path(__file__)]})
    assert len(targets) == 8 and len(matrix) == 8
    assert report['ingestion']['deduplicated_samples'] == 2881
    assert report['challenge_proof'] is False
    print(json.dumps({'scenario_summary': {'PASS': 0, 'FAIL': 0, 'UNTESTABLE': 8},
                      'binary_matches': sum(t['binary_matches_manifest'] for t in targets),
                      'trial_set_backtest_refusals': sum(t['backtest_runner_admission'] == 'REFUSED' for t in targets),
                      'native_streams': len(native_streams), 'reader_fixture_samples': 2881}))


if __name__ == '__main__':
    main()
