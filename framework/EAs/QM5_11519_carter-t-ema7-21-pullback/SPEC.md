# QM5_11519_carter-t-ema7-21-pullback - Strategy Spec

**EA ID:** QM5_11519
**Slug:** carter-t-ema7-21-pullback
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf (see `strategy-seeds/sources/8794b680-f6f4-5142-b12c-e5e0057e7bcf/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades the Carter EMA(7/21) pullback pattern on H1. For long entries, EMA(7) must be above EMA(21), EMA(21) must be rising versus the configured lookback, the last closed bar must close above EMA(7), and that bar's low must touch EMA(21). The EA then places a BuyStop one pip above the pullback bar high, with a 25-pip stop and a 2R take profit. Short entries mirror the same rule with EMA(7) below EMA(21), falling EMA(21), price below EMA(7), a high touch of EMA(21), and a SellStop one pip below the pullback bar low.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 7 | 1-200 | Fast EMA period for trend alignment. |
| `strategy_ema_slow_period` | 21 | 2-300 | Slow EMA period used as trend filter and pullback line. |
| `strategy_ema_rising_lookback` | 3 | 2-20 | Closed-bar shift used to confirm EMA(21) rising or falling. |
| `strategy_sl_pips` | 25 | 1-30 | Fixed stop distance in pips, capped by the card's P2 note. |
| `strategy_tp_rr` | 2.0 | 0.1-10.0 | Take profit as a multiple of stop distance. |
| `strategy_pending_offset_pips` | 1 | 1-20 | Pending stop offset beyond the pullback bar high or low. |
| `strategy_expiry_bars` | 3 | 1-24 | Pending order expiry in bars. |
| `strategy_no_friday_entry` | true | true/false | Suppresses new entries on Fridays. |
| `strategy_spread_pct_of_stop` | 15.0 | 0.0-100.0 | Blocks entry only when live spread exceeds this percent of the stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed live-tradable DWX FX instrument for the Carter H1 pullback system.
- `GBPUSD.DWX` - card-listed live-tradable DWX FX instrument for the Carter H1 pullback system.
- `AUDUSD.DWX` - card-listed live-tradable DWX FX instrument for the Carter H1 pullback system.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research and backtest pipeline requires canonical `.DWX` symbols.
- Index and commodity symbols - the approved card names only EURUSD, GBPUSD, and AUDUSD FX instruments.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Not stated in card frontmatter; expected to be intraday-to-multiday because exits are fixed SL/TP on H1 pending stop entries. |
| Expected drawdown profile | Not stated in card frontmatter; trend-pullback fixed-risk profile with losses bounded by fixed 25-pip SL per trade. |
| Regime preference | Trend continuation after pullback to EMA(21). |
| Win rate target (qualitative) | Not stated in card frontmatter; medium expectation due 2R target. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #16, self-published 2014.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11519_carter-t-ema7-21-pullback.md`

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
| v1 | 2026-06-20 | Initial build from card | 52c75c99-165f-4b11-ba04-6d83582c0450 |
