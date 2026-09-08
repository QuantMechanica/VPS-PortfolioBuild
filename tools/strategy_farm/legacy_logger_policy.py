"""Exact-binary, OWNER-receipt-bound Q09 v3 legacy logger exception.

This never derives build age from filesystem timestamps, invents ``sv``, or
changes admission. Git object bytes and ancestry prove the pre-control binary.
Only the fresh, exclusive selection/holdout stream may use the exception.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
POLICY_PATH = Path(__file__).with_name('config') / 'legacy_logger_allowlist.v1.json'
RECEIPTS_PATH = Path('D:/QM/reports/state/owner_decision_receipts.jsonl')
CONTROL_COMMIT = '6e92c806264d5216c46ba6ad4f8cf8c0641b53f8'
DECISION_ID = 'OWNER-DEC-Q09-LEGACY-LOGGER-SAMPLE-20260907'
FOOTNOTE = ('Legacy-Logger ohne sv; exakt freigegebene Pre-20.07.2026-Binary. '
            'Identitaet und frischer Byte-Strom authentifiziert; '
            'Schema-Version nicht nachgewiesen. Keine Live-Freigabe.')


class LegacyLoggerError(ValueError):
    pass


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _git(*args: str) -> bytes:
    result = subprocess.run(['git', '-C', str(REPO), *args], capture_output=True,
                            timeout=30, check=False)
    if result.returncode:
        raise LegacyLoggerError('legacy build Git evidence unavailable or contradictory')
    return result.stdout


def _verify_owner(policy: dict[str, Any]) -> None:
    binding = policy['owner_receipt']
    for line in RECEIPTS_PATH.read_text(encoding='utf-8').splitlines():
        receipt = json.loads(line)
        if receipt.get('receipt_id') != binding['receipt_id']:
            continue
        unsigned = {k: v for k, v in receipt.items() if k != 'receipt_sha256'}
        data = (json.dumps(unsigned, sort_keys=True, separators=(',', ':'),
                           ensure_ascii=True) + '\n').encode()
        if (receipt.get('receipt_sha256') != binding['receipt_sha256']
                or _sha(data) != binding['receipt_sha256']
                or receipt.get('decision_id') != DECISION_ID
                or receipt.get('decision') != 'YES'
                or receipt.get('decided_by') != 'OWNER'
                or receipt.get('execution_authorized') is not True):
            raise LegacyLoggerError('legacy logger OWNER receipt binding failed')
        return
    raise LegacyLoggerError('legacy logger OWNER receipt missing')


def resolve_authorization(*, ea_id: int, ex5_sha256: str, symbol: str,
                          setfile: Path, fresh_required: bool, phase: str,
                          dispatch_version: str, subgate: str,
                          contract_version: str) -> dict[str, Any] | None:
    if (not fresh_required or phase != 'Q10_NEWS'
            or contract_version != 'q09-news-evidence/v3'
            or dispatch_version != 'q09_news_executor_v1'
            or not re.fullmatch(r'[0-9a-f]{16}_(selection|holdout)', subgate)):
        return None
    policy_bytes = POLICY_PATH.read_bytes()
    policy = json.loads(policy_bytes)
    if policy.get('schema') != 'qm.legacy-logger-allowlist/v1':
        raise LegacyLoggerError('legacy logger policy schema mismatch')
    matches = [entry for entry in policy['binaries']
               if entry['ea_id'] == ea_id and entry['ex5_sha256'] == ex5_sha256
               and entry.get('enabled') is True]
    if not matches:
        return None
    if len(matches) != 1:
        raise LegacyLoggerError('ambiguous legacy logger binary registration')
    _verify_owner(policy)
    entry = matches[0]
    commit = entry['git_commit']
    label = entry['ea_label']
    if (not re.fullmatch(r'[0-9a-f]{40}', commit)
            or not re.fullmatch(rf'QM5_{ea_id}_[a-z0-9-]+', label)):
        raise LegacyLoggerError('invalid legacy build object identity')
    _git('merge-base', '--is-ancestor', commit, CONTROL_COMMIT)
    if commit == CONTROL_COMMIT:
        raise LegacyLoggerError('control commit is not a legacy build')
    recorded_at = _git('show', '-s', '--format=%cI', commit).decode().strip()
    if datetime.fromisoformat(recorded_at) >= datetime(2026, 7, 20, tzinfo=timezone.utc):
        raise LegacyLoggerError('post-control build date refused')
    binary_path = f'framework/EAs/{label}/{label}.ex5'
    if _sha(_git('show', f'{commit}:{binary_path}')) != ex5_sha256:
        raise LegacyLoggerError('archived EX5 bytes do not match the deployed identity')
    registry_bytes = _git('show', f'{commit}:framework/registry/magic_numbers.csv')
    raw = setfile.read_bytes()
    encoding = 'utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig'
    slots = re.findall(r'^\s*qm_magic_slot_offset\s*=\s*(\d+)(?:\|\|[^\r\n]*)?\s*$',
                       raw.decode(encoding), re.MULTILINE)
    if len(slots) != 1:
        raise LegacyLoggerError('legacy sample needs one explicit magic slot in its setfile')
    magic_rows = [row for row in csv.DictReader(io.StringIO(registry_bytes.decode('utf-8-sig')))
                  if row['ea_id'] == str(ea_id) and row['symbol'] == symbol
                  and row['symbol_slot'] == str(int(slots[0])) and row['status'] == 'active']
    if len(magic_rows) != 1 or int(magic_rows[0]['magic']) <= 0:
        raise LegacyLoggerError('legacy sample magic/symbol not bound in archived registry')
    return {
        'schema': 'qm.legacy-logger-authorization/v1',
        'logger_sample_authentication': 'legacy_no_sv',
        'decision_id': DECISION_ID,
        **policy['owner_receipt'],
        'policy_sha256': _sha(policy_bytes),
        'ea_id': ea_id, 'ex5_sha256': ex5_sha256,
        'git_commit': commit, 'git_recorded_at': recorded_at,
        'archived_magic_registry_sha256': _sha(registry_bytes),
        'expected_magic': int(magic_rows[0]['magic']),
        'symbol': symbol, 'setfile_sha256': _sha(raw),
        'fresh_required': True, 'footnote': FOOTNOTE,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ea-id', type=int, required=True)
    parser.add_argument('--ex5-sha256', required=True)
    parser.add_argument('--symbol', required=True)
    parser.add_argument('--setfile', type=Path, required=True)
    parser.add_argument('--fresh-required', action='store_true')
    parser.add_argument('--phase', required=True)
    parser.add_argument('--dispatch-version', required=True)
    parser.add_argument('--subgate', required=True)
    parser.add_argument('--contract-version', required=True)
    args = vars(parser.parse_args())
    try:
        print(json.dumps(resolve_authorization(**args), sort_keys=True))
    except (LegacyLoggerError, OSError, ValueError, KeyError) as exc:
        parser.exit(1, f'LEGACY_LOGGER_AUTHENTICATION_REFUSED: {exc}\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
