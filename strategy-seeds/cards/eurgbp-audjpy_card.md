---
strategy_id: AI-CLAUDE-FX-COINT66-20260609-EURGBP-AUDJPY
ea_id: TBD
slug: eurgbp-audjpy
status: DRAFT
type: strategy
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
source_id: AI-CLAUDE-FX-COINT66-20260609-EURGBP-AUDJPY
source_citation: "QuantMechanica OWNER-requested all-sign reproduction of the 2026-06-09 66-pair FX cointegration scan on Darwinex .DWX D1 data; methodology grounded in Chan, Ernest P. (2009), Quantitative Trading, Wiley, Chapter 7 and Example 3.6."
strategy_type_flags:
  - cointegration-pair-trade
  - mean-reach-exit
  - atr-hard-stop
  - friday-close-flatten
  - symmetric-long-short
concepts:
  - cointegration-pair-trade
  - zscore-band-reversion
  - market-neutral-fx-basket
indicators:
  - rolling-zscore
  - atr-stop
target_symbols: [EURGBP.DWX, AUDJPY.DWX]
logical_symbol: TBD
period: D1
expected_trade_frequency: "D1 two-leg basket, approximately 5 logical spread packages/year from 20 OOS state changes over 2023-2024."
expected_trades_per_year_per_symbol: 5
g0_status: PENDING_REVIEW
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_pf: TBD
expected_dd_pct: TBD
portfolio_scope: basket
---

# EURGBP/AUDJPY Cointegration Basket

## 1. Source

```yaml
source_citations:
  - type: other
    citation: "QuantMechanica. (2026). Cross-Asset FX Edge Discovery — own-data, hypothesis-first; all-sign reproduction of the 66-pair D1 scan."
    location: "docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md, v3 systematic scan; framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py with the positive-hedge exclusion disabled"
    quality_tier: B
    role: primary
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading."
    location: "Example 3.6, pp. 55-59; Chapter 7 stationarity and cointegration, pp. 126-142"
    quality_tier: A
    role: supplement
```

The auditable Chan extraction is
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. The bounded
in-house scan was explicitly selected by the OWNER for this forex-sleeve
mission. It is reproducible from the checked-in script and read-only D1 exports
under `D:/QM/mt5/T_Export/MQL5/Files`.

The published positive-beta pass retained only the already-built
EURJPY/GBPJPY and AUDUSD/NZDUSD anchors. Reproducing the same 66-pair method
without discarding negative regression hedges leaves EURGBP/AUDJPY as the next
strict row after the already-built GBPUSD/USDCAD, EURJPY/GBPJPY,
AUDUSD/NZDUSD, USDCAD/NZDUSD, and AUDUSD/EURGBP sleeves.

| Scan measurement | Value |
|---|---:|
| DEV net Sharpe | 0.4168335930 |
| OOS net Sharpe | 0.8918614046 |
| OOS return | 4.475153414% |
| OOS state changes | 20 |
| Fixed DEV beta | -0.1220286930 |
| Half-life | 36.83805248 D1 bars |

These are approximate in-house screening measurements under the scan's
`0.8 bp/leg` cost model, not live or pipeline performance claims. Swap was not
modeled. Q02 onward remains the judge.

## 2. Concept

Trade temporary deviations in the fixed log-price combination
`ln(EURGBP) - beta * ln(AUDJPY)` after the source scan found positive DEV and
OOS results with a 36.84-day mean-reversion half-life. The fitted beta is
negative, so a long spread is long both legs and a short spread is short both
legs.

EURGBP expresses relative European growth and rate pressure while AUDJPY is a
risk/carry cross. Their relationship is statistical rather than a same-leg
identity. The small absolute beta leaves substantial EURGBP exposure, so
"market-neutral" means regression-neutral to the fitted spread only; it does
not imply currency, USD, carry, or book neutrality. That caveat is a reason for
high-risk review, not a reason to add an untested filter.

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - D1
primary_target_symbols:
  - EURGBP.DWX
  - AUDJPY.DWX
