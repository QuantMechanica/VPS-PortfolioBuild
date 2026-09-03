# QM5_41332_larry-williams-18ma-2outside-bars-d1-opt - Strategy Spec

**EA ID:** QM5_41332
**Slug:** `larry-williams-18ma-2outside-bars-d1-opt`
**Parent EA:** `QM5_11910_larry-williams-18ma-2outside-bars-d1`
**Target symbols:** `NZDUSD.DWX`
**Source:** `c2f8e3d5-4a91-5b67-9c48-a3b7d6e4f2c9`
**Author of this spec:** Claude
**Last revised:** 2026-09-03

---

## 1. Strategy Logic

This derivative preserves the approved parent mechanics for the single
`NZDUSD.DWX` carrier and adds only the six optional DL-089 closed-D1 pattern
veto inputs. With all six inputs at zero, the veto corset is neutral and the
EA reproduces the parent (`QM5_11910`) exactly.

The parent trades a D1 Larry Williams breakout rule. A long setup forms when
the last two closed daily bars both have lows above the 18-day SMA and neither
bar is an inside bar; the entry is a breakout above the higher high of those
two bars plus one pip. A short setup mirrors the rule below the SMA. Exits are
by ATR stop, ATR target, a close back across the 18-day SMA, or a 30-bar time
stop.

The DL-089 corset evaluates a closed-D1 pattern profile once per candidate
entry: `Pattern_AllowsRequest` consults the six `opt_pp_*` predicate slots
before any order is submitted. A zero slot is inert; a non-zero slot vetoes
the corresponding buy or sell leg when its pattern predicate does not fire on
the just-closed D1 reference bar. There is no take-profit, trailing, grid,
martingale, or ML logic beyond the parent's rules.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ma_period` | 18 | 5-80 | Daily SMA period for trend filtering and MA-cross exit. |
| `strategy_atr_period` | 14 | 5-80 | Daily ATR period for stop and target distance. |
| `strategy_atr_sl_mult` | 2.0 | 0.5-6.0 | ATR multiple for initial stop distance. |
| `strategy_target_atr_mult` | 4.0 | 0.5-10.0 | ATR multiple for fixed take-profit distance. |
| `strategy_order_validity` | 5 | 1-20 | Number of D1 bars that a breakout setup remains valid. |
| `strategy_time_stop_bars` | 30 | 1-80 | Maximum D1 bars to hold a position. |
| `opt_pp_buy1..3` | 0 | pattern id | DL-089 buy-side pattern veto slots; zero disables the slot. |
| `opt_pp_sell1..3` | 0 | pattern id | DL-089 sell-side pattern veto slots; zero disables the slot. |

---

## 3. Symbol Universe

**Designed for:**

- `NZDUSD.DWX` - declared DL-089 measurement carrier (parent slot; liquid major FX pair).

The parent `QM5_11910` universe (EURUSD, GBPUSD, USDJPY, USDCAD, USDCHF,
AUDUSD, NZDUSD, EURJPY, GBPJPY, AUDJPY - all `.DWX`) remains its own contract;
this measurement sibling ships only the `NZDUSD.DWX` carrier required by the
DL-089 census.

**Explicitly NOT for:**

- Any symbol outside the declared `NZDUSD.DWX` carrier - the census measures a single (EA, symbol) cell.
- Non-DWX symbols - the farm only backtests registered `.DWX` history symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Pattern reference TF | `D1`, closed shift 1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `15` (neutral baseline reproduces the parent) |
| Typical hold time | Several days to six weeks |
| Expected drawdown profile | Trend-breakout whipsaws during range-bound FX regimes. |
| Regime preference | Daily trend continuation and breakout follow-through. |
| Win rate target (qualitative) | Medium-low with positive reward-to-risk. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c2f8e3d5-4a91-5b67-9c48-a3b7d6e4f2c9`
**Source type:** `seminar manual` (inherited from the approved QM5_11910 parent card)
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11910_larry-williams-18ma-2outside-bars-d1.md`
**R1-R4 verdict (Q00):** all PASS / see `docs/strategy_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 census) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | n/a | No live or pipeline verdict is authorized for this measurement sibling. |
| Full live | n/a | No live or pipeline verdict is authorized for this measurement sibling. |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-03 | DL-089 measurement sibling of QM5_11910 (path-to-25 sibling wave 3) | Parent mechanics byte-equivalent + six-slot pattern-permission corset. |
