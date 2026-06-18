# QM5_10439_mql5-asq-break - Strategy Spec

**EA ID:** QM5_10439
**Slug:** mql5-asq-break
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see MQL5 CodeBase citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates completed M5 bars for a seven-condition breakout. A long trade requires EMA(150) above EMA(510), enough EMA separation versus ATR(14), close above both EMAs, a close above the prior 20-bar high plus 0.25 ATR, RSI(14) in the long zone, bullish close-to-close momentum, and H1 EMA50 above EMA200. A short trade mirrors those conditions below the EMAs and below the prior 20-bar low. Exits use the initial ATR stop, a fixed 2R take-profit, framework Friday close, and a move to break-even after price reaches +1R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_ema_period | 150 | >0 | Fast trend EMA on the M5 chart. |
| strategy_slow_ema_period | 510 | >0 | Slow trend EMA on the M5 chart. |
| strategy_atr_period | 14 | >0 | ATR period for separation, breakout buffer, spread guard, and stop distance. |
| strategy_breakout_lookback | 20 | >0 | Number of prior bars used for breakout high/low. |
| strategy_ema_atr_separation | 0.5 | >=0 | Minimum EMA separation as a multiple of M5 ATR. |
| strategy_breakout_atr_buffer | 0.25 | >=0 | Breakout buffer beyond the prior range as a multiple of M5 ATR. |
| strategy_rsi_period | 14 | >0 | RSI period for momentum-zone filtering. |
| strategy_long_rsi_min | 40.0 | 0-100 | Lower bound for long RSI zone. |
| strategy_long_rsi_max | 65.0 | 0-100 | Upper bound for long RSI zone. |
| strategy_short_rsi_min | 35.0 | 0-100 | Lower bound for short RSI zone. |
| strategy_short_rsi_max | 60.0 | 0-100 | Upper bound for short RSI zone. |
| strategy_htf_filter_enabled | true | true/false | Enables H1 EMA50/EMA200 agreement filter. |
| strategy_htf_fast_ema_period | 50 | >0 | Fast EMA for higher-timeframe agreement. |
| strategy_htf_slow_ema_period | 200 | >0 | Slow EMA for higher-timeframe agreement. |
| strategy_sl_atr_mult | 1.2 | >0 | M5 ATR multiple for baseline stop distance. |
| strategy_h1_sl_cap_atr_mult | 3.0 | >0 | H1 ATR multiple used as maximum stop distance cap. |
| strategy_tp_rr | 2.0 | >0 | Fixed reward/risk multiple for take-profit. |
| strategy_session_start_hour | 8 | 0-23 | Broker-time session start hour for new entries. |
| strategy_session_end_hour | 20 | 0-23 | Broker-time session end hour for new entries. |
| strategy_spread_atr_max_frac | 0.15 | >=0 | Maximum modeled spread as a fraction of M5 ATR. |
| strategy_friday_cutoff_hour | 16 | 0-23 | Broker-time Friday hour after which new entries stop. |
| strategy_max_entries_per_day | 3 | >=1 | Maximum entry attempts per broker day. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - card-listed gold CFD target with DWX data availability.
- EURUSD.DWX - card-listed major FX target with DWX data availability.
- GBPUSD.DWX - card-listed major FX target with DWX data availability.
- XAGUSD.DWX - card-listed silver CFD target with DWX data availability.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest registry requires canonical `.DWX` symbols.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/tester data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H1 EMA50/EMA200 agreement; H1 ATR stop cap |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Card does not state an exact hold time; expected intraday M5 scalper holds are minutes to hours. |
| Expected drawdown profile | Card does not state a drawdown target; fixed ATR stop and 2R target imply bounded per-trade loss. |
| Regime preference | Strict intraday breakout with trend and momentum confirmation. |
| Win rate target (qualitative) | Medium; strict conditions trade less often but target 2R exits. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/71189
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10439_mql5-asq-break.md`

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
| v1 | 2026-06-18 | Initial build from card | e66e6a01-cae2-4c6c-9825-e6ab1a1f72ce |
