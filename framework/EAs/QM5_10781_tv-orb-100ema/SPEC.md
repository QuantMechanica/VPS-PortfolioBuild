# QM5_10781_tv-orb-100ema - Strategy Spec

**EA ID:** QM5_10781
**Slug:** `tv-orb-100ema`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades the first-session opening range on M30. It records the high and low of the opening range after the selected session opens, then blocks trading if EMA(100) is inside that range. It buys when the range is fully above EMA(100) and a closed candle breaks above the range high, and sells when the range is fully below EMA(100) and a closed candle breaks below the range low. Stop loss is placed on the opposite side of the range, take profit is set by the configured R multiple, and positions can be flattened at session end or on an opposite range break.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session` | `STRATEGY_SESSION_LONDON` | Asia, London, New York | Session whose first range defines the breakout box. |
| `strategy_opening_range_minutes` | `30` | `15-60` | Number of minutes after session open used to form the opening range. |
| `strategy_ema_period` | `100` | `50-200` | EMA trend filter period. |
| `strategy_entry_mode` | `STRATEGY_ENTRY_BREAKOUT_CLOSE` | breakout, retest, breakout plus retest | Selects immediate close-break entry, retest entry, or both. |
| `strategy_target_rr` | `1.0` | `1.0-2.0` | Take-profit distance as a multiple of range-side risk. |
| `strategy_session_end_flat` | `true` | `true/false` | Whether to close open positions at session end. |
| `strategy_max_spread_points` | `0` | `0+` | Optional spread cap in points; `0` disables the cap. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major directly aligned with the card's FX intraday target.
- `GBPUSD.DWX` - FX major directly aligned with the card's FX intraday target.
- `USDJPY.DWX` - FX major directly aligned with the card's FX intraday target.
- `AUDUSD.DWX` - FX major directly aligned with the card's FX intraday target.
- `XAUUSD.DWX` - DWX gold symbol for the card's listed XAUUSD extension.
- `GDAXI.DWX` - DWX DAX custom symbol used for the card's GER40.DWX exposure.
- `NDX.DWX` - DWX Nasdaq 100 symbol for the card's listed index extension.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `XAUUSD` - unsuffixed symbol is not a DWX registration target; mapped to `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Intraday, usually minutes to one session |
| Expected drawdown profile | Breakout risk bounded by the opposite side of the opening range. |
| Regime preference | Breakout / volatility expansion with EMA trend alignment |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source indicator
**Pointer:** `https://www.tradingview.com/script/JHm0ftM9-ORB-with-100-EMA/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10781_tv-orb-100ema.md`

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
| v1 | 2026-06-05 | Initial build from card | e29648c7-38bd-4f73-b2f7-613f1ca3ba0f |
