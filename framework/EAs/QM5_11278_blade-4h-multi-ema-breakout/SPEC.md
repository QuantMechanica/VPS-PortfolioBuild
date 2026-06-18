# QM5_11278_blade-4h-multi-ema-breakout — Strategy Spec

**EA ID:** QM5_11278
**Slug:** `blade-4h-multi-ema-breakout`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A H4 trend-aligned consolidation-breakout. Four EMAs (30/150/200/365) define the
regime: EMA(30) is the trend gauge and the 150/200/365 EMAs act as the dynamic
support/resistance stack. The multi-EMA stack alignment is a STATE; the breakout
is the single EVENT. Long when EMA(30) slopes up and price is above it, the
150/200/365 stack is bullishly ordered (EMA150 > EMA200 > EMA365), and the
just-closed H4 bar closes through the prior N-bar consolidation high for the
first time (close[1] > level, close[2] <= level) with a large body
(range > ATR(14)). To trade the retest rather than the runaway, the breakout
bar's low must sit within ATR×0.30 of the broken level. Short is the mirror.
The stop sits behind the broken S/R (structure low/high), floored to at least 25
pips. Position is moved to break-even at +1R and then trailed by ATR(14)×1.5;
exit early if EMA(30) flips against the trade. Gapless .DWX CFDs mean the
breakout uses the prior CLOSE, never an intrabar gap/range.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_trend_period` | 30 | 10-60 | EMA(30) trend-direction gauge |
| `strategy_ema_mid_period` | 150 | 100-200 | EMA(150) dynamic S/R (stack) |
| `strategy_ema_long_period` | 200 | 150-300 | EMA(200) dynamic S/R (stack) |
| `strategy_ema_max_period` | 365 | 250-500 | EMA(365) dynamic S/R (stack) |
| `strategy_ema_slope_bars` | 5 | 2-15 | bars back to gauge EMA(30) slope |
| `strategy_break_lookback` | 12 | 6-40 | consolidation window for the broken S/R level |
| `strategy_atr_period` | 14 | 7-28 | ATR(14): breakout body + retest band + trail |
| `strategy_break_body_mult` | 1.0 | 0.5-2.0 | breakout-bar range > ATR × this (volume-spike proxy) |
| `strategy_retest_band_atr` | 0.30 | 0.1-1.0 | retest within ATR × this of broken level |
| `strategy_sl_struct_lookback` | 6 | 3-20 | structure-stop lookback (behind broken S/R) |
| `strategy_sl_floor_pips` | 25 | 10-50 | min stop distance behind entry (card: 20-25 pips) |
| `strategy_be_trigger_r` | 1.0 | 0.5-2.0 | move SL to break-even at +this × initial risk |
| `strategy_trail_atr_mult` | 1.5 | 0.5-3.0 | ATR(14) trailing-stop multiple |
| `strategy_spread_pct_of_stop` | 20.0 | 5-50 | skip if spread > this % of ATR stop reference |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair, deep liquidity, clean H4 trend/consolidation structure
- `GBPUSD.DWX` — major FX pair, strong H4 trending behaviour suited to breakout-retest
- `USDJPY.DWX` — major FX pair, persistent H4 trends; pip-scale handled via pip_factor
- `AUDUSD.DWX` — commodity-linked major, trends well on H4
- `EURJPY.DWX` — JPY cross with pronounced H4 trends and clean S/R retests

**Explicitly NOT for:**
- Index/metal CFDs (`NDX.DWX`, `XAUUSD.DWX`, etc.) — card scopes FX majors only; EMA(365)
  S/R stack and pip-based stop floor are tuned to FX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~50` |
| Typical hold time | `several hours to a few days` |
| Expected drawdown profile | `moderate; trend-following with structural stop + ATR trail` |
| Regime preference | `breakout` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** `The Blade Forex Strategies — ForexSuccessSecrets.com PDF, "4H Breakout System" (pp. 26-50)`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11278_blade-4h-multi-ema-breakout.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
