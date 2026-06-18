# QM5_11405_carter-tf11-adx-weak-prevday-breakout-h1 — Strategy Spec

**EA ID:** QM5_11405
**Slug:** `carter-tf11-adx-weak-prevday-breakout-h1`
**Source:** `29c77a02-59bd-52f7-bcb3-b3108d5f1e79` (see `strategy-seeds/sources/29c77a02-59bd-52f7-bcb3-b3108d5f1e79/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Prior-day high/low breakout traded only while the trend is weak (ranging). On the
H1 base timeframe the EA reads ADX(14) on the last closed bar; a value below the
weak threshold (default 35) confirms a consolidation/range regime rather than a
strong trend. Yesterday's daily High and Low are read once per broker day from the
completed D1 bar (shift 1), with the day boundary derived from the broker-time bar
timestamp via `QM_BrokerToUTC`.

The setup is a false break of the opposite prior-day extreme: if the last closed
H1 bar's Low pierced below `prevDayLow - buffer` (false breakdown), the EA arms a
BUYSTOP at `prevDayHigh + buffer`; if the last closed H1 bar's High pierced above
`prevDayHigh + buffer` (false breakout), it arms a SELLSTOP at `prevDayLow - buffer`.
The probe uses the intraday H1 bar Low/High (a genuine excursion, not an open gap),
so it is valid on gapless .DWX CFDs. The pending stop order carries a fixed stop
(30 pips) and take-profit (60 pips), moves to break-even after +30 pips, and is
cancelled at the end of the current broker day if it never triggers. One position
and at most one live pending order per magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 14 | 7-28 | ADX period on the H1 base TF |
| `strategy_adx_weak_threshold` | 35.0 | 25-35 | Trade only when ADX < this (weak/ranging regime) |
| `strategy_breakout_buffer_pips` | 15 | 5-15 | Pips beyond the prior-day extreme for probe + entry |
| `strategy_sl_pips` | 30 | 20-40 | Initial stop distance from entry (pips) |
| `strategy_tp_pips` | 60 | 40-80 | Take-profit distance from entry (pips) |
| `strategy_be_trigger_pips` | 30 | 20-40 | Move SL to break-even after +this many pips |
| `strategy_spread_cap_pips` | 20.0 | 5-30 | Block a genuinely wide spread above this (pips); fail-open on zero spread |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major liquid pair, the card's primary breakout instrument
- `GBPUSD.DWX` — major pair with frequent intraday range expansions
- `USDJPY.DWX` — major pair; 3-digit pip scaling handled by the framework
- `AUDUSD.DWX` — liquid commodity-linked pair with clean prior-day levels
- `USDCAD.DWX` — liquid major; range/consolidation regimes common
- `USDCHF.DWX` — liquid major; complements the USD-pair basket

**Explicitly NOT for:**
- Index / metal / energy `.DWX` symbols — the card scopes this strategy to FX
  majors; pip scaling and the 15/30/60-pip levels are calibrated for FX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_D1` (prior-day High/Low, shift 1) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~50` |
| Typical hold time | `intraday to a few hours (same broker day)` |
| Expected drawdown profile | `moderate; fixed 30-pip stop, 60-pip target (2R)` |
| Regime preference | `breakout (within a weak-ADX range)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `29c77a02-59bd-52f7-bcb3-b3108d5f1e79`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Trend Following Systems" (2014), Strategy #11
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11405_carter-tf11-adx-weak-prevday-breakout-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |

> When this EA cycles back to Q01 from a Q02 zero-trade event, add a row:
> `| v2 | YYYY-MM-DD | Q02 all-symbol zero-trades; widened entry filter X | <commit> |`
