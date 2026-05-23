#!/usr/bin/env python3
"""Deterministic guard for qm-g0-review."""
from __future__ import annotations
import argparse, json
from pathlib import Path

REQUIRED = [
    "strategy_id",
    "ea_id",
    "slug",
    "status:",
    "source_citations:",
    "markets:",
    "timeframes:",
    "primary_target_symbols:",
    "## 4. entry rules",
    "## 5. exit rules",
    "## 6. filters (no-trade module)",
    "## 7. trade management rules",
    "expected_pf:",
    "expected_dd_pct:",
    "expected_trade_frequency:",
    "risk_class:",
    "ml_required:",
    "modules_used:",
    "hard_rules_at_risk:",
    "target_modules:",
]

def main():
    p=argparse.ArgumentParser(description='Lint strategy card for G0 readiness')
    p.add_argument('--card',required=True,help='Path to strategy card markdown')
    a=p.parse_args()
    path=Path(a.card)
    text=path.read_text(encoding='utf-8') if path.exists() else ''
    missing=[k for k in REQUIRED if k not in text.lower()]
    status='ok' if path.exists() and not missing else 'error'
    print(json.dumps({'status':status,'card_exists':path.exists(),'missing_sections':missing,'next_action':'cto_semantic_review' if status=='ok' else 'complete_card_fields'},indent=2))
    return 0 if status=='ok' else 2

if __name__=='__main__': raise SystemExit(main())
