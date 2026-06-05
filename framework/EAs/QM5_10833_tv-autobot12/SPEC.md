# QM5_10833_tv-autobot12 - Strategy Spec

**EA ID:** QM5_10833
**Slug:** `tv-autobot12`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a M15 liquidity-sweep momentum pattern with an H1 EMA trend filter. A long setup requires the H1 EMA(115) to rise, H1 price to close above that EMA, chart-timeframe HMA(20) to confirm up direction, price to sweep below the recent swing low, and Williams %R to recover from oversold. A short setup mirrors those rules with a falling H1 EMA, price below the EMA, HMA down confirmation, a sweep above the recent swing high, and Williams %R rolling down from overbought. LP continuation mode uses the same EMA and HMA trend alignment with higher-low or lower-high structure; exits are the card's fixed 5.0R target and the ATR-buffered sweep stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_tf` | `PERIOD_H1` | M15-H4 typical | Higher timeframe used for the EMA trend filter. |
| `strategy_htf_ema_period` | `115` | 89-144 card axis | EMA length for higher-timeframe trend direction. |
| `strategy_hma_period` | `20` | 14-34 card axis | Chart-timeframe HMA confirmation length. |
| `strategy_sweep_lookback_bars` | `14` | 10-20 card axis | Bars used to define recent swing highs and lows. |
| `strategy_williams_period` | `14` | 14-21 card axis | Williams %R lookback used for momentum recovery or rollover. |
| `strategy_atr_period` | `14` | fixed card default | ATR period for the sweep stop buffer. |
| `strategy_stop_atr_buffer_frac` | `0.10` | 0.00-1.00 | Fraction of ATR added beyond the sweep extreme for stop placement. |
| `strategy_target_rr` | `5.0` | 3.0-5.0 card axis | Fixed reward-to-risk target multiple. |
| `strategy_mode` | `2` | 0, 1, 2 | 0 = HP only, 1 = LP only, 2 = HP plus LP. |
| `strategy_max_spread_points` | `0.0` | 0.0+ | Optional spread cap; 0 disables the cap. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - card R3 includes metals and explicitly names XAUUSD.
- `EURUSD.DWX` - card R3 includes FX and explicitly names EURUSD.
- `GBPUSD.DWX` - card R3 includes FX and explicitly names GBPUSD.
- `GDAXI.DWX` - DAX equivalent for card-stated `GER40.DWX`, which is not present in `dwx_symbol_matrix.csv`.
- `NDX.DWX` - card R3 includes index CFDs and explicitly names NDX.

**Explicitly NOT for:**
- `GER40.DWX` - unavailable in `dwx_symbol_matrix.csv`; this build uses `GDAXI.DWX` as the DAX port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | H1 EMA(115) trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Not specified in card frontmatter; card body implies intraday-to-multibar holds until 5R target, stop, or Friday close. |
| Expected drawdown profile | Low hit-rate risk from 5R targets and noisy MTF transitions on fast charts. |
| Regime preference | Trend-aligned liquidity sweep momentum. |
| Win rate target (qualitative) | Low to medium because the default target is 5.0R. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source script
**Pointer:** `https://www.tradingview.com/script/tDChqhhR-AutoTrade-Bot-v12/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10833_tv-autobot12.md`

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
| v1 | 2026-06-06 | Initial build from card | c92d3770-4bc3-4a0d-b61d-0783cce2a3d1 |
