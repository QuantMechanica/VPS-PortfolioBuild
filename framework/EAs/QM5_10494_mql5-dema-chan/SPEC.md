# QM5_10494_mql5-dema-chan - Strategy Spec

**EA ID:** QM5_10494
**Slug:** `mql5-dema-chan`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades a closed-bar breakout of a DEMA range channel on H8. The upper channel is DEMA(high) shifted forward by the channel shift, and the lower channel is DEMA(low) shifted the same way. A long entry triggers when Close[1] crosses above the shifted upper channel; a short entry triggers when Close[1] crosses below the shifted lower channel. Exits occur at the ATR stop, the 2R target, a fixed 1920-minute holding-time limit, or the next opposite channel breakout.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H8` | M1-MN1 | Timeframe used for DEMA channel signals. |
| `strategy_dema_period` | `14` | 2-200 | DEMA period for high and low channel lines. |
| `strategy_channel_shift_bars` | `3` | 0-20 | Channel line shift in bars used by the source indicator. |
| `strategy_price_shift_points` | `0.0` | 0-1000 | Vertical point offset applied to upper/lower channel lines. |
| `strategy_atr_period` | `14` | 2-200 | ATR period for protective stop and ATR floor. |
| `strategy_atr_sl_mult` | `1.5` | 0.1-10.0 | ATR multiplier for initial stop distance. |
| `strategy_target_rr` | `2.0` | 0.1-10.0 | Take-profit multiple of initial risk. |
| `strategy_hold_minutes` | `1920` | 1-10080 | Maximum position holding time in minutes. |
| `strategy_min_atr_points` | `20.0` | 0-10000 | Minimum ATR floor in points before entries are allowed. |
| `strategy_max_spread_points` | `35` | 0-10000 | Maximum allowed current spread in points. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair in the card's portable P2 basket.
- `EURJPY.DWX` - source test symbol family and explicitly listed by the card.
- `GBPUSD.DWX` - liquid major FX pair in the card's portable P2 basket.
- `XAUUSD.DWX` - liquid metal symbol included by the card for OHLC channel breakout testing.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 backtest framework requires canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H8` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | Fixed holding-time exit at 1920 minutes, with earlier SL/TP or opposite breakout exits. |
| Expected drawdown profile | Conservative ATR-defined loss per failed breakout. |
| Regime preference | Breakout / volatility expansion. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/21558`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10494_mql5-dema-chan.md`

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
| v1 | 2026-05-28 | Initial build from card | 32d408fe-320e-4101-8b57-05dfab596fce |
