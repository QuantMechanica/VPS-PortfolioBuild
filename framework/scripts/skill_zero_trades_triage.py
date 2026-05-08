#!/usr/bin/env python3
"""Deterministic guard for qm-zero-trades-recovery."""
from __future__ import annotations
import argparse, csv, json
from pathlib import Path

def main():
    p=argparse.ArgumentParser(description='Classify zero-trades cohort from phase report')
    p.add_argument('--report',required=True)
    p.add_argument('--threshold',type=int,default=5)
    a=p.parse_args()
    rp=Path(a.report)
    zt=0
    if rp.exists():
        with rp.open('r',encoding='utf-8',newline='') as f:
            for r in csv.DictReader(f):
                v=(r.get('verdict') or '').upper()
                reason=(r.get('invalidation_reason') or '').lower()
                if v in {'NO_REPORT','INVALID'} or 'zero' in reason:
                    zt+=1
    status='ok' if rp.exists() else 'error'
    dispatch = zt >= a.threshold
    print(json.dumps({'status':status,'zero_trade_count':zt,'threshold':a.threshold,'dispatch_recovery':dispatch,'next_action':'run_recovery_v2' if dispatch else 'document_symbol_noise'},indent=2))
    return 0 if status=='ok' else 2

if __name__=='__main__': raise SystemExit(main())
