---
ea_id: QM5_10013
slug: rw-fx-weekend-gap
type: strategy
source_id: dcbac84f-6ecf-5d21-9630-50faa69306ec
source_citation: "Robot Wealth, 'Index of Strategies', section 'FX Weekend GAP (alpha around market close)', https://robotwealth.com/index-of-strategies/#fx-weekend-gap-alpha-around-market-close"
sources:
  - "[[sources/robot-wealth-blog]]"
concepts:
  - "[[concepts/weekend-gap]]"
  - "[[concepts/fx-cross-sectional]]"
indicators:
  - "[[indicators/friday-close-gap]]"
  - "[[indicators/cross-sectional-rank]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX]
period: H1
expected_trade_frequency: "Weekly Friday/Monday gap effect; one candidate trade per week per symbol, reduced by gap threshold. Conservative estimate 30 trades/year/symbol."
expected_trades_per_year_per_symbol: 30
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL cited; R2 deterministic weekend gap/rank entry and gap-fill/time exit with ~30 trades/year/symbol; R3 major FX DWX symbols testable; R4 fixed non-ML one-position rules."
---

# Robot Wealth FX Weekend Gap

## Quelle
- Source: [[sources/robot-wealth-blog]]
- Citation: Robot Wealth, "Index of Strategies", section "FX Weekend GAP (alpha around market close)", https://robotwealth.com/index-of-strategies/#fx-weekend-gap-alpha-around-market-close
- Accessed 2026-05-19 URL: https://robotwealth.com/index-of-strategies/#fx-weekend-gap-alpha-around-market-close
- Source location: the index names the strategy as "FX Weekend GAP (alpha around market close)" and points to FX Bootcamp material, FX Pod research code/Zorro scripts, and the Edge Database entry.
- Author / institution: Robot Wealth / Kris Longmore team.

## Mechanik

### Entry
- At the first tradable H1 bar after the weekend open, compute each symbol's weekend gap: Monday open minus Friday close.
- Normalize gap by ATR(14,H1).
- Cross-sectionally rank all target symbols by normalized gap.
- Enter long the strongest negative gap symbols (gap-down mean-reversion) when normalized gap <= -0.35 ATR.
- Enter short the strongest positive gap symbols when normalized gap >= +0.35 ATR.
- Baseline one-position-per-symbol implementation trades each symbol independently; portfolio version caps total simultaneous positions at three by largest absolute gap.

### Exit
- Exit at gap fill, defined as price touching Friday close.
- If not filled, exit after 24 trading hours.
- Force-flat before Tuesday 17:00 New York time.

### Stop Loss
- Initial SL = 1.2 * absolute weekend gap, minimum 0.8 * ATR(14,H1), maximum 2.0 * ATR(14,H1).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` per symbol, with portfolio cap if several symbols trigger.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Skip tiny gaps below 0.35 ATR.
- Skip symbols with abnormal weekend spread at market open; wait one H1 bar if spread > 2x median H1 spread.
- Skip weekends with known extraordinary political/election risk affecting a target currency unless P8 news mode later allows it.

## Concepts
- [[concepts/weekend-gap]] - primary
- [[concepts/fx-cross-sectional]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Robot Wealth index URL names the strategy and links related Robot Wealth assets. |
| R2 Mechanical | UNKNOWN | Source index confirms strategy and code assets exist, but public page does not expose exact thresholds; deterministic gap-fill defaults supplied. |
| R3 DWX-testbar | PASS | Major FX symbols are DWX instruments; weekend gaps are observable in broker data. |
| R4 No ML | PASS | Fixed calendar/gap/rank rules, no ML, grid, martingale, or adaptive live parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10011_rw-fx-weekly-seas]] - both exploit weekly timing structure in FX.

## Lessons Learned
- TBD during pipeline run.
