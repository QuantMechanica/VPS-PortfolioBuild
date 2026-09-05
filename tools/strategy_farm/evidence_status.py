"""Read-only, conservative Q08 evidence projection. Writes only JSON to stdout."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / 'framework/scripts') not in sys.path:
    sys.path.insert(0, str(ROOT / 'framework/scripts'))
from q08_davey import dsr_v2


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def check_binding(path, expected, label):
    if not path or not expected or not dsr_v2.SHA.fullmatch(str(expected)):
        return {'label': label, 'status': 'missing'}
    try:
        actual = sha(path)
    except OSError:
        return {'label': label, 'status': 'missing', 'path': str(path)}
    return {'label': label, 'status': 'current' if actual == expected else 'stale',
            'path': str(path), 'expected_sha256': expected, 'actual_sha256': actual}


def inspect_bindings(aggregate):
    stream = aggregate.get('portfolio_stream') or {}
    baseline = aggregate.get('baseline_run') or {}
    bindings = [check_binding(stream.get('durable_path') or stream.get('path'),
                             stream.get('durable_sha256') or stream.get('content_sha256'), 'stream')]
    for key in ('summary', 'report', 'mq5', 'ex5', 'setfile'):
        bindings.append(check_binding(baseline.get('baseline_' + key + '_path'),
                                      baseline.get('baseline_' + key + '_sha256'), key))
    state = 'stale' if any(x['status'] == 'stale' for x in bindings) else (
        'missing' if any(x['status'] == 'missing' for x in bindings) else 'current')
    return state, bindings


def project(path, *, v2_result=None):
    path = Path(path)
    raw = path.read_bytes()
    aggregate = json.loads(raw.decode('utf-8-sig'))
    binding, receipts = inspect_bindings(aggregate)
    valid_shape = aggregate.get('evidence_schema') == 'q08_aggregate/v2' and isinstance(aggregate.get('sub_gates'), list)
    n = aggregate.get('n_trades')
    technical = 'invalid' if not valid_shape or type(n) is not int or n <= 0 else (
        'valid' if binding == 'current' else 'unavailable')
    economic = 'inconclusive'
    gross, cost = aggregate.get('gross_total'), aggregate.get('commission_total')
    if (isinstance(gross, (float, int)) and not isinstance(gross, bool)
            and isinstance(cost, (float, int)) and not isinstance(cost, bool)
            and math.isfinite(gross) and math.isfinite(cost)
            and aggregate.get('cost_cushion_tier') != 'INVALID'):
        economic = 'positive' if gross > cost else ('negative' if gross < cost else 'inconclusive')
    dsr = v2_result or next((x for x in aggregate.get('sub_gates', [])
                             if str(x.get('name', '')).startswith('8.2')), {})
    evidence = dsr.get('evidence') or {}
    if evidence.get('engine') == 'QM_DSR_V2':
        statistical = evidence.get('statistical_status', 'uncorrected_selection')
    elif 'insufficient_daily_returns' in str(dsr.get('detail', '')):
        statistical = 'low_sample'
    else:
        statistical = 'uncorrected_selection'
    if statistical not in ('sufficient', 'low_sample', 'uncorrected_selection'):
        statistical = 'uncorrected_selection'
    return {'schema': 'qm.evidence-status/v1', 'source_path': str(path.resolve()),
            'source_sha256': hashlib.sha256(raw).hexdigest(),
            'ea_id': aggregate.get('ea_id'), 'symbol': aggregate.get('symbol'),
            'technical_validity': technical, 'economic_result': economic,
            'statistical_sufficiency': statistical, 'evidence_binding': binding,
            'usage': 'research', 'bindings': receipts,
            'usage_reason': 'No governed release/operational receipt is supplied by this Q08 artifact.',
            'scope': 'Integrity of referenced Q08 evidence; no change to stored verdicts or admission.'}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aggregate', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        result = project(args.aggregate)
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        result = {'schema': 'qm.evidence-status/v1', 'technical_validity': 'unavailable',
                  'economic_result': 'inconclusive', 'statistical_sufficiency': 'uncorrected_selection',
                  'evidence_binding': 'missing', 'usage': 'research', 'error': str(exc)}
    print(json.dumps(result, indent=2, allow_nan=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
