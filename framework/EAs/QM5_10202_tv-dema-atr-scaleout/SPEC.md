# QM5_10202_tv-dema-atr-scaleout - Strategy Spec

**EA ID:** QM5_10202
**Slug:** `tv-dema-atr-scaleout`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades H1 directional shifts in a DEMA baseline. A long signal occurs when the latest closed-bar DEMA slope turns bullish after a non-bullish prior slope; a short signal occurs when the latest closed-bar DEMA slope turns bearish after a non-bearish prior slope. Entries use market orders with an initial stop at 1.5 * ATR(14) and a full-position target at 2.0 * ATR(14). If an opposite DEMA shift appears while a position is open, the EA closes the position at market and opens the reverse side on the following H1 bar.

The card references an "adjusted DEMA" but does not define the exact envelope adjustment formula beyond DEMA plus ATR context. This build implements the most literal mechanical reading available from the card: closed-bar DEMA slope for direction, ATR for stop/target and spread gating.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_dema_period` | 34 | >= 2 | DEMA period used for closed-bar trend-state shifts. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used for warmup, stop, target, and spread checks. |
| `strategy_atr_sl_mult` | 1.5 | > 0 | Initial stop distance as an ATR multiple. |
| `strategy_atr_tp_mult` | 2.0 | > 0 | Full-position target distance as an ATR multiple. |
| `strategy_spread_stop_max` | 0.15 | >= 0 | Maximum allowed spread as a fraction of stop distance. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid DWX FX major.
- `GBPUSD.DWX` - card target; liquid DWX FX major.
- `XAUUSD.DWX` - card target; DWX gold CFD supports the ATR trend logic.
- `GDAXI.DWX` - registered DAX port for card-stated `GER40.DWX`, which is not present in the DWX matrix.
- `NDX.DWX` - card target; liquid DWX Nasdaq 100 index CFD.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Any symbol without an active row for `QM5_10202` in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; `QM_IsNewBar(_Symbol, PERIOD_H1)` for open-position opposite-signal exits |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | hours to days, bounded by ATR target/stop and opposite DEMA shifts |
| Expected drawdown profile | trend-following whipsaw risk in sideways regimes; per-trade risk bounded by HR4 framework sizing |
| Regime preference | trend-following / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** TradingView script `DEMA ATR Strategy [PrimeAutomation]`, author handle `ChartPrime`, published 2025-11-25 and updated 2026-03-19, https://www.tradingview.com/script/rqRd3f62-DEMA-ATR-Strategy-PrimeAutomation/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10202_tv-dema-atr-scaleout.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | 394af65f-e046-4b17-aacd-0c92744f4373 |
