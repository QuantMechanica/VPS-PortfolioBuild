# QM5_10773_tv-harami-bb - Strategy Spec

**EA ID:** QM5_10773
**Slug:** `tv-harami-bb`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-01

---

## 1. Strategy Logic

The EA trades a two-candle Harami reversal after the first candle touches or pierces an outer Bollinger Band. A bullish setup requires a bearish first candle touching the lower band, followed by a bullish second candle whose body sits inside the first candle body; bearish setups mirror this at the upper band. Entries occur only on confirmed closed bars with no existing position for the EA magic. Exits are managed by the card's bracket: either source points or the ATR-normalized 2R baseline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_timeframe` | `PERIOD_CURRENT` | MT5 timeframe enum | Signal timeframe; default follows the tester chart period. |
| `strategy_bb_period` | `20` | `20-30` | Bollinger Band lookback period from the card test grid. |
| `strategy_bb_deviation` | `2.0` | `2.0-2.5` | Bollinger Band standard deviation multiplier. |
| `strategy_pattern_strictness` | `STRATEGY_HARAMI_BODY_INSIDE` | body-inside or full-range-inside | Harami containment rule from the card test grid. |
| `strategy_stop_mode` | `STRATEGY_STOP_ATR` | source-points or ATR | Bracket mode; ATR is the cross-symbol DWX baseline. |
| `strategy_source_sl_points` | `20` | `1+` | Source-pure stop distance in points. |
| `strategy_source_tp_points` | `40` | `1+` | Source-pure target distance in points. |
| `strategy_atr_period` | `14` | `1+` | ATR period for normalized stops. |
| `strategy_atr_sl_mult` | `1.0` | `0.75-1.5` | ATR stop multiplier from the card test grid. |
| `strategy_take_profit_rr` | `2.0` | `1.5-2.5` | Take-profit reward/risk multiple. |
| `strategy_use_ema200_filter` | `false` | `true/false` | Optional EMA200 direction ablation. |
| `strategy_ema_period` | `200` | `1+` | EMA period used when the direction filter is enabled. |
| `strategy_max_spread_points` | `0` | `0+` | Optional spread ceiling; zero disables the strategy-specific spread gate. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - R3 forex basket member with available DWX candle and indicator data.
- `GBPUSD.DWX` - R3 forex basket member with available DWX candle and indicator data.
- `USDJPY.DWX` - R3 forex basket member with available DWX candle and indicator data.
- `XAUUSD.DWX` - Canonical DWX metal symbol for the card's `XAUUSD` basket item.
- `GDAXI.DWX` - Canonical available DAX symbol used for the card's `GER40.DWX` basket item.
- `NDX.DWX` - R3 US index basket member with available DWX candle and indicator data.
- `WS30.DWX` - R3 US index basket member with available DWX candle and indicator data.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is used instead.
- `XAUUSD` - Unsuffixed broker name is not used in DWX backtest artifacts; `XAUUSD.DWX` is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` and `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Bracket-managed intraday to multi-bar holds; exact frontmatter value not provided. |
| Expected drawdown profile | Mean-reversion bracket risk, noisy during persistent band-walk trends. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `TradingView script Cf6gXdy1-Moja-Strategia-Harami-BB`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10773_tv-harami-bb.md`

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
| v1 | 2026-06-01 | Initial build from card | 8ac11a81-6d20-4095-9051-0bb9c04a8684 |
