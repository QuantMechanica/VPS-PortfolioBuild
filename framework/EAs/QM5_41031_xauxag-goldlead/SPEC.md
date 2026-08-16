# QM5_41031_xauxag-goldlead — Strategy Spec

**EA ID:** QM5_41031
**Slug:** `xauxag-goldlead`
**Source:** `KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-16

Canonical card: `strategy-seeds/cards/approved/QM5_41031_xauxag-goldlead_card.md`

## 1. Strategy Logic

At the first eligible tick of each synchronized XAU/XAG D1 session, the EA
reads exactly two completed closes for each metal and computes
`g = ln(XAU_close[1]/XAU_close[2])` and
`s = ln(XAG_close[1]/XAG_close[2])`.

When `g >= 0.0075`, `s < 0.50*g`, and `abs(s) <= abs(g)`, it sells XAU and
buys XAG. When `g <= -0.0075`, `s > 0.50*g`, and `abs(s) <= abs(g)`, it buys
XAU and sells XAG. Every other state is flat; silver never leads. The legs
target equal absolute USD notional, share one fixed-dollar stop budget, and
use frozen `3.0 * ATR(20,D1)` stops. Both legs close at the first subsequent
XAU D1 boundary. Friday 21 and three calendar days are fail-safe exits.

Each broker date is persisted before any fallible gate. There is no retry,
current-bar signal input, target, fitted ratio, optimizer, scale-in, grid,
martingale, or standalone leg.

## 2. Parameters

All values are locked for Q02; there is no optimization range.

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | locked | exact companion route |
| `strategy_entry_grace_minutes` | 180 | locked | latest eligible tick after host D1 open |
| `strategy_gold_shock_abs_return` | 0.0075 | locked | minimum absolute completed gold log return |
| `strategy_silver_response_fraction` | 0.50 | locked | strict maximum same-direction silver response |
| `strategy_atr_period_d1` | 20 | locked | completed-bar ATR period per leg |
| `strategy_atr_sl_mult` | 3.0 | locked | frozen hard-stop distance per leg |
| `strategy_notional_ratio` | 1.0 | locked | XAU:XAG absolute USD-notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | locked | post-rounding pair mismatch ceiling |
| `strategy_max_hold_days` | 3 | locked | stale package repair guard |
| `strategy_xau_max_spread_points` | 1500 | locked | XAU entry spread ceiling |
| `strategy_xag_max_spread_points` | 1500 | locked | XAG entry spread ceiling |

## 3. Symbol Universe

**Designed for:**

- `XAUUSD.DWX` — exact host and traded slot 0, magic `410310000`.
- `XAGUSD.DWX` — exact companion and traded slot 1, magic `410310001`.

**Explicitly NOT for:**

- Any other symbol, synthetic ratio, futures contract, or metal mapping.
- Either XAU or XAG as a standalone strategy; results belong to one package.

The logical tester route is `QM5_41031_XAU_XAG_GOLDLEAD_D1`, hosted on
`XAUUSD.DWX` through `basket_manifest.json`.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(XAUUSD.DWX, PERIOD_D1)` |
| Formation | exactly two completed synchronized D1 closes per metal |
| Normal lifecycle | first following XAU D1 boundary |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Completed packages / year | approximately 10–30; Q02 floor is 5 |
| Typical hold time | one D1 session |
| Expected drawdown profile | sparse paired losses bounded by frozen per-leg stops and one aggregate budget |
| Regime preference | large gold information shock with bounded silver under-response |
| Win rate target | unknown; positive governed economics must be demonstrated |

The implementation should own exactly two opposite legs or none. A failed
second open, orphan, duplicate, same-side pair, missing stop, or notional
mismatch closes every owned leg immediately. Equal notional is a testable
exposure reduction convention, not a beta-neutrality or decorrelation claim.

## 6. Source Citation

**Source ID:** `KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026`

**Source type:** peer-reviewed academic papers plus exchange carrier support

**Pointer:** `strategy-seeds/sources/KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026/source.md`

**R1–R4 verdict:** all PASS; see the approved canonical card and
`decisions/2026-08-16_xauxag_gold_lead_lag_g0.md`.

Krawiec and Gorska (2015) report daily gold-to-silver Granger ordering and an
adverse reverse-direction result. They do not provide coefficient signs or a
trading rule. The same-direction catch-up, thresholds, package construction,
CFD mapping, and risk rules are disclosed QM falsification choices.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Q02 baseline | `RISK_FIXED` | USD 1,000 per logical two-leg package |
| Any live phase | not authorized | no preset or deployment artifact |

The joint volume solve rounds both legs down, targets a 1:1 absolute notional
ratio within 20%, and requires combined normalized frozen-stop risk no greater
than one package budget. `RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1` are locked
in the sole backtest setfile. This build does not authorize AutoTrading,
`T_Live`, portfolio admission, or changes to any live or portfolio manifest.

## Q01 Evidence

- independent mechanic reference suite: 13 tests PASS
- strict compile: 0 errors, 0 warnings
- targeted V5 build check: 0 failures, 0 warnings
- card/schema, seven-section spec, basket manifest, setfile identity: PASS
- static P1 artifact validation: PASS
- build report: `D:/QM/reports/framework/21/build_check_20260816_211706.json`
- P1 report: `D:/QM/reports/pipeline/QM5_41031/P1/P1_QM5_41031_result.json`

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-16 | Initial governed build from approved card | Q01 PASS |
