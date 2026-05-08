#!/usr/bin/env python3
"""Deterministic guard for qm-strategy-card-extraction."""
from __future__ import annotations
import argparse, json
from pathlib import Path

FORBIDDEN=('tensorflow','pytorch','sklearn','xgboost','lightgbm')


def main():
    p=argparse.ArgumentParser(description='Validate extracted strategy card schema and ML ban')
    p.add_argument('--card',required=True)
    a=p.parse_args()
    path=Path(a.card)
    text=path.read_text(encoding='utf-8') if path.exists() else ''
    lower=text.lower()
    hits=[t for t in FORBIDDEN if t in lower]
    required=['## hypothesis','## rules','## risk']
    miss=[r for r in required if r not in lower]
    status='ok' if path.exists() and not hits and not miss else 'error'
    print(json.dumps({'status':status,'ml_hits':hits,'missing_sections':miss,'next_action':'submit_card' if status=='ok' else 'revise_card'},indent=2))
    return 0 if status=='ok' else 2

if __name__=='__main__': raise SystemExit(main())
