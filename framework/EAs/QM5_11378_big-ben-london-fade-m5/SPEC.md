# QM5_11378_big-ben-london-fade-m5 - Strategy Spec

**EA ID:** QM5_11378
**Slug:** big-ben-london-fade-m5
**Source:** e803fe2b-2ca3-50af-a4b5-3cafbebac42d
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA measures the candle-body range from 00:00 through 06:55 GMT on M5 bars. If price closes below that range during 07:00-08:00 GMT, it waits for the next bullish M5 candle that closes back above the range low and buys; if price closes above the range, it waits for the next bearish candle that closes back below the range high and sells. Take profit is the Asia body range width clipped to 20-60 pips, stop loss is one pip beyond the spike candle and capped at 25 pips, and any open trade is closed at 09:00 GMT.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_start_hhmm_utc` | 0 | 0-2359 | GMT start of the Asia body-range window. |
| `strategy_range_end_hhmm_utc` | 700 | 0-2359 | GMT end of the Asia body-range window. |
| `strategy_spike_start_hhmm_utc` | 700 | 0-2359 | GMT start of the pre-London spike window. |
| `strategy_spike_end_hhmm_utc` | 800 | 0-2359 | GMT end of the spike-detection window. |
| `strategy_entry_end_hhmm_utc` | 830 | 0-2359 | Last GMT time for re-entry candle entries. |
| `strategy_time_stop_hhmm_utc` | 900 | 0-2359 | GMT time stop for any open trade. |
| `strategy_min_range_pips` | 15 | 1-100 | Minimum Asia body-range width required to trade. |
| `strategy_tp_min_pips` | 20 | 1-200 | Lower clip for range-width take profit. |
| `strategy_tp_max_pips` | 60 | 1-300 | Upper clip for range-width take profit. |
| `strategy_sl_buffer_pips` | 1 | 0-20 | Extra stop buffer beyond the spike candle. |
| `strategy_sl_max_pips` | 25 | 1-200 | Maximum stop distance from entry. |
| `strategy_spread_cap_pips` | 20 | 1-100 | Maximum modeled spread allowed for new entries. |
| `strategy_lookback_bars` | 220 | 100-500 | M5 bars scanned once per closed bar to rebuild same-day session state. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - card primary instrument and direct London-open FX target.
- `EURUSD.DWX` - card secondary instrument with liquid European-session behavior.
- `USDJPY.DWX` - card secondary instrument with available M5 DWX data.

**Explicitly NOT for:**
- Non-FX index `.DWX` symbols - the source is a London-open FX range fade.
- Forex pairs outside the card basket - not approved in the R3 portable set.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Intraday, from re-entry candle until TP/SL or 09:00 GMT |
| Expected drawdown profile | Mean-reversion losses cluster on strong London continuation mornings. |
| Regime preference | Counter-trend mean-revert after pre-London stop-run spikes |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** e803fe2b-2ca3-50af-a4b5-3cafbebac42d
**Source type:** local PDF
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\450251566-Big-Ben-Breakout-Strategy-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11378_big-ben-london-fade-m5.md`

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
| v1 | 2026-06-23 | Initial build from card | e834b759-ba0c-4f50-b8bc-ca3e0ff2e74d |
