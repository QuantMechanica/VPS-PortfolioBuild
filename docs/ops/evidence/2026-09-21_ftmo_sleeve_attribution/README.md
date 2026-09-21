# FTMO sleeve-level P&L attribution

Task: `74c41987-2c55-4b49-ab0f-811e48f1c953`  
Authority: `OWNER-DEC-FTMO-FINAL-MEGA-20260921` sections U.7, 63 and R OPERATIONS  
Scope: read-only run against D2g6 `PRE_SUNDAY_LIVE_TRIAL`; this is not representative Sunday Demo evidence.

## Verdict

**PASS — reconciliation_ok=true, 4 Prague days.**

For the roster-freeze period beginning `2026-09-18T04:50:00Z`, broker account history reconciles exactly:

`account realised $120.61 = roster realised $83.93 + unattributed realised $36.68; difference $0.00`.

The six roster sleeves contributed:

| Magic | Sleeve | Realised USD | Latest floating at run | Closed trades |
|---:|---|---:|---:|---:|
| 104030002 | 10403 XAUUSD D1 | 0.00 | 0.00 | 0 |
| 107000003 | 10700 XAUUSD H1 | 0.00 | 0.00 | 0 |
| 107060001 | 10706 GBPUSD H1 | 0.00 | 0.00 | 0 |
| 114220004 | 11422 USDCAD D1 | -37.50 | 130.10 | 1 |
| 132130000 | 13213 USDJPY H1 | 121.43 | 0.00 | 1 |
| 412190000 | 41219 XAUUSD D1 | 0.00 | 0.00 | 0 |

One deal is deliberately outside the roster: the `15370001` XAGUSD cutover close realised `$36.68` on the first day. It appears as `MAGIC_NOT_IN_ROSTER` in `unattributed[]`, participates in both daily and period identities, and is never assigned to a D2g6 sleeve.

The live run read six broker deals and 460,789 collector samples with zero malformed rows. The September 18 period begins after Prague midnight, so that day's midnight floating/headroom fields are explicitly unavailable outside tolerance; September 19–21 use a nearest-sample midnight proxy. These observations are correctly labelled as pre-Sunday evidence.

## Implementation

`tools/strategy_farm/ftmo/sleeve_attribution.py` produces `qm.ftmo-sleeve-attribution/v1` with:

- a per-Prague-day × per-magic table of cent-rounded realised profit, commission, swap and fee;
- entries, exits and unique closed-position trade count;
- floating P&L at the nearest Prague-midnight sample, with coverage and distance;
- worst observed intraday floating-P&L MAE proxy;
- Daily-Loss headroom consumed and each sleeve's proportional share at the account's worst observed equity;
- book/account totals and a realised cumulative curve for every sleeve;
- every non-roster, manual, zero-magic or balance deal in `unattributed[]`;
- a strict identity per day and over the full period: `roster + unattributed == broker account history`, to the cent.

Direct broker queries are guarded: the exact FTMO executable must already have a matching live process before the MetaTrader5 read-only attachment is permitted. T_Live and T1–T10 paths are refused. The query verifies the expected server and login suffix, emits only masked identity (`*******732`), calls no trade API, and disconnects its Python session afterward. A normalized CSV/JSON input is also supported for offline evidence and tests.

Outputs:

- machine sidecar: `D:/QM/reports/state/ftmo_sleeve_attribution.json`;
- byte-identical durable sidecar snapshot: `PRE_SUNDAY_attribution_snapshot.json` (SHA-256 `5fdbf15a727e01c737e790946348813a093b23c6a5686c0e43dff0625d6fcaad`);
- durable PRE_SUNDAY Markdown snapshot: `PRE_SUNDAY_attribution_report.md`;
- Mission Control: `tools/strategy_farm/render_cockpit_v2.py` reads the sidecar only and displays a compact `SLEEVE P&L` block.

## OWNER section-G Mission Control binding

The FTMO BOOK panel now renders, without recomputation, the canonical state JSON's:

- Incumbent sleeves, roles, risk weights, R/day, trades/day, active-day ratio, daily/max breach probabilities, payout LCB, median Challenge/first-payout days, and strongest dependence cluster;
- Shadow book with the same fields;
- `delta_shadow_vs_incumbent`;
- `strongest_missing_book_behavior`;
- financing label.

Missing or schema-invalid attribution remains visibly `EVIDENCE_MISSING`; it is never zero-filled.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_sleeve_attribution.py tools/strategy_farm/tests/test_render_cockpit_ftmo_book.py -q
........                                                                 [100%]
8 passed

live PRE_SUNDAY run:
schema=qm.ftmo-sleeve-attribution/v1
reconciliation_ok=true
day_count=4
unattributed_deals=1
```

The synthetic fixture covers two roster magics, one unattributed deal, a position open across Prague midnight, a commission-only broker deal, and the exact reconciliation identity.
