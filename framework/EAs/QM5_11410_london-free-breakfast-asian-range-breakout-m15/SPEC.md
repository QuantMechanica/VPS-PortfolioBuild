# QM5_11410_london-free-breakfast-asian-range-breakout-m15 — Strategy Spec

**EA ID:** QM5_11410
**Slug:** `london-free-breakfast-asian-range-breakout-m15`
**Source:** `8b4188d8-fda3-5633-965f-da707fcb5b4b` (see `strategy-seeds/sources/8b4188d8-fda3-5633-965f-da707fcb5b4b/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The Asian (Tokyo) session is quiet and prints a well-defined range; when London
opens, volatility expands and price breaks out. On M15, the EA marks the High and
Low of the prior Asian session (broker-time 01:00–09:00) using only CLOSED bars.
During the London breakout window (broker-time 09:00–10:00), the first M15 bar
whose CLOSE breaks the Asian range is the single trigger event: `close > asian_high`
opens a BUY at market, `close < asian_low` opens a SELL. The stop is the breakout
candle's extreme (Low for long / High for short), capped at 40 pips; the take-profit
is a fixed 40-pip distance. One trade per calendar day (first confirmed direction
only). Session windows are evaluated from the bar TIMESTAMP in broker time (DXZ
NY-Close GMT+2/+3), never wall-clock; the Asian range is built from prior closed
bars only.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_asian_start_h` | 1 | 0-23 | Asian session start hour (broker time) |
| `strategy_asian_end_h` | 9 | 0-23 | Asian session end hour (broker, exclusive) |
| `strategy_london_start_h` | 9 | 0-23 | London breakout-window start hour (broker) |
| `strategy_london_end_h` | 10 | 0-23 | London breakout-window end hour (broker, exclusive) |
| `strategy_tp_pips` | 40 | 25-55 | Fixed take-profit distance in pips |
| `strategy_sl_cap_pips` | 40 | 15-60 | Max stop distance; breakout-candle extreme capped to this |
| `strategy_min_range_pips` | 5 | 1-30 | Ignore degenerate Asian ranges smaller than this |
| `strategy_spread_cap_pips` | 20 | 5-50 | Skip a genuinely wide spread (fail-open on zero spread) |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — primary; the card's lead pair, most active at London open.
- `EURUSD.DWX` — major with a clean Asian range and strong London expansion.
- `USDJPY.DWX` — Tokyo-session pair with a well-formed Asian range.
- `AUDUSD.DWX` — liquid major; Asian-session pair with London follow-through.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the strategy is calibrated to FX session
  structure (Tokyo range → London expansion); index cash sessions do not map to
  these broker-time windows.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~100` |
| Typical hold time | `minutes to a few hours (intraday, SL/TP exit)` |
| Expected drawdown profile | `clustered losses in choppy / false-breakout regimes` |
| Regime preference | `breakout / volatility-expansion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `8b4188d8-fda3-5633-965f-da707fcb5b4b`
**Source type:** `book` (local PDF, anonymous author)
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\423041768-London-Free-Breakfast-Forex-Trading-Strategy-1.pdf`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11410_london-free-breakfast-asian-range-breakout-m15.md`

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
| v1 | 2026-06-18 | Initial build from card | central-step registration pending |
