# QM5_12745_chan-wti-cl3040 - Strategy Spec

**EA ID:** QM5_12745
**Slug:** `chan-wti-cl3040`
**Source:** `SRC05` / `SRC05_S07_CL3040`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency WTI structural sleeve on `XTIUSD.DWX`.
On each new D1 bar it compares the prior closed daily close against the 30-day
and 40-day reference closes:

- Long when the prior close is below the 30-day reference and above the
  40-day reference.
- Short when the prior close is above the 30-day reference and below the
  40-day reference.
- Flat when neither condition is true.

The implementation uses the source-stated 30/40 crude-oil combination rule but
conforms it to V5 with one position per magic/symbol, an ATR hard stop, and a
max-hold stale-position guard.

The strategy is not a monthly 6/9/12-month TSMOM package, not a WTI calendar or
event setup, not a pure 4-week reversal, not a natural-gas sleeve, and not a
metal ratio sleeve.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_short_lookback_d1` | 30 | 20-35 | Short reference close in completed D1 bars |
| `strategy_long_lookback_d1` | 40 | 35-60 | Long reference close in completed D1 bars |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 2.75 | 2.25-3.75 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 20 | 10-30 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - WTI crude-oil CFD proxy.

**Explicitly NOT for:**
- `XNGUSD.DWX` - natural-gas exposure has separate cards.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metal sleeves are outside this WTI card.
- Equity index symbols - the mission is commodity/energy exposure.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 6-14 |
| Typical hold time | source-condition cluster, capped at 20 calendar days |
| Expected drawdown profile | medium-high crude-oil reversals bounded by ATR stop |
| Regime preference | pullback inside a 40-day structural trend condition |
| Win rate target | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `SRC05`
**Strategy lineage:** `SRC05_S07_CL3040`
**Source type:** book
**Pointer:** `strategy-seeds/sources/SRC05/`
**Source card:** `strategy-seeds/cards/chan-at-ts-mom-fut_card.md`
**R1-R4 verdict (G0):** all PASS / see
`strategy-seeds/cards/approved/QM5_12745_chan-wti-cl3040_card.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). No live manifest, `T_Live` file, portfolio
gate, or AutoTrading setting is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-28 | Initial build from card | branch-local build |
