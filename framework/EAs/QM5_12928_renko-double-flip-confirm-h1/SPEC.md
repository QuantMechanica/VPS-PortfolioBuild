# QM5_12928_renko-double-flip-confirm-h1 — Strategy Spec

**EA ID:** QM5_12928
**Slug:** renko-double-flip-confirm-h1
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Gemini
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

Implements a deterministic Renko chart double-flip confirmation trend strategy on H1 bars. Renko brick sizes are computed once per week at Monday 00:00 broker time as `BRICK_PIPS = round(ATR(14, H1) * 0.5 / pip)` and remain frozen throughout the trading week. The strategy tracks Renko block sequence states using a standard reversal rule of 2 bricks.

- **Entry Signals**:
  - **BUY**: Enters long at the close of an H1 bar when the Renko block sequence produces its second consecutive bullish brick (`last = +1, second_last = +1`) following a bearish sequence (`third_last = -1`). Requires re-arm condition (at least one bearish brick printed since last BUY exit).
  - **SELL**: Enters short when the Renko block sequence produces its second consecutive bearish brick (`last = -1, second_last = -1`) following a bullish sequence (`third_last = +1`). Requires re-arm condition (at least one bullish brick printed since last SELL exit).
- **Position Management & Exits**:
  - **Hard SL**: Initial stop loss placed at 2.0 × `BRICK_PIPS` excursion from entry.
  - **Take Profit**: 3.0 × `BRICK_PIPS` limit order.
  - **Trail-by-brick**: Once at least 2 favorable bricks have closed since entry, the SL trails to the opposite-side wick/boundary of the most recently closed brick (`last_brick_close - brick_size` for BUY, `last_brick_close + brick_size` for SELL).
  - **Reverse-flip exit**: If a single opposite-color brick prints while in position, the position is immediately liquidated at market.
  - **Time stop**: Maximum hold time of 48 H1 bars (2 trading days).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 5-50 | ATR period on H1 for weekly brick sizing |
| `strategy_brick_atr_mult` | 0.5 | 0.2-1.5 | ATR multiplier for weekly brick sizing |
| `strategy_reversal_rule` | 2 | 2-4 | Number of bricks required for a Renko direction reversal |
| `strategy_tp_brick_mult` | 3.0 | 1.5-6.0 | Take profit distance in brick units |
| `strategy_sl_brick_mult` | 2.0 | 1.0-4.0 | Initial hard stop loss distance in brick units |
| `strategy_trail_brick_threshold` | 2 | 1-5 | Favorable bricks required before trailing stop activates |
| `strategy_time_stop_bars` | 48 | 24-120 | Maximum holding duration in H1 bars |
| `strategy_max_spread_mult` | 1.5 | 1.0-3.0 | Spread filter ceiling multiplier vs 20-bar median spread |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for.

**Designed for:**
- FX majors: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`
- Metals: `XAUUSD.DWX`
- Index CFDs: `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, `WS30.DWX`

**Explicitly NOT for:**
- Non-liquid or exotic crosses without sufficient H1 historical tick quality.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H1)` |

---

## 5. Expected Behaviour

How this EA should behave in production.

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 - 60 |
| Typical hold time | 4 - 24 hours |
| Expected drawdown profile | Well-contained due to 2-brick hard stop and early reverse-flip liquidation |
| Regime preference | Strong directional trending and breakout regimes |
| Win rate target (qualitative) | medium-high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** book / forum cluster
**Pointer:** Steve Nison, *Beyond Candlesticks* (Wiley 1994) + ForexFactory Renko Double-Flip thread cluster
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12928_renko-double-flip-confirm-h1.md`

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
| v1 | 2026-08-21 | Initial build from approved card | 3b5aa26f-a1b7-4089-8de5-5c425c6444a1 |
