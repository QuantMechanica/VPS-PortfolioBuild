"""Open an OWNER recovery window and release the auto-tripped containment.

Context (2026-08-13 ~19:51Z): the custom-history gate FAIL_CLOSED fleet-wide
because T8 lost three manifest-bound archive files; containment auto-engaged
(`automatic_stop_condition`). The three files have been restored from the
canonical source (T1) and byte-verified against the signed manifest. What
remains is the governed release, which requires an OPEN OWNER window — the
08-09 and 08-10 (ramp_soak) windows have both closed.

This follows the exact convention the ramp_soak follow-up window established:
a fresh detached approval attached to the approval-free draft manifest
(attach_owner_approval refuses a manifest that already carries one), same
manifest_sha256 (it hashes the archive content, not the approval), same
standing decision/review lineage, dual audits 3+4 as registered in the live
activation.

Run BY OWNER via `!` — the signature sentence is the OWNER countersignature:

    ! python C:/QM/repo/tools/strategy_farm/open_recovery_window_and_release.py "<Signatur-Satz>"

Every step is fail-closed by the underlying tooling; this script only
sequences it and prints evidence.
"""
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

A = Path(r'D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809')
DRAFT = A / 'archive_manifest_draft.json'
RAMP_SOAK_RECEIPT = A / 'owner_window_receipt_ramp_soak.json'
WINDOW_ID = 'custom_history_variant_a_20260809_t8_restore_recovery'
NEW_RECEIPT = A / 'owner_window_receipt_t8_restore.json'
NEW_MANIFEST = A / 'archive_manifest_owner_approved_t8_restore.json'
AUDITS = [A / 'isolation_audit_3.json', A / 'isolation_audit_4.json']
MIGRATION = Path(r'C:\QM\repo\tools\strategy_farm\custom_history_migration.py')
MODE_JSON = Path(r'D:\QM\strategy_farm\state\custom_history_containment_mode.json')


def main() -> int:
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        print('USAGE: open_recovery_window_and_release.py "<OWNER Signatur-Satz>"')
        print('The sentence IS the countersignature and must come from OWNER.')
        return 2
    signature = sys.argv[1].strip()

    prior = json.loads(RAMP_SOAK_RECEIPT.read_text(encoding='utf-8'))
    now = datetime.now(timezone.utc).replace(microsecond=0)
    receipt = dict(prior)
    receipt['signed_at_utc'] = now.strftime('%Y-%m-%dT%H:%M:%SZ')
    receipt['signature'] = signature
    receipt['window_id'] = WINDOW_ID
    receipt['window_start_utc'] = (now - timedelta(minutes=5)).strftime('%Y-%m-%dT%H:%M:%SZ')
    receipt['window_end_utc'] = (now + timedelta(hours=12)).strftime('%Y-%m-%dT%H:%M:%SZ')
    NEW_RECEIPT.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + '\n',
                           encoding='utf-8', newline='\n')
    print(f'receipt written: {NEW_RECEIPT.name}  window {receipt["window_start_utc"]}'
          f' .. {receipt["window_end_utc"]}')

    steps = [
        ('attach-owner-approval',
         [sys.executable, str(MIGRATION), 'attach-owner-approval',
          '--manifest', str(DRAFT), '--owner-receipt', str(NEW_RECEIPT),
          '--output', str(NEW_MANIFEST)]),
        ('release-containment',
         [sys.executable, str(MIGRATION), 'release-containment',
          '--manifest', str(NEW_MANIFEST), '--owner-receipt', str(NEW_RECEIPT),
          '--audit', str(AUDITS[0]), '--audit', str(AUDITS[1]),
          '--reason', 't8_manifest_archives_restored_content_verified_from_canonical_t1',
          '--execute']),
    ]
    for name, cmd in steps:
        print(f'--- {name} ---')
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600,
                              cwd=r'C:\QM\repo')
        out = (proc.stdout or '').strip()
        err = (proc.stderr or '').strip()
        if out:
            print(out[-2000:])
        if err:
            print(err[-1000:])
        if proc.returncode != 0:
            print(f'{name} FAILED with exit {proc.returncode} — stopping, nothing further changed')
            return proc.returncode

    mode = json.loads(MODE_JSON.read_text(encoding='utf-8'))
    print(f'containment enabled = {mode.get("enabled")}  (must be False)')
    return 0 if mode.get('enabled') is False else 1


if __name__ == '__main__':
    sys.exit(main())
