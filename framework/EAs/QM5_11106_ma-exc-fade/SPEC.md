# QM5_11106_ma-exc-fade — Strategy Spec

**EA ID:** QM5_11106
**Slug:** `ma-exc-fade`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (EarnForex MA-MaxExcursion, GitHub)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Mean-reversion fade of an over-extended swing back to its moving average. The EA
tracks the maximum excursion (largest deviation of close from a 20-period SMA)
over each segment between two consecutive price/MA crosses. When price has
stretched well below the MA and then closes back above it (a fresh upward
cross-back on the last completed H1 bar), the EA goes LONG to fade the prior
down-excursion; the mirror down-cross after a large up-excursion goes SHORT.

A fade fires only if the just-completed excursion segment is large: both at or
above the median of the last 20 same-direction excursions AND at least
`0.8 * ATR(14)` (whipsaw filter). The hard stop is `1.8 * ATR(14)` from entry.
There is no fixed take-profit: a long exits on the next cross below the MA, a
short on the next cross above; a safety time stop closes any position still open
after 24 H1 bars. Segment reconstruction runs once per closed bar, bounded to a
400-bar history scan.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 20 | 10-50 | SMA period for the cross / excursion reference (source default) |
| `strategy_stats_count` | 20 | 5-50 | Number of recent same-side excursions used for the median qualifier |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the excursion filter and stop |
| `strategy_exc_atr_mult` | 0.8 | 0.3-2.0 | Minimum excursion size as a multiple of ATR (whipsaw filter) |
| `strategy_sl_atr_mult` | 1.8 | 1.0-3.0 | Hard-stop distance as a multiple of ATR |
| `strategy_time_stop_bars` | 24 | 6-72 | Safety time stop in H1 bars |
| `strategy_scan_max_bars` | 400 | 100-1000 | Bounded history scan depth for segment reconstruction |
| `strategy_spread_pct_of_stop` | 15.0 | 5-50 | Skip a bar only if spread exceeds this % of stop distance (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean MA mean-reversion behaviour on H1
- `GBPUSD.DWX` — liquid major with sufficient excursion amplitude to fade
- `USDJPY.DWX` — liquid major; pip-scale handled via QM stop helpers
- `XAUUSD.DWX` — high-volatility metal; large excursions suit the ATR-scaled fade

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500.DWX) — card scope is the FX+gold basket; index
  excursion dynamics not validated for this fade.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | `hours to a few days (mean-reversion, time-stopped at 24 H1 bars)` |
| Expected drawdown profile | `moderate; ATR-scaled 1.8× stop bounds per-trade loss` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum` (EarnForex indicator repository / GitHub)
**Pointer:** `https://github.com/EarnForex/MA-MaxExcursion`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11106_ma-exc-fade.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