host_symbol: EURGBP.DWX
tester_currency: USD
portfolio_scope: basket
```

Both traded legs and every tester-currency conversion dependency must be
declared in `basket_manifest.json` at build time. Backtests must use
`RISK_FIXED`; no live setfile is authorized by this draft.

## 4. Entry Rules

- Evaluate once per new closed D1 bar on the logical host.
- Require at least 60 aligned closed D1 bars for both legs.
- Use the fixed DEV beta `-0.12202869296345396`; never refit it at runtime.
- Compute `spread = ln(EURGBP) - beta * ln(AUDJPY)`.
- Compute the spread z-score from the preceding 60 closed D1 observations.
- With no package open and `z > +2.0`, open a short-spread package: short
  EURGBP and short AUDJPY.
- With no package open and `z < -2.0`, open a long-spread package: long EURGBP
  and long AUDJPY.
- Split the fixed-risk budget across the legs in `1:abs(beta)` risk weight,
  normalized so the package consumes one `RISK_FIXED` budget.
- Attach a fixed `ATR(20, D1) * 2.0` protective stop to each leg.
- At most one logical package may be open; no averaging, grid, martingale,
  pyramiding, or partial entry is allowed.

## 5. Exit Rules

- Close both legs when `abs(z) < 0.5` on a closed D1 bar.
- Close the surviving leg immediately if the package becomes orphaned.
- A leg-level ATR hard stop may close one leg; orphan cleanup must then flatten
  the other leg without waiting for a new entry signal.
- Framework Friday close remains enabled.
- Framework kill-switch and hard-stop exits always take precedence.

## 6. Filters (No-Trade Module)

- Trade only from the declared logical host and only when both D1 histories are
  synchronized and warm.
- Use the standard framework kill-switch, news, Friday-close, weekend,
  holiday, and broker-connectivity gates.
- Do not add a correlation, volatility-regime, session, carry, or adaptive
  stationarity filter before the standard pipeline tests the source rule.

## 7. Trade Management Rules

- Treat the two positions as one package with deterministic leg magics.
- Do not trail, move to break-even, scale in, scale out, or rebalance beta.
- If either leg cannot be opened, immediately close any leg opened during the
  failed package transaction.
- If only one leg remains open for any reason, flatten it on the next
  management pass.

## 8. Parameters To Test

```yaml
- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: -0.12202869296345396
  sweep_range: [-0.16, -0.12202869296345396, -0.08]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.75, 2.0, 2.25]
- name: strategy_exit_z
  default: 0.5
  sweep_range: [0.25, 0.5, 0.75]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5]
```

## 9. Author Claims

Chan describes the method, not this pair: "The main method used to test for
cointegration is called the cointegrating augmented Dickey-Fuller test."
(Example 7.2, p. 128.)

No external author performance claim is imported for EURGBP/AUDJPY. The scan
measurements above are explicitly provisional and net only of its approximate
transaction-cost model.

## 10. Initial Risk Profile

```yaml
expected_pf: TBD
expected_dd_pct: TBD
expected_trade_frequency: approximately 5 logical packages/year
risk_class: high
gridding: false
scalping: false
ml_required: false
```

The high-risk classification reflects the marginal OOS Sharpe, cross-bloc
economic link, negative beta, and concentrated EURGBP weight. Multi-week swap,
conversion, spread, and real-tick costs are delegated to the pipeline.

## 11. Strategy Allowability Check

- [x] Mechanical fixed-beta, closed-D1 z-score entry and mean-reach exit.
- [x] No ML, online refit, external runtime data, banned indicator, grid, or
  martingale.
- [x] Low-frequency D1 design; no latency-sensitive premise.
- [x] `RISK_FIXED` backtest contract and one package per magic pair.
- [x] Friday Close compatible and enabled.
- [x] Tier-A Chan method source plus reproducible OWNER-approved in-house pair
  selection.
- [x] No existing card or EA folder names the EURGBP/AUDJPY pair as of
  2026-07-10.
- [ ] CEO + Quality-Business review and EA-ID allocation are still required.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Logical-host, synchronized-history, warmup, and standard framework gates."
  trade_entry:
    used: true
    notes: "Closed-D1 fixed-negative-beta spread z-score with atomic two-leg package entry."
  trade_management:
    used: true
    notes: "Broken-package and partial-entry cleanup only; hard stops are attached at entry."
  trade_close:
    used: true
    notes: "Close the package when abs(z) < 0.5; framework Friday close and kill-switch remain active."
hard_rules_at_risk:
  - friday_close
  - risk_mode_dual
  - dwx_suffix_discipline
  - magic_schema
  - one_position_per_magic_symbol
  - kill_switch_coverage
at_risk_explanation: |
  Multi-week holds make Friday flattening and swap material, but Friday close
  remains enabled. Build review must verify RISK_FIXED backtest mode,
  .DWX-only research symbols, ea_id*10000+slot magics, one position per leg,
  and package-wide kill-switch/orphan cleanup.
```

## 13. Implementation Notes

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: medium
estimated_test_runtime: "basket Q02 approximately 60-120 minutes; use paced fleet only"
data_requirements: "EURGBP.DWX and AUDJPY.DWX D1 plus tester-currency conversion history declared by basket manifest"
```

## 14. Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial all-sign 66-pair candidate extraction | G0 | DRAFT_PENDING_REVIEW |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | PENDING_REVIEW | this card |
| Q01 Build Validation | TBD | BLOCKED_NO_EA_ID | TBD |
| Q02 Baseline Screening | TBD | NOT_ENQUEUED | TBD |

## 16. Lessons Captured

- 2026-07-10: The published positive-beta report hid two additional strict
  negative-beta rows; sign-aware reproduction is required before declaring the
  66-pair frontier exhausted.
- 2026-07-10: Seven paced Q02 jobs were active during extraction, so no manual
  backtest was launched and no queue row was created.
