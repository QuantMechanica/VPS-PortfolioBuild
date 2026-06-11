# QM5_9951_ff-macd-bias-ema48-m15 - Strategy Spec

**EA ID:** QM5_9951
**Slug:** `ff-macd-bias-ema48-m15`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the M15 EMA(4) / EMA(8) cross from the approved ForexFactory MACD bias card. A long entry is allowed when EMA(4) crosses above EMA(8) on the just-closed M15 bar, the closed bar is above both EMAs, and MACD(12,26,9) main is at or above the configured positive threshold. A short entry mirrors the rule below both EMAs with a negative MACD threshold. FX symbols use the card's 10 pip stop and 20 pip target; XAUUSD uses the card's ATR-normalized MACD threshold, 1 ATR stop, and 2R target. Open positions exit by SL, TP, Friday close, or an opposite EMA(4/8) cross.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 4 | integer > 0 and < `strategy_ema_slow` | Fast EMA period used for the arrow/cross rule. |
| `strategy_ema_slow` | 8 | integer > `strategy_ema_fast` | Slow EMA period used for the arrow/cross rule. |
| `strategy_macd_fast` | 12 | integer > 0 and < `strategy_macd_slow` | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | integer > `strategy_macd_fast` | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | integer > 0 | MACD signal period. |
| `strategy_macd_fx_threshold` | 0.0001 | > 0 | Absolute MACD-main threshold for FX symbols. |
| `strategy_atr_period` | 14 | integer > 0 | ATR period for spread filtering and XAUUSD normalization. |
| `strategy_macd_atr_mult` | 0.10 | > 0 | XAUUSD MACD threshold as a multiple of ATR(14). |
| `strategy_fx_sl_pips` | 10 | integer > 0 | Fixed FX stop distance in pips. |
| `strategy_fx_tp_pips` | 20 | integer > 0 | Fixed FX take-profit distance in pips. |
| `strategy_atr_sl_mult` | 1.0 | > 0 | XAUUSD stop distance as a multiple of ATR(14). |
| `strategy_atr_tp_rr` | 2.0 | > 0 | XAUUSD take-profit multiple of initial risk. |
| `strategy_session_start_h` | 7 | 0-23 | Broker-time session start hour, inclusive. |
| `strategy_session_end_h` | 18 | 0-23 | Broker-time session end hour, exclusive. |
| `strategy_max_spread_atr` | 0.15 | >= 0 | Maximum allowed spread as a fraction of ATR(14). |

Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major from the card's R3 P2 basket; uses the 10/20 pip bracket.
- `GBPUSD.DWX` - FX major from the card's R3 P2 basket; uses the 10/20 pip bracket.
- `USDJPY.DWX` - FX major from the card's R3 P2 basket; uses the 10/20 pip bracket.
- `XAUUSD.DWX` - Metal from the card's R3 P2 basket; uses the ATR-normalized fallback.

**Explicitly NOT for:**
- Index `.DWX` symbols - the card states this is not SP500-specific and names only FX/XAU symbols.
- Energy `.DWX` symbols - not part of the approved R3 basket.
- Unlisted FX crosses - not part of the approved R3 P2 basket for this build.

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
| Trades / year / symbol | `120` |
| Typical hold time | Not specified in card frontmatter; expected to be M15 scalp duration governed by 10/20 pip bracket or opposite EMA cross. |
| Expected drawdown profile | Not specified in card frontmatter; fixed 1R stop per trade with no averaging, grid, or martingale. |
| Regime preference | Not specified in card frontmatter; mechanical EMA/MACD momentum continuation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** jamesagnew, "MACD and bias method", ForexFactory, 2025, https://www.forexfactory.com/thread/post/15450120
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9951_ff-macd-bias-ema48-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | 7bbec1c0-c77b-4243-9572-c8447f210193 |
