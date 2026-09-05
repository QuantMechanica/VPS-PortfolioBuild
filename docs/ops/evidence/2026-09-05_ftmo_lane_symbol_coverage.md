# FTMO lane symbol coverage — 2026-09-05

## Result

**PASS (build-only).** `ftmo_lane_runner.py` now has fail-closed source, evaluator,
native-terminal and FTMO-code definitions for every unique symbol used by the
sealed eight-sleeve pool. Existing XAUUSD and GER40.cash support remains in
place. No terminal, trial, T_Live, or AutoTrading action was performed.

The runner records a unit-preserving lot normalization in every derived-set
receipt and job manifest:

`target lots = source lots × source contract size ÷ target contract size`

## Eight-sleeve mapping

| Sleeve | DXZ source | Evaluator | FTMO native / API code | DXZ units/lot | FTMO units/lot | Target lots per source lot |
|---|---|---|---|---:|---:|---:|
| 10706:GBPUSD | GBPUSD.DWX | GBPUSD | GBPUSD / GBP/USD | 100,000 | 100,000 | 1 |
| 11421:EURUSD | EURUSD.DWX | EURUSD | EURUSD / EUR/USD | 100,000 | 100,000 | 1 |
| 11422:USDCAD | USDCAD.DWX | USDCAD | USDCAD / USD/CAD | 100,000 | 100,000 | 1 |
| 11910:NZDUSD | NZDUSD.DWX | NZDUSD | NZDUSD / NZD/USD | 100,000 | 100,000 | 1 |
| 13054:XTIUSD | XTIUSD.DWX | XTIUSD | USOIL.cash | 1,000 | 100 | 10 |
| 1537:XAGUSD | XAGUSD.DWX | XAGUSD | XAGUSD / XAG/USD | 5,000 | 5,000 | 1 |
| 20048:XTIUSD | XTIUSD.DWX | XTIUSD | USOIL.cash | 1,000 | 100 | 10 |
| 21505:XAGUSD | XAGUSD.DWX | XAGUSD | XAGUSD / XAG/USD | 5,000 | 5,000 | 1 |

Source contract sizes are the `framework/registry/venue_cost_model.json`
contract convention: standard FX 100,000 underlying units, XAG 5,000 oz, and
XTI 1,000 bbl. Target contract sizes are pinned to the normalized contracts in
`2026-09-05_ftmo_current_pool_cost_snapshot.json`.

## Validation output

Pinned cost snapshot SHA-256:
`90421c5a3764b7f5ba6fb281a71bd27a54910c568341443f2b5389251bb8d99e`

```text
candidate_sleeves=8
GBPUSD.DWX -> GBPUSD [GBP/USD]: source=100000 target=100000 snapshot=100000 factor=1 PASS=True
EURUSD.DWX -> EURUSD [EUR/USD]: source=100000 target=100000 snapshot=100000 factor=1 PASS=True
USDCAD.DWX -> USDCAD [USD/CAD]: source=100000 target=100000 snapshot=100000 factor=1 PASS=True
NZDUSD.DWX -> NZDUSD [NZD/USD]: source=100000 target=100000 snapshot=100000 factor=1 PASS=True
XTIUSD.DWX -> USOIL.cash [USOIL.cash]: source=1000 target=100 snapshot=100 factor=10 PASS=True
XAGUSD.DWX -> XAGUSD [XAG/USD]: source=5000 target=5000 snapshot=5000 factor=1 PASS=True
```

Focused verification:

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_lane_runner.py tools/strategy_farm/tests/test_ftmo_m1_bootstrap.py -q
43 passed in 1.49s
```

Tests cover every current-pool symbol mapping, the non-unity WTI normalization,
crossed source/native rejection, build risk guardrails, lane binding, evidence
class isolation, and history-bootstrap compatibility.

## Authorization boundary

This patch only expands declarative coverage and validation. It does not prove
native history availability or symbol-probe success; those existing fail-closed
gates remain required per lane before a job can be prepared. Trial start,
account action, purchase, pointer signing, T_Live, and AutoTrading remain outside
this artifact.
