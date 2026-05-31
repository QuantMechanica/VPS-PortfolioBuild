# QM5_10687_tv-parent-sweep - Strategy Spec

**EA ID:** QM5_10687
**Slug:** `tv-parent-sweep`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA tracks Asia, London, and New York broker-time sessions. After a completed child session is fully contained inside its parent session range, the parent high and low become the trade map. A long entry fires when a closed bar sweeps below the parent low and closes back above that low; a short entry fires when a closed bar sweeps above the parent high and closes back below that high. The target is the opposite parent-session level, the stop is the sweep extreme plus the configured ATR buffer, and open trades are closed at the next configured session end if neither stop nor target is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_asia_start_hour` | 0 | 0-23 | Broker-time hour when the Asia session starts. |
| `strategy_asia_end_hour` | 8 | 0-24 | Broker-time hour when the Asia session ends. |
| `strategy_london_start_hour` | 8 | 0-23 | Broker-time hour when the London session starts. |
| `strategy_london_end_hour` | 16 | 0-24 | Broker-time hour when the London session ends. |
| `strategy_newyork_start_hour` | 13 | 0-23 | Broker-time hour when the New York session starts. |
| `strategy_newyork_end_hour` | 21 | 0-24 | Broker-time hour when the New York session ends. |
| `strategy_min_rr` | 1.5 | 1.0-2.0 | Minimum projected reward-to-risk from entry to opposite parent level. |
| `strategy_reclaim_filter` | true | true/false | Requires a bullish reclaim candle for longs and bearish reclaim candle for shorts. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used for the stop buffer. |
| `strategy_stop_atr_buffer` | 0.10 | 0.0-0.25 | ATR fraction added beyond the sweep extreme for the stop. |
| `strategy_max_spread_points` | 60 | 0-500 | Blocks new entries when spread is above this point threshold; 0 disables. |
| `strategy_rollover_start_hhmm` | 2355 | 0-2359 | Start of broker-time rollover no-trade window. |
| `strategy_rollover_end_hhmm` | 5 | 0-2359 | End of broker-time rollover no-trade window. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with liquid intraday session structure.
- `GBPUSD.DWX` - FX major with liquid London and New York sweeps.
- `USDJPY.DWX` - FX major with Asia, London, and New York participation.
- `XAUUSD.DWX` - Metal market explicitly covered by the card's FX/metals/index scope.
- `GDAXI.DWX` - Canonical DWX DAX symbol for the card's `GER40.DWX` index target.

**Explicitly NOT for:**
- Non-DWX symbols - the build and pipeline require canonical DWX registry symbols.
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Intraday, from reclaim confirmation to session end or parent-range target. |
| Expected drawdown profile | Session-range reversal drawdowns during noisy overlapping sessions. |
| Regime preference | Mean-revert after liquidity sweep. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/idsNSGg2-Parent-Session-Sweeps-Alert/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10687_tv-parent-sweep.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-31 | Initial build from card | 73bd6f1b-a86b-4c7d-afec-90a5fb77b1eb |
