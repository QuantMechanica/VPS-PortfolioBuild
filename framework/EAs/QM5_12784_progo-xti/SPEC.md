# QM5_12784_progo-xti - Strategy Spec

**EA ID:** QM5_12784
**Slug:** `progo-xti`
**Source:** `SRC03_S16_XTI`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a D1 WTI Pro-Go flow-crossover sleeve on `XTIUSD.DWX`.
For each completed D1 bar it computes a public/overnight component from prior
close to current open and a professional/session component from current open
to current close. It trades when the 14-day professional-flow SMA crosses the
14-day public-flow SMA.

The strategy is intentionally not a duplicate of the existing WTI family:
calendar/weekday/month, weekend-gap, WPSR, refinery, hurricane, OPEC, expiry,
ETF-roll, SPR, CAD/oil, XTI/XNG, oil/gold, oil/silver, seasonal pseudo-price,
52-week anchor, 8-week box, Donchian, RSI pullback, and commodity reversal
sleeves use different timing or information sets.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_flow_ma_period` | 14 | 10-28 | SMA length for public and professional flow lines |
| `strategy_signal_mode` | 0 | 0-1 | 0 uses signed magnitude, 1 uses sign-only flow |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 12 | 8-20 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 10-24.
- Typical hold: several days to 12 calendar days unless an opposite line cross
  or ATR stop exits earlier.
- Regime preference: WTI sessions where professional open-to-close flow takes
  leadership over prior-close-to-open flow, or vice versa.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Williams, Larry R. (1999). *Long-Term Secrets to Short-Term Trading*. Wiley
Trading. Local source registry: `strategy-seeds/cards/williams-pro-go_card.md`,
SRC03_S16, Pro-Go public/professional flow decomposition.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
