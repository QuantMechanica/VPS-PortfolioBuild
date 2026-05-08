#!/usr/bin/env python3
"""Deterministic guard for qm-build-ea-from-card."""
from __future__ import annotations
import argparse, csv, json
from pathlib import Path

REPO=Path(__file__).resolve().parents[2]
REG_EA=REPO/'framework/registry/ea_id_registry.csv'
REG_MAGIC=REPO/'framework/registry/magic_numbers.csv'
EA_ROOT=REPO/'framework/EAs'

def args():
    p=argparse.ArgumentParser(description='Validate EA build prerequisites from approved card')
    p.add_argument('--ea-id',required=True)
    p.add_argument('--ea-label',required=True)
    return p.parse_args()

def csv_has(path,key,val):
    if not path.exists(): return False
    with path.open('r',encoding='utf-8',newline='') as f:
        return any(r.get(key)==val for r in csv.DictReader(f))

def main():
    a=args()
    ea_dir=EA_ROOT/a.ea_label
    checks={
        'ea_registry_row': csv_has(REG_EA,'ea_id',a.ea_id),
        'magic_registry_rows': REG_MAGIC.exists(),
        'ea_dir_exists': ea_dir.exists(),
    }
    status='ok' if checks['ea_registry_row'] and checks['magic_registry_rows'] else 'error'
    print(json.dumps({'status':status,'checks':checks,'next_action':'implement_or_review_mq5' if status=='ok' else 'fix_registry_first'},indent=2))
    return 0 if status=='ok' else 2

if __name__=='__main__': raise SystemExit(main())
