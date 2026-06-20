# QM5_9259_mql5-struct-pull - Strategy Spec

**EA ID:** QM5_9259
**Slug:** `mql5-struct-pull`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA detects raw swing highs and lows over a five-bar lookback, then keeps only swings validated by break of structure, displacement above the average candle range, a liquidity sweep rejection, or time-based respect. A long signal requires the latest valid swing to be a low and either a higher low, downside liquidity sweep, or bullish displacement while the state is accumulation or expansion. A short signal mirrors this with a valid high, lower high, upside liquidity sweep, or bearish displacement while the state is distribution or reversal. Exits occur when the opposite validated structure plus displacement appears; otherwise trades use structural SL and 2R TP, optionally shortened to the next closer liquidity or valid structure target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_swing_lookback` | 5 | 2-20 | Bars on each side used to confirm a raw swing high or low. |
| `strategy_displacement_factor` | 1.5 | 0.5-5.0 | Candle-range multiplier required for displacement validation. |
| `strategy_structure_hold_bars` | 3 | 1-20 | Bars a structure level must hold without violation. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for the structural stop buffer. |
| `strategy_atr_buffer_mult` | 0.25 | 0.0-2.0 | ATR multiple placed beyond the nearest validated structure stop. |
| `strategy_risk_reward_ratio` | 2.0 | 0.5-10.0 | Fixed risk-reward target before optional closer liquidity target override. |
| `strategy_scan_bars` | 100 | 30-500 | Closed-bar structure window used for swing and liquidity detection. |
| `strategy_avg_candle_bars` | 50 | 10-200 | Average candle sample used as the displacement baseline. |
| `strategy_equal_zone_points` | 10 | 1-500 | Price tolerance in points for equal-high/equal-low liquidity zones. |
| `strategy_min_bars_between_trades` | 3 | 0-20 | Closed-bar cooldown matching the source three-bar trade throttle. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid FX major with DWX OHLC and ATR data.
- `GBPJPY.DWX` - card target; liquid FX cross with DWX OHLC and ATR data.
- `WS30.DWX` - DWX matrix-supported Dow 30 port for the card's `US30.DWX` target.

**Explicitly NOT for:**
- `US30.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `WS30.DWX`.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tester data contract.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `65` |
| Typical hold time | Hours to several days, bounded by structural SL/TP or opposite structure exit |
| Expected drawdown profile | Medium, structure-stop driven with fixed $1,000 backtest risk |
| Regime preference | Validated market-structure pullback and reversal regimes |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** `https://www.mql5.com/en/articles/21888`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9259_mql5-struct-pull.md`

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
| v1 | 2026-06-20 | Initial build from card | 9207ec07-388b-41c6-ba46-1557517911a6 |
