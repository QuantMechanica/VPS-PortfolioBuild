# QM5_10408_et-sample-brk - Strategy Spec

**EA ID:** QM5_10408
**Slug:** `et-sample-brk`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA samples a fixed intraday M1 time window and records that window's high and low. After the sample ends, it places a buy stop if the last closed bar is between the sampled high and the percent-offset long trigger, or a sell stop if the last closed bar is between the sampled low and the percent-offset short trigger. The protective stop is the opposite side of the sample range, the target defaults to 1R, entries are rejected when the stop distance exceeds 2.0 times ATR(20), and all trades or pending entries stop at the daily P/L cutoff or session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sample_start_hhmm` | 1000 | 0000-2359 | Start of the M1 sample window in broker HHMM. |
| `strategy_sample_end_hhmm` | 1001 | 0000-2359 | End of the sample window, exclusive, in broker HHMM. |
| `strategy_session_end_hhmm` | 2200 | 0000-2359 | Time after which new entries are blocked and open trades are closed. |
| `strategy_percent_hi` | 0.001 | >0 | Percent offset above the sampled high for the buy stop trigger. |
| `strategy_percent_low` | 0.001 | >0 | Percent offset below the sampled low for the sell stop trigger. |
| `strategy_atr_period` | 20 | >=1 | ATR period used for the maximum stop-distance filter. |
| `strategy_max_stop_atr_mult` | 2.0 | >0 | Reject entries where stop distance is above this ATR multiple. |
| `strategy_target_rr` | 1.0 | >0 | Take-profit distance as a multiple of initial stop risk. |
| `strategy_daily_profit_cutoff` | 1000.0 | >=0 | Daily symbol/magic P/L level that stops trading and exits open trades. |
| `strategy_daily_loss_cutoff` | 1000.0 | >=0 | Daily symbol/magic loss level that stops trading and exits open trades. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread cap in points; 0 disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - card primary S&P 500 index target; valid backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 index exposure from the card's US index basket.
- `WS30.DWX` - Dow 30 index exposure from the card's US index basket.
- `GDAXI.DWX` - verified DWX DAX custom symbol used in place of card text `GER40.DWX`.
- `XAUUSD.DWX` - gold/metals symbol explicitly named by the card.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the verified DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Intraday; from sample breakout fill until target, stop, daily cutoff, or session end. |
| Expected drawdown profile | Intraday breakout with bounded per-trade risk and daily P/L stop. |
| Regime preference | Breakout / volatility expansion after a fixed sample window. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/easylanguage-code.251026/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10408_et-sample-brk.md`

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
| v1 | 2026-05-25 | Initial build from card | 65f09759-383f-4216-9f35-76ff1e49e94b |
