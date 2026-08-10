# QM5_20073_pip-hunter-heiken-ashi-r1-recovery — Strategy Spec

**EA ID:** QM5_20073
**Slug:** `pip-hunter-heiken-ashi-r1-recovery`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Single-timeframe (H1) Heiken-Ashi trend-follower. Heiken-Ashi candles are
computed inline from raw OHLC (no MT5 built-in exists): `HA_Close = (Open + High
+ Low + Close) / 4`, `HA_Open = (prev HA_Open + prev HA_Close) / 2` (oldest bar
in the lookback window seeded with the raw `(Open + Close) / 2` midpoint),
`HA_High = max(High, HA_Open, HA_Close)`, `HA_Low = min(Low, HA_Open, HA_Close)`.
A bar is green when `HA_Close > HA_Open`, otherwise red. The recursive chain is
rebuilt from a 40-bar price-history window once per new H1 bar and cached.

Long entry (all on the last closed bar `[1]`): the HA color streak ending at
`[1]` is green and at least `strategy_min_streak_bars` (default 2) bars long AND
`HA_Open[1] == HA_Low[1]` within one point (flat trend-bar bottom, no/minimal
lower wick) AND `Close[1] > EMA(200, H1)` AND `RSI(14)` crosses up through 50
(`RSI[1] > 50 AND RSI[2] <= 50`). Short entry is the mirror: red streak,
`HA_Open[1] == HA_High[1]` (no upper wick), `Close[1] < EMA(200, H1)`, RSI
crossing down through 50. Orders are opened at market on the open of the next H1
bar (entry is gated by `QM_IsNewBar()`).

Exit is whichever fires first: (primary) HA color flip on the last closed bar
against the position; (secondary) RSI re-crosses 50 against the trade direction
(long exits when `RSI[1] < 50 AND RSI[2] >= 50`, mirror for short); (tertiary)
the order-attached take-profit at RR = 2.0. Stop-loss is `ATR(14, H1) x 2.0` from
entry, order-attached. One position per symbol per magic; opposite momentum is
handled by the HA-flip exit (position is closed first, and the >=2-bar streak
requirement guarantees a fresh opposite entry cannot qualify on the same bar).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 200 | 100-300 | EMA period for the H1 directional bias filter |
| `strategy_rsi_period` | 14 | 7-28 | RSI period for the 50-midline cross trigger |
| `strategy_rsi_midline` | 50.0 | 40-60 | RSI level treated as the cross threshold |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the stop-loss distance |
| `strategy_atr_sl_mult` | 2.0 | 1.0-2.5 | Stop distance as this multiple of ATR |
| `strategy_rr_target` | 2.0 | 1.5-3.0 | Take-profit as this reward:risk multiple |
| `strategy_min_streak_bars` | 2 | 2-4 | Required consecutive same-color HA streak length |
| `strategy_ha_lookback_bars` | 40 | 20-60 | Bars used to seed the recursive HA chain each new bar |
| `strategy_max_spread_points` | 25 | 0-100 | Skip entry when current spread exceeds this (points) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major with clean H1 trends
- `GBPUSD.DWX` — FX major with strong directional H1 legs
- `USDJPY.DWX` — FX major; HA smoothing suits its trending regime
- `AUDUSD.DWX` — commodity-linked FX major with sustained trends
- `EURJPY.DWX` — FX cross with pronounced trend persistence
- `XAUUSD.DWX` — gold; strong trend regime is well suited to HA color streaks

**Explicitly NOT for:**
- Index CFDs (e.g. `NDX.DWX`, `WS30.DWX`) — overnight swap/gap behaviour and
  session structure are not part of this card's R3 PASS basket; not validated.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` (entry, exit, EMA, RSI, ATR and HA all on H1) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~40` |
| Typical hold time | `hours to a few days (multi-bar H1 trend legs)` |
| Expected drawdown profile | `~16% peak; whipsaw losses in range-bound regimes` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `ForexFactory Trading Systems forum — "Pip Hunter Heiken Ashi" thread cluster`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_20073_pip-hunter-heiken-ashi-r1-recovery.md`

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
| v1 | 2026-08-11 | Initial build from card | pending build commit |
