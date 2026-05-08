#!/usr/bin/env python3
"""Deterministic guard for qm-t6-deploy-verification."""
from __future__ import annotations
import argparse, json
from pathlib import Path

def main():
    p=argparse.ArgumentParser(description='Validate T6 deploy verification evidence bundle')
    p.add_argument('--manifest',required=True)
    p.add_argument('--experts-log',required=True)
    p.add_argument('--journal-log',required=True)
    a=p.parse_args()
    m=Path(a.manifest); e=Path(a.experts_log); j=Path(a.journal_log)
    checks={
        'manifest_exists':m.exists(),
        'experts_log_exists':e.exists(),
        'journal_log_exists':j.exists(),
    }
    status='ok' if all(checks.values()) else 'error'
    print(json.dumps({'status':status,'checks':checks,'next_action':'perform_read_only_t6_verification' if status=='ok' else 'collect_missing_evidence'},indent=2))
    return 0 if status=='ok' else 2

if __name__=='__main__': raise SystemExit(main())
