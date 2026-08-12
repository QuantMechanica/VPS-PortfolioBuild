# QM5_1287_mtf-macd-histogram-divergence — Strategy Spec

**EA ID:** QM5_1287
**Slug:** `mtf-macd-histogram-divergence`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Multi-timeframe MACD histogram-divergence fade. On H4 (anchor timeframe) a
3-bar fractal swing detector maintains the two most recent confirmed
swing-highs and swing-lows. A **bearish regular divergence** latches when
the newest swing-high price exceeds the older one while its MACD(12,26,9)
histogram value is lower (and still above zero) — mirrored for a
**bullish regular divergence** on swing-lows. Once latched, the EA waits
for an H1 (trigger timeframe) MACD-histogram zero-cross in the latched
direction to enter, rejecting the entry only if the H4 EMA(50) slope runs
sharply *with* the trend being faded (`|slope| > 2*ATR(14,H4)`). The latch
expires after 24 H1 bars if unconfirmed. Exit is primarily the opposite H1
histogram zero-cross, secondarily a hard TP at `2*ATR(14,H4)`, tertiarily a
48 H1-bar time-stop. Stop loss sits at the triggering swing extremum plus a
`0.3*ATR(14,H4)` buffer, floored at `0.5*ATR(14,H4)` minimum distance. One
position per symbol per magic; the latch is consumed on entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 2-50 | MACD fast EMA period (H4 anchor + H1 trigger) |
| `strategy_macd_slow` | 26 | 5-100 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 2-50 | MACD signal EMA period |
| `strategy_ema_period` | 50 | 10-200 | H4 regime EMA period |
| `strategy_atr_period` | 14 | 5-100 | H4 ATR period (SL/TP/slope scale) |
| `strategy_atr_tp_mult` | 2.0 | 0.5-5.0 | TP = mult * ATR(14,H4) from entry |
| `strategy_sl_buffer_atr_mult` | 0.3 | 0.0-2.0 | SL buffer beyond the triggering swing extremum |
| `strategy_sl_floor_atr_mult` | 0.5 | 0.1-2.0 | Minimum SL distance floor (ATR units) |
| `strategy_slope_atr_mult` | 2.0 | 0.5-5.0 | EMA(50,H4) slope reject threshold (ATR units) |
| `strategy_latch_max_h1_bars` | 24 | 1-100 | Divergence latch lifetime in H1 bars |
| `strategy_max_hold_h1_bars` | 48 | 1-200 | Tertiary time-stop, H1 bars |
| `strategy_skip_bars_open` | 2 | 0-10 | Skip first N H1 bars of the broker day |
| `strategy_skip_bars_close` | 2 | 0-10 | Skip last N H1 bars of the broker day |
| `strategy_spread_cap_pips` | 25 | 0-200 | Block only a genuinely wide spread (pips) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `EURJPY.DWX` — FX
  majors/crosses with clean H1/H4 MACD structure
- `XAUUSD.DWX` — gold; strong H4 trend/divergence character
- `NDX.DWX`, `WS30.DWX` — index CFDs; H4 momentum with periodic exhaustion
  reversals suited to divergence detection

**Explicitly NOT for:**
- Ultra-low-liquidity exotics — divergence detection needs a clean,
  gap-free H1/H4 series (all eight registered symbols qualify).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | H4 anchor (swing/divergence/EMA/ATR), H1 trigger (MACD zero-cross entry/exit) |
| Bar gating | H4 state advanced on `QM_IsNewBar(_Symbol, PERIOD_H4)`; entry/exit evaluated on the framework's H1 `QM_IsNewBar()` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~6` |
| Typical hold time | `hours to ~2 days (48 H1-bar time-stop ceiling)` |
| Expected drawdown profile | `~22% max DD; single position per symbol` |
| Regime preference | `mean-revert (fades exhausted H4 trend at divergence, rejects only the strongest continuations)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/` — ForexFactory MTF MACD divergence community cluster; underlying mechanic Gerald Appel MACD (1979) + Alexander Elder histogram-divergence (*Trading for a Living*, 1993, Wiley).
**R1–R4 verdict (Q00):** R1 TIER_C / R2–R4 PASS per `artifacts/cards_approved/QM5_1287_mtf-macd-histogram-divergence.md`

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
| v1 | 2026-08-10 | Initial build from card | 0705feeb-6fe5-40ab-8e5a-7f4266633b9e |
