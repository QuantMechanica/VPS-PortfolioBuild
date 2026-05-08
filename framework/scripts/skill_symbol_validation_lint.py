#!/usr/bin/env python3
"""Deterministic guard for qm-validate-custom-symbol."""
from __future__ import annotations
import argparse, csv, json
from pathlib import Path

def main():
    p=argparse.ArgumentParser(description='Validate custom-symbol evidence files and registry row')
    p.add_argument('--csv-path',required=True)
    p.add_argument('--registry',default='C:/QM/repo/framework/registry/custom_symbols.csv')
    p.add_argument('--symbol',required=True)
    a=p.parse_args()
    csv_path=Path(a.csv_path)
    reg=Path(a.registry)
    cols_ok=False
    if csv_path.exists():
        with csv_path.open('r',encoding='utf-8',newline='') as f:
            hdr=next(csv.reader(f),[])
            cols_ok=set(['Date','Time']).issubset(set(hdr))
    reg_row=False
    if reg.exists():
        with reg.open('r',encoding='utf-8',newline='') as f:
            reg_row=any(r.get('symbol')==a.symbol for r in csv.DictReader(f))
    status='ok' if csv_path.exists() and cols_ok else 'error'
    print(json.dumps({'status':status,'checks':{'tick_csv_exists':csv_path.exists(),'tick_csv_columns_ok':cols_ok,'registry_row_exists':reg_row},'next_action':'update_validation_status' if status=='ok' else 'fix_data_export'},indent=2))
    return 0 if status=='ok' else 2

if __name__=='__main__': raise SystemExit(main())
