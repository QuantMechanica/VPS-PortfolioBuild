# QM5_10904_carter-wpr-smma - Strategy Spec

**EA ID:** QM5_10904
**Slug:** `carter-wpr-smma`
**Source:** `6facee24-8a58-5bbf-88e9-38d44291db50` (see `strategy-seeds/sources/6facee24-8a58-5bbf-88e9-38d44291db50/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades EURUSD.DWX and GBPUSD.DWX on H1. A long entry is opened after the closed candle crosses above SMMA(55) applied to High, Williams R(55) crosses above -25, and Stochastic(5,5,5) K is above D. A short entry is opened after the closed candle crosses below SMMA(55) applied to Low, Williams R(55) crosses below -75, and Stochastic(5,5,5) K is below D. Initial stop is placed beyond the recent swing extreme with a 2 pip buffer, take profit is 2R, and channel-close exits close longs below the high-SMMA or shorts above the low-SMMA.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_smma_period` | 55 | 2+ | SMMA period applied separately to High and Low for channel entry and exit. |
| `strategy_wpr_period` | 55 | 2+ | Williams R lookback period. |
| `strategy_wpr_long_level` | -25.0 | -100 to 0 | Long threshold crossed upward by Williams R. |
| `strategy_wpr_short_level` | -75.0 | -100 to 0 | Short threshold crossed downward by Williams R. |
| `strategy_stoch_k` | 5 | 2+ | Stochastic K period. |
| `strategy_stoch_d` | 5 | 2+ | Stochastic D period. |
| `strategy_stoch_slowing` | 5 | 2+ | Stochastic slowing period. |
| `strategy_swing_lookback` | 10 | 1+ | Recent bars used for swing stop placement. |
| `strategy_stop_buffer_pips` | 2 | 0+ | Buffer beyond the swing high or swing low. |
| `strategy_take_profit_rr` | 2.0 | 0.1+ | Take-profit multiple of initial stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Source card explicitly names EURUSD and the DWX matrix verifies it is available.
- `GBPUSD.DWX` - Source card explicitly names GBPUSD and the DWX matrix verifies it is available.

**Explicitly NOT for:**
- Other `.DWX` symbols - The card names only EURUSD or GBPUSD and does not authorize basket expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Not specified in card frontmatter; H1 entries with 2R or channel-close exits are expected to hold hours to days. |
| Expected drawdown profile | Not specified in card frontmatter; fixed-risk one-position trend/channel trades. |
| Regime preference | Channel breakout with momentum confirmation. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6facee24-8a58-5bbf-88e9-38d44291db50`
**Source type:** `book`
**Pointer:** `G:/My Drive/QuantMechanica/Ebook/PDF resources/20 Forex Trading Strategies - Thomas Carter.pdf`, Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", 2014, Strategy #5, pages 12-13.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10904_carter-wpr-smma.md`

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
| v1 | 2026-06-06 | Initial build from card | aa1cc0e9-8e46-40a5-98e9-77035b4bb33d |
