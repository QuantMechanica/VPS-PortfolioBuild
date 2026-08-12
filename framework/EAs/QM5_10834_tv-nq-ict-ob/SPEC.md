# QM5_10834_tv-nq-ict-ob — Strategy Spec

**EA ID:** QM5_10834
**Slug:** `tv-nq-ict-ob`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (sealed public Pine bytes: `docs/candidate-analysis/primary_source_pine_v1.pine`)
**Author of this spec:** Codex
**Last revised:** 2026-07-20

---

## 1. Strategy Logic

The EA trades a New York morning liquidity sweep and order-block mitigation setup on closed bars. It first requires a daily EMA(20) directional bias, then a sweep of the previous-day high or low during the half-open `[09:45, 10:15)` New York window, followed on a strictly later bar by a fresh close-cross through the last 5-bar fractal swing level. The first MSS freezes the last opposite candle as the order block. Mitigation is eligible only on another strictly later closed bar. Exits are the order-block stop, a fixed 2.0R target, or a forced flat at 10:15 New York even during a news blackout.

The distinct-bar FSM (`WAIT_SWEEP -> WAIT_MSS -> WAIT_MITIGATION`) is an
outcome-blind causal tightening of the public OHLC script: it prevents an
unknowable within-bar ordering from being treated as sweep, break and retrace
simultaneously.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_start_hhmm` | 945 | 0-2359 | New York entry window start time. |
| `strategy_entry_end_hhmm` | 1015 | 0-2359 | New York entry window end time and force-flat threshold. |
| `strategy_daily_ema_period` | 20 | 2-200 | Daily EMA period for directional bias. |
| `strategy_bias_mode` | `BIAS_CURRENT_PRICE` | enum | Use current closed-bar price or previous daily close against daily EMA(20). |
| `strategy_fractal_width` | 5 | 3-7 | Fractal swing width used for market-structure shift. |
| `strategy_fractal_lookback` | 60 | 10-200 | Maximum closed bars searched for the most recent fractal swing. |
| `strategy_ob_lookback` | 20 | 3-100 | Maximum closed bars searched for the last opposite candle before MSS. |
| `strategy_ob_refinement` | `OB_DEFENSIVE_ATR55` | enum | Public Pine v1 refinement: full wick range when source-candle range is <=0.5 ATR(55); otherwise low-to-close for bullish OBs and close-to-high for bearish OBs. Aggressive/full modes use the full wick range. |
| `strategy_ob_refine_atr_period` | 55 | 55 | ATR period bound to the public Pine v1 order-block refinement. Not a tuning axis. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop-distance safety checks. |
| `strategy_min_stop_atr` | 0.25 | 0.05-2.0 | Minimum allowed stop distance as ATR multiple. |
| `strategy_max_stop_atr` | 2.0 | 0.5-10.0 | Maximum allowed stop distance as ATR multiple. |
| `strategy_target_r` | 2.0 | 1.0-5.0 | Fixed target in R multiple. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional spread gate; 0 disables the gate. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — closest DWX Nasdaq 100 target for the original NQ/MNQ concept.
- `WS30.DWX` — US large-cap index proxy from the card's portable basket.
- `GDAXI.DWX` — matrix-valid DAX symbol used for the card's GER40 exposure.
- `XAUUSD.DWX` — liquid DWX metal symbol listed in the card's R3 basket.
- `EURUSD.DWX` — liquid DWX forex symbol listed in the card's R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SP500.DWX` — mentioned only as a possible later test path, not part of this card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_D1` for previous-day levels and EMA(20) bias |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Intraday; normally minutes, forced flat after the NY morning window. |
| Expected drawdown profile | Sparse, high-confluence index-open losses with slippage sensitivity. |
| Regime preference | Liquidity sweep into short-term volatility expansion. |
| Win rate target (qualitative) | Medium; fixed 2R target allows lower win rate. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView `NQ 9:45-10:15 ICT Strategy - Complete`, author `uzair2join`, https://www.tradingview.com/script/8NHRB35j-NQ-9-45-10-15-ICT-Strategy-Complete/
**Public Pine endpoint:** `https://pine-facade.tradingview.com/pine-facade/get/PUB%3Baa5cd40f93284855a7ac93cec5a26bd3/1`
**Public Pine v1 source SHA-256:** `015bb5d550a8687f506646de6c33ddfe8b29c3ed5e4ec96f3c66364edfb7f0b5`
**Sealed local bytes:** `docs/candidate-analysis/primary_source_pine_v1.pine` (UTF-8 without BOM, original CRLF bytes)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10834_tv-nq-ict-ob.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

`QM_FrameworkInit` enforces that exactly one of fixed-risk and percentage-risk
is positive. Environment-to-mode policy is bound by the generated setfile and
build/pipeline contract; the framework does not currently infer an environment
inside the EA.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | e05d0d9b-643a-4634-a7d9-a69e370d965b |
| v2 | 2026-07-20 | Outcome-blind fidelity repair | Strict event FSM, closed-bar session binding, ATR55 source refinement, fail-closed data bias, post-confirmed daily trade flag, restart restoration, and news-safe force-flat. |
