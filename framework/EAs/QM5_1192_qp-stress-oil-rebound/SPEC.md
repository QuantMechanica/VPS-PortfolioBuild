# QM5_1192_qp-stress-oil-rebound — Strategy Spec

**EA ID:** QM5_1192
**Slug:** `qp-stress-oil-rebound`
**Source:** `7ede58dd-d184-5099-9d48-7a65de230853`
**Author of this spec:** Codex
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

At each completed D1 bar, the EA calculates close-to-close returns for
`SP500.DWX` and `XAUUSD.DWX`. When both returns are below the configured stress
threshold, it opens one long position in the oil proxy assigned to the current
magic slot. The initial stop is 1.5 times the completed-bar ATR(20), and the
position closes at the next D1 close, with a two-trading-day safety exit.

The strategy is a cross-asset stress-reversal rule. It does not use machine
learning, external APIs, external CSV signals, trailing stops, or partial exits.

---

## 2. Parameters

| Parameter | Default | Valid range / contract | Meaning |
|---|---:|---|---|
| `strategy_equity_signal_symbol` | `SP500.DWX` | non-empty DWX symbol | Equity return used as the first stress leg. |
| `strategy_gold_signal_symbol` | `XAUUSD.DWX` | non-empty DWX symbol | Gold return used as the second stress leg. |
| `strategy_oil_primary_symbol` | `XTIUSD.DWX` | slot 0 trade symbol | Current governed oil proxy. |
| `strategy_oil_fallback_symbol` | `XBRUSD.DWX` | slot 1 only | Historical Brent fallback; its DWX history is retired and slot 1 is not eligible for a new run. |
| `strategy_stress_threshold_pct` | `0.0` | percentage | Both signal returns must be strictly below this threshold. |
| `strategy_atr_period_d1` | `20` | integer greater than 0 | D1 ATR period for the initial stop. |
| `strategy_atr_sl_mult` | `1.5` | number greater than 0 | ATR multiple for the initial stop. |
| `strategy_safety_hold_days` | `2` | integer at least 1 | Maximum D1-bar hold if the next-close exit is unavailable. |
| `strategy_min_d1_bars` | `30` | at least `max(ATR period + 5, 10)` | Minimum history required by the signal legs. |
| `strategy_max_spread_points` | `0` | 0 disables; positive values cap spread | Optional entry spread ceiling. |

Framework-level risk, news, Friday-close, seed, and portfolio inputs are
documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — governed slot 0 trade instrument and the only symbol in the
  current Q02 recovery scope.
- `SP500.DWX` — read-only equity stress signal leg.
- `XAUUSD.DWX` — read-only gold stress signal leg.

**Explicitly not eligible for a new run:**

- `XBRUSD.DWX` — historical slot 1 fallback whose custom-history row was
  retired on 2026-08-12. It remains documented for registry lineage only.
- All non-oil host symbols — the EA's no-trade filter requires the host symbol
  to match the oil proxy assigned to its magic slot.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `SP500.DWX` D1 and `XAUUSD.DWX` D1 |
| Bar gating | `QM_IsNewBar()` on the host D1 chart |
| Signal data | Completed bars only (`shift >= 1`) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 20 |
| Typical hold time | One trading day; two days maximum |
| Expected drawdown profile | Episodic losses around cross-asset stress clusters, bounded per trade by the ATR stop |
| Regime preference | Short-horizon stress mean reversion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This strategy was mechanised from the approved local strategy card:

**Source ID:** `7ede58dd-d184-5099-9d48-7a65de230853`

**Source type:** Quantpedia research encyclopedia

**Named author:** Cyril Dujava

**Pointer:** `docs/strategy_card.md` and
`quantpedia.com/short-term-correlated-stress-reversal-trading/`

**Approval record:** `docs/strategy_card.md` declares `g0_status: APPROVED` and
records the mechanical entry, exit, stop, sizing, and data caveats used here.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-26 | Initial build from approved card | Original V5 build wave |
| v2 | 2026-08-18 | Q02 infrastructure recovery | Canonical Q01 spec schema; signal mechanics unchanged |
