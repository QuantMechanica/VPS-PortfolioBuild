# QM5_11313_tc20-h1-12-ema5-rsi3-stoch-adx — Strategy Spec

**EA ID:** QM5_11313
**Slug:** `tc20-h1-12-ema5-rsi3-stoch-adx`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Author of this spec:** Codex
**Last revised:** 2026-08-08

---

## 1. Strategy Logic

On each closed H1 bar, the EA buys when EMA(34, close) is above EMA(89, close), RSI(3) is at least 80, Stochastic(5,3,3) K is above D, ADX(14) +DI is above -DI, and EMA(3, close) crosses above EMA(5, open); sells use the exact mirror conditions. The EMA(3)/EMA(5) cross is the single fresh trigger, while RSI is the simultaneous burst state, so the implementation does not require two rare crossover events on one bar. The stop uses the lower of EMA(34) and the prior five-bar low for buys, or the higher of EMA(34) and the prior five-bar high for sells, plus a two-pip buffer, a 20-pip floor, and a 1.5×ATR(14) cap; the target is 2R. A reverse EMA(3)/EMA(5) cross closes the position, while the framework retains Friday-close and news-entry controls.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_macro_fast` | 34 | 21 or 34 in P3 | Fast macro EMA on close |
| `strategy_ema_macro_slow` | 89 | 55 or 89 in P3 | Slow macro EMA on close |
| `strategy_ema_trigger_fast` | 3 | card fixed | Fast micro-trigger EMA on close |
| `strategy_ema_trigger_slow` | 5 | card fixed | Slow micro-trigger EMA on open |
| `strategy_rsi_period` | 3 | 3 or 5 in P3 | Momentum-burst RSI period |
| `strategy_rsi_long_level` | 80.0 | card fixed | Minimum long RSI burst state |
| `strategy_rsi_short_level` | 20.0 | card fixed | Maximum short RSI burst state |
| `strategy_stoch_k` | 5 | card fixed | Stochastic K period |
| `strategy_stoch_d` | 3 | card fixed | Stochastic D period |
| `strategy_stoch_slowing` | 3 | card fixed | Stochastic slowing |
| `strategy_adx_enabled` | true | true or false in P3 | Enables the directional DI filter |
| `strategy_adx_period` | 14 | card fixed | ADX DI period |
| `strategy_structure_lookback` | 5 | card fixed | Prior bars used for the stop extreme |
| `strategy_sl_buffer_pips` | 2 | card fixed | Pip buffer beyond EMA/structure |
| `strategy_sl_min_pips` | 20 | card fixed | Stop-distance floor before the ATR cap |
| `strategy_atr_period` | 14 | card fixed | ATR period for the stop cap |
| `strategy_atr_cap_mult` | 1.5 | card fixed | Maximum stop distance in ATR units |
| `strategy_take_profit_rr` | 2.0 | card fixed | Target distance as a multiple of risk |
| `strategy_spread_cap_pips` | 20 | card fixed | Maximum accepted spread |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — card-listed liquid FX major and primary smoke symbol.
- `GBPUSD.DWX` — card-listed liquid FX major with the same H1 indicator inputs.
- `USDJPY.DWX` — card-listed P2 expansion major; framework pip conversion handles JPY precision.

**Explicitly NOT for:**

- Non-FX symbols — the approved card authorizes only the three listed FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` (card frontmatter) |
| Expected trade frequency | Not separately supplied; 70/year implies about 1.35 trades/week |
| Typical hold time | Not supplied in card frontmatter; measured downstream |
| Regime preference | Trend/momentum, inferred directly from the EMA/DI/burst rules |
| Expected drawdown profile | Not supplied in card frontmatter; measured downstream |
| Win rate target (qualitative) | Not supplied in card frontmatter; measured downstream |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book / local PDF archive`
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\376863900-20-Forex-Trading-Strategies-Collection.pdf`, Thomas Carter, “20 Forex Trading Strategies (1 Hour Time Frame),” Strategy #12
**Lineage:** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11313_tc20-h1-12-ema5-rsi3-stoch-adx.md`.

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
| v1 | 2026-08-08 | Initial build from card | be0f9f18-ddda-4179-a5ff-5dd6ec067009 |
